import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/test_command.dart';
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

Future<(List<String>, int)> _runCheck(
  String projectPath,
  List<String> args,
) async {
  final runner = CommandRunner('smartwork', 'test')
    ..addCommand(TestCommand(projectPath: projectPath));
  final previousExitCode = exitCode;
  exitCode = 0;
  final output = await _captureOutput(
    () => runner.run(['test', 'check', ...args]),
  );
  final result = exitCode;
  exitCode = previousExitCode;
  return (output, result);
}

/// Tests `smartwork test check <feature>` — SmartWork's Test Guard.
void main() {
  group('TestCheckCommand', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_cli_test_check_');
      projectPath = tempDir.path;
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('exits 0 and reports pass when every subject is covered', () async {
      await Directory('$projectPath/lib/features/auth').create(recursive: true);
      await File('$projectPath/lib/features/auth/login_cubit.dart')
          .writeAsString('class LoginCubit {}');
      await Directory('$projectPath/test/features/auth')
          .create(recursive: true);
      await File('$projectPath/test/features/auth/login_cubit_test.dart')
          .writeAsString('void main() { LoginCubit(); }');

      final (output, code) = await _runCheck(projectPath, ['auth']);

      expect(code, 0);
      expect(output.join('\n'), contains('Test Guard passed'));
    });

    test('exits 1 and lists the reason when a subject is missing', () async {
      await Directory('$projectPath/lib/features/auth').create(recursive: true);
      await File('$projectPath/lib/features/auth/login_cubit.dart')
          .writeAsString('class LoginCubit {}');

      final (output, code) = await _runCheck(projectPath, ['auth']);

      expect(code, 1);
      final text = output.join('\n');
      expect(text, contains('Test Guard failed'));
      expect(text, contains('LoginCubit — missing'));
    });

    test('reports a clear error for an unknown feature', () async {
      final (output, code) = await _runCheck(projectPath, ['billing']);

      expect(code, 1);
      expect(output.join('\n'), contains('No feature named "billing"'));
    });

    test('--format json includes a guardPassed field', () async {
      await Directory('$projectPath/lib/features/auth').create(recursive: true);
      await File('$projectPath/lib/features/auth/login_cubit.dart')
          .writeAsString('class LoginCubit {}');

      final (output, code) =
          await _runCheck(projectPath, ['auth', '--format', 'json']);

      expect(code, 1);
      expect(output.single, contains('"guardPassed": false'));
    });

    test(
        'exits 1 when real coverage data on disk shows a covered '
        'scenario has an uncovered line (partial)', () async {
      await Directory('$projectPath/lib/features/auth').create(recursive: true);
      await File('$projectPath/lib/features/auth/login_cubit.dart')
          .writeAsString('class LoginCubit {}');
      await Directory('$projectPath/test/features/auth')
          .create(recursive: true);
      await File('$projectPath/test/features/auth/login_cubit_test.dart')
          .writeAsString('void main() { LoginCubit(); }');
      await Directory('$projectPath/coverage').create(recursive: true);
      await File('$projectPath/coverage/lcov.info').writeAsString('''
SF:lib/features/auth/login_cubit.dart
DA:1,1
DA:2,0
LF:2
LH:1
end_of_record
''');

      final (output, code) = await _runCheck(projectPath, ['auth']);

      expect(code, 1);
      final text = output.join('\n');
      expect(text, contains('Test Guard failed'));
      expect(text, contains('LoginCubit — partial'));
    });

    test(
        'exits 1 for a real method-call argument mismatch even though '
        'TestGapAnalyzer\'s own (constructor-only) status stays covered '
        '— regression: check originally only looked at TestScenario '
        'status, so a genuine method-signature mismatch the newer '
        'TestMaintenanceAnalyzer detects was silently invisible to the '
        'guard', () async {
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

      final (output, code) = await _runCheck(projectPath, ['auth']);

      expect(code, 1);
      final text = output.join('\n');
      expect(text, contains('Test Guard failed'));
      expect(text, contains('AuthBloc — outdated'));
      expect(text, contains('Confidence: HIGH'));
      expect(text, contains("'a@test.com', 'password', false"));
    });
  });
}
