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

Future<(List<String>, int)> _runGenerate(
  String projectPath,
  List<String> args, {
  bool Function(String)? confirm,
}) async {
  final runner = CommandRunner('smartwork', 'test')
    ..addCommand(TestCommand(projectPath: projectPath, confirm: confirm));
  final previousExitCode = exitCode;
  exitCode = 0;
  final output = await _captureOutput(
    () => runner.run(['test', 'generate', ...args]),
  );
  final result = exitCode;
  exitCode = previousExitCode;
  return (output, result);
}

/// Tests `smartwork test generate <feature>` — the CLI surface for
/// `TestGenerationLifecycle`.
void main() {
  group('TestGenerateCommand', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_cli_test_generate_');
      projectPath = tempDir.path;
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    Future<void> _seedFeature() async {
      await File('$projectPath/pubspec.yaml').create(recursive: true);
      await File('$projectPath/pubspec.yaml').writeAsString('name: demo_app\n');
      await Directory('$projectPath/lib/features/auth/state')
          .create(recursive: true);
      await File('$projectPath/lib/features/auth/state/login_cubit.dart')
          .writeAsString('class LoginCubit {}');
    }

    test('--dry-run shows the plan and writes nothing', () async {
      await _seedFeature();

      final (output, code) =
          await _runGenerate(projectPath, ['auth', '--dry-run']);

      expect(code, 0);
      expect(output.join('\n'), contains('login_cubit_test.dart'));
      expect(output.join('\n'), contains('dry run'));
      expect(
        await File(
                '$projectPath/test/features/auth/state/login_cubit_test.dart')
            .exists(),
        isFalse,
      );
    });

    test('declining the confirmation writes nothing', () async {
      await _seedFeature();

      final (output, code) = await _runGenerate(
        projectPath,
        ['auth'],
        confirm: (_) => false,
      );

      expect(code, 0);
      expect(output.join('\n'), contains('Operation cancelled'));
      expect(
        await File(
                '$projectPath/test/features/auth/state/login_cubit_test.dart')
            .exists(),
        isFalse,
      );
    });

    test('confirming writes the real test file', () async {
      await _seedFeature();

      final (output, code) = await _runGenerate(
        projectPath,
        ['auth'],
        confirm: (_) => true,
      );

      expect(code, 0);
      expect(output.join('\n'), contains('Wrote 1 test file'));
      final written =
          File('$projectPath/test/features/auth/state/login_cubit_test.dart');
      expect(await written.exists(), isTrue);
      expect(await written.readAsString(), contains('LoginCubit'));
    });

    test('--non-interactive writes without asking', () async {
      await _seedFeature();

      final (output, code) = await _runGenerate(
        projectPath,
        ['auth', '--non-interactive'],
        confirm: (_) => throw StateError('must not ask for confirmation'),
      );

      expect(code, 0);
      expect(output.join('\n'), contains('Wrote 1 test file'));
    });

    test('reports a clear error for an unknown feature', () async {
      final (output, code) = await _runGenerate(projectPath, ['billing']);

      expect(code, 1);
      expect(output.join('\n'), contains('No feature named "billing"'));
    });

    test('nothing to generate when every subject is already covered', () async {
      await _seedFeature();
      await Directory('$projectPath/test/features/auth/state')
          .create(recursive: true);
      await File('$projectPath/test/features/auth/state/login_cubit_test.dart')
          .writeAsString('void main() { LoginCubit(); }');

      final (output, code) = await _runGenerate(projectPath, ['auth']);

      expect(code, 0);
      expect(output.join('\n'), contains('Nothing to generate'));
    });
  });
}
