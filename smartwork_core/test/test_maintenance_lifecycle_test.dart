import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('TestMaintenanceLifecycle.plan', () {
    late String tempDir;

    setUp(() async {
      tempDir =
          (await Directory.systemTemp.createTemp('test_maintenance_')).path;
    });

    tearDown(() async {
      await Directory(tempDir).delete(recursive: true);
    });

    test('throws for an unknown feature', () async {
      await Directory('$tempDir/lib/features/auth').create(recursive: true);
      await File('$tempDir/lib/features/auth/auth.dart')
          .writeAsString('class Auth {}');

      expect(
        () => TestMaintenanceLifecycle().plan(tempDir, 'billing'),
        throwsA(isA<FeatureNotFoundForTestingException>()),
      );
    });

    test(
        'produces a real plan for a genuine signature mismatch on '
        'disk', () async {
      await Directory('$tempDir/lib/features/auth/state')
          .create(recursive: true);
      await File('$tempDir/lib/features/auth/state/auth_bloc.dart')
          .writeAsString('''
class AuthBloc {
  Future<void> login(String email, String password, bool rememberMe) async {}
}
''');
      await Directory('$tempDir/test/features/auth/state')
          .create(recursive: true);
      await File('$tempDir/test/features/auth/state/auth_bloc_test.dart')
          .writeAsString('''
void main() {
  final bloc = AuthBloc();
  bloc.login('a@test.com', 'password');
}
''');

      final plan = await TestMaintenanceLifecycle().plan(tempDir, 'auth');

      expect(plan.feature, 'auth');
      expect(plan.highConfidence, hasLength(1));
      expect(plan.highConfidence.single.newSnippet,
          "'a@test.com', 'password', false");
    });
  });

  group('TestMaintenanceLifecycle.apply', () {
    late String tempDir;
    late String testFilePath;

    setUp(() async {
      tempDir =
          (await Directory.systemTemp.createTemp('test_maintenance_')).path;
      testFilePath = '$tempDir/test/features/auth/state/auth_bloc_test.dart';
      await Directory('$tempDir/test/features/auth/state')
          .create(recursive: true);
    });

    tearDown(() async {
      await Directory(tempDir).delete(recursive: true);
    });

    TestUpdate _highConfidenceUpdate({
      required String oldSnippet,
      required String newSnippet,
      required int startOffset,
      required int endOffset,
    }) =>
        TestUpdate(
          testFile: 'test/features/auth/state/auth_bloc_test.dart',
          subject: 'AuthBloc',
          kind: TestUpdateKind.methodCallArguments,
          confidence: TestUpdateConfidence.high,
          reason: 'AuthBloc.login() now requires rememberMe.',
          oldSnippet: oldSnippet,
          newSnippet: newSnippet,
          startOffset: startOffset,
          endOffset: endOffset,
        );

    test(
        'writes only the exact spliced region, preserving everything '
        'else in the file byte-for-byte', () async {
      const original = '''
// A developer comment.
void main() {
  final bloc = AuthBloc();
  bloc.login('a@test.com', 'password'); // trailing comment
}
''';
      await File(testFilePath).writeAsString(original);

      final argsStart = original.indexOf("'a@test.com'");
      final argsEnd = argsStart + "'a@test.com', 'password'".length;
      final update = _highConfidenceUpdate(
        oldSnippet: "'a@test.com', 'password'",
        newSnippet: "'a@test.com', 'password', false",
        startOffset: argsStart,
        endOffset: argsEnd,
      );
      final plan = TestMaintenancePlan(feature: 'auth', updates: [update]);

      final result = await TestMaintenanceLifecycle().apply(tempDir, plan);

      expect(result.appliedUpdates, [update]);
      expect(result.updatedFiles,
          ['test/features/auth/state/auth_bloc_test.dart']);

      final written = await File(testFilePath).readAsString();
      expect(written, contains('// A developer comment.'));
      expect(written, contains('// trailing comment'));
      expect(written, contains("bloc.login('a@test.com', 'password', false)"));
    });

    test(
        'never applies a medium- or low-confidence update, even if '
        'present in the plan', () async {
      await File(testFilePath).writeAsString('void main() {}');

      final mediumUpdate = TestUpdate(
        testFile: 'test/features/auth/state/auth_bloc_test.dart',
        subject: 'AuthBloc',
        kind: TestUpdateKind.methodCallArguments,
        confidence: TestUpdateConfidence.medium,
        reason: 'reason',
        oldSnippet: 'old',
        newSnippet: 'new',
        startOffset: 0,
        endOffset: 3,
      );
      final plan =
          TestMaintenancePlan(feature: 'auth', updates: [mediumUpdate]);

      final result = await TestMaintenanceLifecycle().apply(tempDir, plan);

      expect(result.appliedUpdates, isEmpty);
      expect(result.skippedUpdates, [mediumUpdate]);
      expect(await File(testFilePath).readAsString(), 'void main() {}');
    });

    test(
        'throws StaleTestUpdateException, and writes nothing, when the '
        "file's current content no longer matches the plan's own "
        'oldSnippet at the recorded offset', () async {
      await File(testFilePath).writeAsString("bloc.login('changed');");

      final update = _highConfidenceUpdate(
        oldSnippet: "'a@test.com', 'password'",
        newSnippet: "'a@test.com', 'password', false",
        startOffset: 11,
        endOffset: 20,
      );
      final plan = TestMaintenancePlan(feature: 'auth', updates: [update]);

      await expectLater(
        TestMaintenanceLifecycle().apply(tempDir, plan),
        throwsA(isA<StaleTestUpdateException>()),
      );
      expect(await File(testFilePath).readAsString(), "bloc.login('changed');");
    });

    test(
        'applies multiple updates to the same file correctly, without '
        'one splice invalidating another\'s offsets', () async {
      const original = "one(1); two(2);";
      await File(testFilePath).writeAsString(original);

      final firstCallStart = original.indexOf('1');
      final secondCallStart = original.indexOf('2');
      final updateOne = _highConfidenceUpdate(
        oldSnippet: '1',
        newSnippet: '1, true',
        startOffset: firstCallStart,
        endOffset: firstCallStart + 1,
      );
      final updateTwo = _highConfidenceUpdate(
        oldSnippet: '2',
        newSnippet: '2, false',
        startOffset: secondCallStart,
        endOffset: secondCallStart + 1,
      );
      final plan = TestMaintenancePlan(
        feature: 'auth',
        updates: [updateOne, updateTwo],
      );

      await TestMaintenanceLifecycle().apply(tempDir, plan);

      expect(
        await File(testFilePath).readAsString(),
        'one(1, true); two(2, false);',
      );
    });
  });

  group('TestMaintenanceLifecycle.rollback', () {
    test('restores every file to its given original content', () async {
      final tempDir =
          (await Directory.systemTemp.createTemp('test_maintenance_')).path;
      final filePath = '$tempDir/test/a_test.dart';
      await Directory('$tempDir/test').create(recursive: true);
      await File(filePath).writeAsString('modified content');

      await TestMaintenanceLifecycle().rollback(
        tempDir,
        {'test/a_test.dart': 'original content'},
      );

      expect(await File(filePath).readAsString(), 'original content');
      await Directory(tempDir).delete(recursive: true);
    });
  });

  group('TestMaintenanceLifecycle.verify', () {
    test(
        'reports analyzePassed false and skips running tests when '
        'flutter analyze fails', () async {
      final events = <String>[];
      final lifecycle = TestMaintenanceLifecycle(
        runProcess: (executable, arguments, {workingDirectory}) async {
          events.add(executable);
          if (executable == 'flutter' && arguments.first == 'analyze') {
            return ProcessResult(0, 1, '', 'some analyze error');
          }
          return ProcessResult(0, 0, 'Formatted 1 file (0 changed)', '');
        },
        executionService: TestExecutionService(
          runProcess: (executable, arguments, {workingDirectory}) async {
            events.add('flutter test');
            return ProcessResult(0, 0, '', '');
          },
        ),
      );

      final result =
          await lifecycle.verify('/fake/project', ['test/a_test.dart']);

      expect(result.analyzePassed, isFalse);
      expect(result.passed, isFalse);
      expect(result.analyzeOutput, contains('some analyze error'));
      expect(events, isNot(contains('flutter test')));
    });

    test('runs flutter test for every changed file once analyze passes',
        () async {
      final testedTargets = <String>[];
      final lifecycle = TestMaintenanceLifecycle(
        runProcess: (executable, arguments, {workingDirectory}) async =>
            ProcessResult(0, 0, 'Formatted 2 files (0 changed)', ''),
        executionService: TestExecutionService(
          runProcess: (executable, arguments, {workingDirectory}) async {
            testedTargets.add(arguments[1]);
            return ProcessResult(0, 0, '', '');
          },
        ),
      );

      final result = await lifecycle.verify(
        '/fake/project',
        ['test/a_test.dart', 'test/b_test.dart'],
      );

      expect(result.passed, isTrue);
      expect(testedTargets, ['test/a_test.dart', 'test/b_test.dart']);
    });

    test(
        'reports passed false when a test run fails, without hiding '
        'it', () async {
      final lifecycle = TestMaintenanceLifecycle(
        runProcess: (executable, arguments, {workingDirectory}) async =>
            ProcessResult(0, 0, 'Formatted 1 file (0 changed)', ''),
        executionService: TestExecutionService(
          runProcess: (executable, arguments, {workingDirectory}) async =>
              ProcessResult(0, 1, '', ''),
        ),
      );

      final result =
          await lifecycle.verify('/fake/project', ['test/a_test.dart']);

      expect(result.analyzePassed, isTrue);
      expect(result.testsPassed, isFalse);
      expect(result.passed, isFalse);
    });
  });
}
