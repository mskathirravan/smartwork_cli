@Tags(['cli-exit-code'])
import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/localization_command.dart';
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

Future<int> _runLocalizationCommand(
  String projectPath,
  LocalizationConfig Function() promptLocalization,
) async {
  final runner = CommandRunner('smartwork', 'test')
    ..addCommand(LocalizationCommand(
      projectPath: projectPath,
      promptLocalization: promptLocalization,
    ));
  final previousExitCode = exitCode;
  exitCode = 0;
  await runner.run(['localization']);
  final result = exitCode;
  exitCode = previousExitCode;
  return result;
}

/// Tests `smartwork localization` — the CLI surface for
/// [LocalizationLifecycle].
void main() {
  group('LocalizationCommand', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() async {
      tempDir = Directory.systemTemp
          .createTempSync('smartwork_cli_localization_test_');
      projectPath = tempDir.path;

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

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('enables localization, generates l10n files, and reports it',
        () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runLocalizationCommand(
          projectPath,
          () => LocalizationConfig.enabled(
            supportedLocales: ['en', 'fr'],
            defaultLocale: 'en',
          ),
        );
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Localization updated: en, fr (default: en)'));
      expect(File('$projectPath/l10n.yaml').existsSync(), isTrue);
      expect(File('$projectPath/lib/l10n/app_en.arb').existsSync(), isTrue);
      expect(File('$projectPath/lib/l10n/app_fr.arb').existsSync(), isTrue);
    });

    test('disables localization, preserving ARB files, and reports it',
        () async {
      await _runLocalizationCommand(
        projectPath,
        () => LocalizationConfig.enabled(
          supportedLocales: ['en'],
          defaultLocale: 'en',
        ),
      );

      late int code;
      final output = await _captureOutput(() async {
        code = await _runLocalizationCommand(
          projectPath,
          () => LocalizationConfig.disabled(),
        );
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Localization updated: disabled'));
      expect(File('$projectPath/l10n.yaml').existsSync(), isFalse);
      expect(File('$projectPath/lib/l10n/app_en.arb').existsSync(), isTrue);
    });

    test(
        'running in an uninitialized project is reported clearly, never '
        'prompting', () async {
      final emptyDir = Directory.systemTemp
          .createTempSync('smartwork_cli_localization_empty_');
      addTearDown(() => emptyDir.deleteSync(recursive: true));

      var promptCalled = false;
      late int code;
      final output = await _captureOutput(() async {
        code = await _runLocalizationCommand(emptyDir.path, () {
          promptCalled = true;
          return LocalizationConfig.disabled();
        });
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('No Smartwork project found'));
      expect(promptCalled, isFalse);
    });
  });
}
