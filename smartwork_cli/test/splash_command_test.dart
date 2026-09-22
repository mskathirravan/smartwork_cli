import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/splash_command.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// A real, minimal, valid 4x4 PNG.
final List<int> _validPngBytes = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x04, //
  0x08, 0x02, 0x00, 0x00, 0x00, 0x26, 0x93, 0x09, //
  0x29, 0x00, 0x00, 0x00, 0x15, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x62, 0x62, 0x60, 0x60, 0xF8, //
  0xCF, 0x40, 0x01, 0x00, 0x00, 0xFF, 0xFF, 0x03, //
  0x00, 0x02, 0x9C, 0x01, 0x9E, 0x97, 0xF6, 0x25, //
  0x0F, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, //
  0x44, 0xAE, 0x42, 0x60, 0x82, //
];

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

/// Result of [_runSplashCommand]: the exit code and, if the command's
/// own argument parsing rejected the invocation before `run()` ever
/// executed, the [UsageException] that was thrown.
class _RunResult {
  final int exitCode;
  final UsageException? usageException;

  _RunResult({required this.exitCode, this.usageException});
}

Future<_RunResult> _runSplashCommand(
  String projectPath,
  List<String> args,
) async {
  final runner = CommandRunner('smartwork', 'test')
    ..addCommand(SplashCommand(projectPath: projectPath));
  final previousExitCode = exitCode;
  exitCode = 0;
  UsageException? usageException;
  try {
    await runner.run(['splash', ...args]);
  } on UsageException catch (e) {
    usageException = e;
  }
  final result = exitCode;
  exitCode = previousExitCode;
  return _RunResult(exitCode: result, usageException: usageException);
}

/// Tests `smartwork splash --background <hex> --icon <path>` (V1.1-8)
/// — the CLI surface for [SplashLifecycle.addSplash].
void main() {
  group('SplashCommand', () {
    late Directory tempDir;
    late String projectPath;
    late File iconFile;

    setUp(() async {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_cli_splash_test_');
      projectPath = tempDir.path;
      iconFile = File('${tempDir.path}_icon.png')
        ..writeAsBytesSync(_validPngBytes);

      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      );
      await ProjectGenerator(outputPath: projectPath, config: config)
          .generate();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
      if (iconFile.existsSync()) iconFile.deleteSync();
    });

    test('a valid invocation generates Splash and reports success', () async {
      late _RunResult result;
      final output = await _captureOutput(() async {
        result = await _runSplashCommand(
          projectPath,
          ['--background', '#2E7D32', '--icon', iconFile.path],
        );
      });
      final text = output.join('\n');

      expect(result.exitCode, 0);
      expect(result.usageException, isNull);
      expect(text, contains('Splash Screen updated'));
      expect(text, contains('lib/shared/ui/splash_screen.dart'));
      expect(
        File('$projectPath/lib/shared/ui/splash_screen.dart').existsSync(),
        isTrue,
      );
    });

    test('running again with different values updates Splash in place',
        () async {
      await _runSplashCommand(
        projectPath,
        ['--background', '#2E7D32', '--icon', iconFile.path],
      );

      final result = await _runSplashCommand(
        projectPath,
        ['--background', 'FF0000', '--icon', iconFile.path],
      );

      expect(result.exitCode, 0);
      final content = File('$projectPath/lib/shared/ui/splash_screen.dart')
          .readAsStringSync();
      expect(content, contains('Color(0xFFFF0000)'));
    });

    test('missing --icon is rejected with a clear usage message', () async {
      late _RunResult result;
      final output = await _captureOutput(() async {
        result = await _runSplashCommand(
          projectPath,
          ['--background', '#2E7D32'],
        );
      });

      expect(result.usageException, isNull);
      expect(result.exitCode, 1);
      expect(output.join('\n'), contains('Usage: smartwork splash'));
    });

    test('missing --background is rejected with a clear usage message',
        () async {
      late _RunResult result;
      final output = await _captureOutput(() async {
        result = await _runSplashCommand(
          projectPath,
          ['--icon', iconFile.path],
        );
      });

      expect(result.usageException, isNull);
      expect(result.exitCode, 1);
      expect(output.join('\n'), contains('Usage: smartwork splash'));
    });

    test('missing both --background and --icon is rejected the same way',
        () async {
      late _RunResult result;
      final output = await _captureOutput(() async {
        result = await _runSplashCommand(projectPath, []);
      });

      expect(result.exitCode, 1);
      expect(output.join('\n'), contains('Usage: smartwork splash'));
    });

    test('an invalid background color is reported clearly', () async {
      late _RunResult result;
      final output = await _captureOutput(() async {
        result = await _runSplashCommand(
          projectPath,
          ['--background', 'not-a-color', '--icon', iconFile.path],
        );
      });
      final text = output.join('\n');

      expect(result.exitCode, 1);
      expect(text, contains('background color'));
      expect(
        File('$projectPath/lib/shared/ui/splash_screen.dart').existsSync(),
        isFalse,
      );
    });

    test('a missing icon file is reported clearly', () async {
      late _RunResult result;
      final output = await _captureOutput(() async {
        result = await _runSplashCommand(
          projectPath,
          ['--background', '#2E7D32', '--icon', '/no/such/icon.png'],
        );
      });
      final text = output.join('\n');

      expect(result.exitCode, 1);
      expect(text, contains('not found'));
    });

    test('running in an uninitialized project is reported clearly', () async {
      final emptyDir =
          Directory.systemTemp.createTempSync('smartwork_no_project_');
      addTearDown(() => emptyDir.deleteSync(recursive: true));

      late _RunResult result;
      final output = await _captureOutput(() async {
        result = await _runSplashCommand(
          emptyDir.path,
          ['--background', '#2E7D32', '--icon', iconFile.path],
        );
      });
      final text = output.join('\n');

      expect(result.exitCode, 1);
      expect(text, contains('No Smartwork project found'));
    });
  });
}
