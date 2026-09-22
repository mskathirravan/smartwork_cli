import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

const _lcov = '''
SF:lib/features/auth/state/login_cubit.dart
DA:1,1
DA:2,0
LF:2
LH:1
end_of_record
SF:lib/features/profile/profile_page.dart
DA:1,1
LF:1
LH:1
end_of_record
''';

void main() {
  group('CoverageCollectionLifecycle', () {
    late String tempDir;

    setUp(() async {
      tempDir =
          (await Directory.systemTemp.createTemp('coverage_lifecycle_')).path;
      await Directory('$tempDir/lib/features/auth').create(recursive: true);
      await File('$tempDir/lib/features/auth/auth.dart')
          .writeAsString('class Auth {}');
    });

    tearDown(() async {
      await Directory(tempDir).delete(recursive: true);
    });

    test(
        'throws when the feature does not exist, without ever running '
        'flutter test', () async {
      var ranTests = false;
      final lifecycle = CoverageCollectionLifecycle(
        executionService: TestExecutionService(
          runProcess: (executable, arguments, {workingDirectory}) async {
            ranTests = true;
            return ProcessResult(0, 0, '', '');
          },
        ),
      );

      await expectLater(
        lifecycle.collect(tempDir, 'billing'),
        throwsA(isA<FeatureNotFoundForTestingException>()),
      );
      expect(ranTests, isFalse);
    });

    test(
        'throws CoverageNotProducedException when flutter test never '
        'writes coverage/lcov.info', () async {
      final lifecycle = CoverageCollectionLifecycle(
        executionService: TestExecutionService(
          runProcess: (executable, arguments, {workingDirectory}) async =>
              ProcessResult(0, 0, '', ''),
        ),
      );

      await expectLater(
        lifecycle.collect(tempDir, 'auth'),
        throwsA(isA<CoverageNotProducedException>()),
      );
    });

    test(
        'runs flutter test --coverage, reads the real lcov.info it '
        'wrote, and narrows the result to the requested feature', () async {
      final lifecycle = CoverageCollectionLifecycle(
        executionService: TestExecutionService(
          runProcess: (executable, arguments, {workingDirectory}) async {
            expect(arguments, contains('--coverage'));
            await Directory('$tempDir/coverage').create(recursive: true);
            await File('$tempDir/coverage/lcov.info').writeAsString(_lcov);
            return ProcessResult(0, 0, '', '');
          },
        ),
      );

      final report = await lifecycle.collect(tempDir, 'auth');

      expect(report.files, hasLength(1));
      expect(
          report.files.single.file, 'lib/features/auth/state/login_cubit.dart');
    });

    test('passes a MockServer and mappings through to TestExecutionService',
        () async {
      final events = <String>[];
      final mockServer = _RecordingMockServer(events);

      final lifecycle = CoverageCollectionLifecycle(
        executionService: TestExecutionService(
          runProcess: (executable, arguments, {workingDirectory}) async {
            await Directory('$tempDir/coverage').create(recursive: true);
            await File('$tempDir/coverage/lcov.info').writeAsString(_lcov);
            return ProcessResult(0, 0, '', '');
          },
        ),
      );

      await lifecycle.collect(
        tempDir,
        'auth',
        mockServer: mockServer,
        mappings: [
          MockMapping(
            name: 'login',
            method: 'POST',
            urlPath: '/login',
            responseStatus: 200,
          ),
        ],
      );

      expect(events, ['start', 'loadMappings', 'reset', 'stop']);
    });
  });
}

class _RecordingMockServer implements MockServer {
  final List<String> events;

  _RecordingMockServer(this.events);

  @override
  Future<void> start() async => events.add('start');

  @override
  Future<void> stop() async => events.add('stop');

  @override
  Future<bool> isReady() async => true;

  @override
  Future<void> loadMappings(List<MockMapping> mappings) async =>
      events.add('loadMappings');

  @override
  Future<void> reset() async => events.add('reset');
}
