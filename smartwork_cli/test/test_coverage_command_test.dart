import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/test_command.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

Future<List<String>> _captureOutput(Future<void> Function() body) async {
  final lines = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines;
}

Future<(List<String>, int)> _runCoverage(
  String projectPath,
  List<String> args, {
  CoverageCollectionLifecycle? lifecycle,
}) async {
  final runner = CommandRunner('smartwork', 'test')
    ..addCommand(TestCommand(
      projectPath: projectPath,
      coverageLifecycle: lifecycle,
    ));
  final previousExitCode = exitCode;
  exitCode = 0;
  final output = await _captureOutput(
    () => runner.run(['test', 'coverage', ...args]),
  );
  final result = exitCode;
  exitCode = previousExitCode;
  return (output, result);
}

const _lcov = '''
SF:lib/features/auth/state/login_cubit.dart
DA:1,1
DA:2,0
LF:2
LH:1
end_of_record
''';

CoverageCollectionLifecycle _fakeLifecycle({
  bool writeCoverage = true,
}) =>
    CoverageCollectionLifecycle(
      executionService: TestExecutionService(
        runProcess: (executable, arguments, {workingDirectory}) async {
          if (writeCoverage) {
            await Directory('$workingDirectory/coverage')
                .create(recursive: true);
            await File('$workingDirectory/coverage/lcov.info')
                .writeAsString(_lcov);
          }
          return ProcessResult(0, 0, '', '');
        },
      ),
    );

/// Tests `smartwork test coverage <feature>` — the CLI surface for
/// `CoverageCollectionLifecycle`. This command genuinely invokes
/// `flutter test --coverage` under the hood, so these tests never spawn
/// a real Flutter process — they seed `coverage/lcov.info` directly to
/// simulate what a real run would have written, since
/// `CoverageCollectionLifecycle`/`TestExecutionService` are already
/// covered by their own real-subprocess-injection tests in
/// `smartwork_core`.
void main() {
  group('TestCoverageCommand', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_cli_test_coverage_');
      projectPath = tempDir.path;
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('requires a feature name', () async {
      final (output, code) = await _runCoverage(projectPath, []);

      expect(code, 1);
      expect(output.join('\n'), contains('Feature name is required'));
    });

    test(
        'reports a clear error for an unknown feature, without ever '
        'running flutter test', () async {
      var ranTests = false;
      final lifecycle = CoverageCollectionLifecycle(
        executionService: TestExecutionService(
          runProcess: (executable, arguments, {workingDirectory}) async {
            ranTests = true;
            return ProcessResult(0, 0, '', '');
          },
        ),
      );

      final (output, code) = await _runCoverage(
        projectPath,
        ['billing'],
        lifecycle: lifecycle,
      );

      expect(code, 1);
      expect(output.join('\n'), contains('No feature named "billing"'));
      expect(ranTests, isFalse);
    });

    test(
        'reports a clear error when flutter test never produces '
        'coverage/lcov.info', () async {
      await Directory('$projectPath/lib/features/auth').create(recursive: true);
      await File('$projectPath/lib/features/auth/auth.dart')
          .writeAsString('class Auth {}');

      final (output, code) = await _runCoverage(
        projectPath,
        ['auth'],
        lifecycle: _fakeLifecycle(writeCoverage: false),
      );

      expect(code, 1);
      expect(output.join('\n'), contains('did not produce'));
    });

    test('prints a real per-file coverage summary on success', () async {
      await Directory('$projectPath/lib/features/auth/state')
          .create(recursive: true);
      await File('$projectPath/lib/features/auth/state/login_cubit.dart')
          .writeAsString('class LoginCubit {}');

      final (output, code) = await _runCoverage(
        projectPath,
        ['auth'],
        lifecycle: _fakeLifecycle(),
      );

      expect(code, 0);
      final text = output.join('\n');
      expect(text, contains('Feature: auth'));
      expect(text, contains('Line coverage: 50.0% (1/2 lines)'));
      expect(text, contains('lib/features/auth/state/login_cubit.dart'));
    });

    test('--verbose lists the exact uncovered line', () async {
      await Directory('$projectPath/lib/features/auth').create(recursive: true);
      await File('$projectPath/lib/features/auth/auth.dart')
          .writeAsString('class Auth {}');

      final (output, code) = await _runCoverage(
        projectPath,
        ['auth', '--verbose'],
        lifecycle: _fakeLifecycle(),
      );

      expect(code, 0);
      expect(output.join('\n'), contains('line 2'));
    });

    test('--format json prints the complete CoverageReport as JSON', () async {
      await Directory('$projectPath/lib/features/auth').create(recursive: true);
      await File('$projectPath/lib/features/auth/auth.dart')
          .writeAsString('class Auth {}');

      final (output, code) = await _runCoverage(
        projectPath,
        ['auth', '--format', 'json'],
        lifecycle: _fakeLifecycle(),
      );

      expect(code, 0);
      expect(output.single, contains('"lineCoverage": 0.5'));
    });
  });
}
