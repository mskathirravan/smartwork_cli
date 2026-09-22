import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/test_command.dart';
import 'package:test/test.dart';

/// Runs [body], capturing everything printed via `print()` during it.
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

Future<(List<String>, int)> _runAnalyze(
  String projectPath,
  List<String> args,
) async {
  final runner = CommandRunner('smartwork', 'test')
    ..addCommand(TestCommand(projectPath: projectPath));
  final previousExitCode = exitCode;
  exitCode = 0;
  final output = await _captureOutput(
    () => runner.run(['test', 'analyze', ...args]),
  );
  final result = exitCode;
  exitCode = previousExitCode;
  return (output, result);
}

/// Tests `smartwork test analyze <feature>` — the CLI surface for
/// `TestAnalysisLifecycle.analyze`. No SmartWork project is required:
/// this command works against any real `lib/features/<name>/` folder,
/// so these fixtures are built directly rather than through
/// `ProjectGenerator`, the same way `TestAnalysisLifecycle`'s own Core
/// tests do.
void main() {
  group('TestAnalyzeCommand', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_cli_test_analyze_');
      projectPath = tempDir.path;
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('requires a feature name', () async {
      final (output, code) = await _runAnalyze(projectPath, []);

      expect(code, 1);
      expect(output.join('\n'), contains('Feature name is required'));
    });

    test('reports a clear error for an unknown feature', () async {
      await Directory('$projectPath/lib/features/auth').create(recursive: true);
      await File('$projectPath/lib/features/auth/auth.dart')
          .writeAsString('class Auth {}');

      final (output, code) = await _runAnalyze(projectPath, ['billing']);

      expect(code, 1);
      expect(output.join('\n'), contains('No feature named "billing"'));
    });

    test(
        'prints a human-readable summary distinguishing covered from '
        'missing subjects', () async {
      await Directory('$projectPath/lib/features/auth/state')
          .create(recursive: true);
      await File('$projectPath/lib/features/auth/state/login_cubit.dart')
          .writeAsString('class LoginCubit {}');
      await Directory('$projectPath/test/features/auth/state')
          .create(recursive: true);
      await File('$projectPath/test/features/auth/state/login_cubit_test.dart')
          .writeAsString('void main() { LoginCubit(); }');
      await Directory('$projectPath/lib/features/auth/data')
          .create(recursive: true);
      await File('$projectPath/lib/features/auth/data/repo.dart')
          .writeAsString('class AuthRepositoryImpl {}');

      final (output, code) = await _runAnalyze(projectPath, ['auth']);
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Feature: auth'));
      expect(text, contains('LoginCubit — covered'));
      expect(text, contains('AuthRepositoryImpl — missing'));
    });

    test('--format json prints the complete TestAnalysis as JSON', () async {
      await Directory('$projectPath/lib/features/auth').create(recursive: true);
      await File('$projectPath/lib/features/auth/auth.dart')
          .writeAsString('class Auth {}');

      final (output, code) =
          await _runAnalyze(projectPath, ['auth', '--format', 'json']);

      expect(code, 0);
      expect(output, hasLength(1));
      expect(output.single, contains('"feature": "auth"'));
      expect(output.single, contains('"status": "missing"'));
    });

    test('--verbose includes each scenario\'s own reason', () async {
      await Directory('$projectPath/lib/features/auth').create(recursive: true);
      await File('$projectPath/lib/features/auth/auth.dart')
          .writeAsString('class Auth {}');

      final (withoutVerbose, _) = await _runAnalyze(projectPath, ['auth']);
      final (withVerbose, _) =
          await _runAnalyze(projectPath, ['auth', '--verbose']);

      expect(withoutVerbose.join('\n'), isNot(contains('No file under')));
      expect(withVerbose.join('\n'), contains('No file under'));
    });
  });
}
