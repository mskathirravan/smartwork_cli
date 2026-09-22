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

Future<(List<String>, int)> _runUpdate(
  String projectPath,
  List<String> args, {
  bool Function(String)? confirm,
  TestMaintenanceLifecycle? lifecycle,
}) async {
  final runner = CommandRunner('smartwork', 'test')
    ..addCommand(TestCommand(
      projectPath: projectPath,
      confirm: confirm,
      maintenanceLifecycle: lifecycle,
    ));
  final previousExitCode = exitCode;
  exitCode = 0;
  final output = await _captureOutput(
    () => runner.run(['test', 'update', ...args]),
  );
  final result = exitCode;
  exitCode = previousExitCode;
  return (output, result);
}

/// A `TestMaintenanceLifecycle` that never spawns a real `flutter`/
/// `dart` process — `verify` always reports a configurable outcome, so
/// these CLI tests exercise the command's own orchestration (plan ->
/// confirm -> apply -> verify -> rollback-on-failure) without needing a
/// real Flutter toolchain.
TestMaintenanceLifecycle _lifecycleWithVerification({
  required bool verifyPasses,
}) =>
    TestMaintenanceLifecycle(
      executionService: TestExecutionService(
        runProcess: (executable, arguments, {workingDirectory}) async =>
            ProcessResult(0, verifyPasses ? 0 : 1, '', ''),
      ),
      runProcess: (executable, arguments, {workingDirectory}) async =>
          ProcessResult(0, 0, 'Formatted 1 file (0 changed)', ''),
    );

void main() {
  group('TestUpdateCommand', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_cli_test_update_');
      projectPath = tempDir.path;
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    Future<void> _seedOutdatedFeature() async {
      await Directory('$projectPath/lib/features/auth/state')
          .create(recursive: true);
      await File('$projectPath/lib/features/auth/state/auth_bloc.dart')
          .writeAsString('''
class AuthBloc {
  Future<void> login(String email, String password, bool rememberMe) async {}
}
''');
      await Directory('$projectPath/test/features/auth/state')
          .create(recursive: true);
      await File('$projectPath/test/features/auth/state/auth_bloc_test.dart')
          .writeAsString('''
void main() {
  final bloc = AuthBloc();
  bloc.login('a@test.com', 'password');
}
''');
    }

    test('requires a feature name', () async {
      final (output, code) = await _runUpdate(projectPath, []);

      expect(code, 1);
      expect(output.join('\n'), contains('Feature name is required'));
    });

    test('reports a clear error for an unknown feature', () async {
      final (output, code) = await _runUpdate(projectPath, ['billing']);

      expect(code, 1);
      expect(output.join('\n'), contains('No feature named "billing"'));
    });

    test('--dry-run shows the plan and writes nothing', () async {
      await _seedOutdatedFeature();

      final (output, code) =
          await _runUpdate(projectPath, ['auth', '--dry-run']);

      expect(code, 0);
      final text = output.join('\n');
      expect(text, contains('Confidence: HIGH'));
      expect(text, contains("'a@test.com', 'password'"));
      expect(text, contains("'a@test.com', 'password', false"));
      expect(text, contains('dry run'));

      final original = await File(
              '$projectPath/test/features/auth/state/auth_bloc_test.dart')
          .readAsString();
      expect(original, contains("bloc.login('a@test.com', 'password');"));
    });

    test('declining the confirmation writes nothing', () async {
      await _seedOutdatedFeature();

      final (output, code) = await _runUpdate(
        projectPath,
        ['auth'],
        confirm: (_) => false,
      );

      expect(code, 0);
      expect(output.join('\n'), contains('Operation cancelled'));
      final original = await File(
              '$projectPath/test/features/auth/state/auth_bloc_test.dart')
          .readAsString();
      expect(original, contains("bloc.login('a@test.com', 'password');"));
    });

    test(
        'confirming applies the update and reports successful '
        'verification when it genuinely passes', () async {
      await _seedOutdatedFeature();

      final (output, code) = await _runUpdate(
        projectPath,
        ['auth'],
        confirm: (_) => true,
        lifecycle: _lifecycleWithVerification(verifyPasses: true),
      );

      expect(code, 0);
      expect(output.join('\n'), contains('Applied 1 update'));
      expect(output.join('\n'), contains('Verification passed'));

      final updated = await File(
              '$projectPath/test/features/auth/state/auth_bloc_test.dart')
          .readAsString();
      expect(updated, contains("'a@test.com', 'password', false"));
    });

    test(
        'rolls back the change and reports failure when verification '
        'genuinely fails — never hides it, never leaves the file '
        'modified', () async {
      await _seedOutdatedFeature();
      final originalContent = await File(
              '$projectPath/test/features/auth/state/auth_bloc_test.dart')
          .readAsString();

      final (output, code) = await _runUpdate(
        projectPath,
        ['auth'],
        confirm: (_) => true,
        lifecycle: _lifecycleWithVerification(verifyPasses: false),
      );

      expect(code, 1);
      expect(output.join('\n'), contains('Verification failed'));
      expect(output.join('\n'), contains('Rolled back'));

      final afterRollback = await File(
              '$projectPath/test/features/auth/state/auth_bloc_test.dart')
          .readAsString();
      expect(afterRollback, originalContent);
    });

    test('--non-interactive applies without asking for confirmation', () async {
      await _seedOutdatedFeature();

      final (output, code) = await _runUpdate(
        projectPath,
        ['auth', '--non-interactive'],
        confirm: (_) => throw StateError('must not ask for confirmation'),
        lifecycle: _lifecycleWithVerification(verifyPasses: true),
      );

      expect(code, 0);
      expect(output.join('\n'), contains('Applied 1 update'));
    });

    test(
        'reports nothing to apply when there is no high-confidence '
        'update, without ever asking for confirmation', () async {
      await Directory('$projectPath/lib/features/auth').create(recursive: true);
      await File('$projectPath/lib/features/auth/auth.dart')
          .writeAsString('class Auth {}');

      final (output, code) = await _runUpdate(
        projectPath,
        ['auth'],
        confirm: (_) => throw StateError('must not ask for confirmation'),
      );

      expect(code, 0);
      expect(output.join('\n'), contains('No high-confidence updates'));
    });
  });
}
