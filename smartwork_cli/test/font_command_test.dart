@Tags(['cli-exit-code'])
import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/font_command.dart';
import 'package:smartwork_cli/src/commands/font_prompt.dart';
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

Future<int> _runFontCommand(
  String projectPath,
  FontSelection Function() promptFont,
) async {
  final runner = CommandRunner('smartwork', 'test')
    ..addCommand(FontCommand(projectPath: projectPath, promptFont: promptFont));
  final previousExitCode = exitCode;
  exitCode = 0;
  await runner.run(['font']);
  final result = exitCode;
  exitCode = previousExitCode;
  return result;
}

/// Tests `smartwork font` — the CLI surface for [FontLifecycle].
void main() {
  group('FontCommand', () {
    late Directory tempDir;
    late String projectPath;
    late File sourceFont;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_cli_font_test_');
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

      sourceFont = File('${tempDir.path}_source_font.ttf')
        ..writeAsBytesSync([0, 1, 2, 3]);
      addTearDown(() {
        if (sourceFont.existsSync()) sourceFont.deleteSync();
      });
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('updates to a Google Font and reports it', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runFontCommand(
          projectPath,
          () => FontSelection(
            fonts: FontConfig.google(GoogleFontConfig(family: 'Poppins')),
            includeHomeSample: false,
          ),
        );
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Font updated: Poppins (Google Font)'));

      final config = await ProjectConfigFile(projectPath: projectPath).read();
      expect(config.fonts.type, FontType.google);
    });

    test('updates to a Custom Font, copies the file, and reports it', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runFontCommand(
          projectPath,
          () => FontSelection(
            fonts: FontConfig.custom(
              CustomFontConfig(
                family: 'MyBrand',
                files: [CustomFontFile(sourcePath: sourceFont.path)],
              ),
            ),
            includeHomeSample: false,
          ),
        );
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('Font updated: MyBrand (Custom Font)'));
      expect(
        File('$projectPath/assets/fonts/${sourceFont.uri.pathSegments.last}')
            .existsSync(),
        isTrue,
      );
    });

    test(
        'includeHomeSample generates font_sample.dart and instructs the '
        'developer to embed it themselves', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runFontCommand(
          projectPath,
          () => FontSelection(
            fonts: FontConfig.google(GoogleFontConfig(family: 'Poppins')),
            includeHomeSample: true,
          ),
        );
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, contains('font_sample.dart generated'));
      expect(text, contains('Add const FontSample()'));
      expect(
        File('$projectPath/lib/shared/ui/font_sample.dart').existsSync(),
        isTrue,
      );
      final barrel =
          File('$projectPath/lib/shared/ui/shared_ui.dart').readAsStringSync();
      expect(barrel, contains("export 'font_sample.dart';"));

      final home = File(
        '$projectPath/lib/features/home/presentation/pages/home_page.dart',
      ).readAsStringSync();
      expect(home, isNot(contains('FontSample')),
          reason: 'smartwork font must never edit an existing Home page');
    });

    test('declining the sample never generates font_sample.dart', () async {
      late int code;
      final output = await _captureOutput(() async {
        code = await _runFontCommand(
          projectPath,
          () => FontSelection(
            fonts: FontConfig.google(GoogleFontConfig(family: 'Poppins')),
            includeHomeSample: false,
          ),
        );
      });
      final text = output.join('\n');

      expect(code, 0);
      expect(text, isNot(contains('font_sample.dart')));
      expect(
        File('$projectPath/lib/shared/ui/font_sample.dart').existsSync(),
        isFalse,
      );
    });

    test(
        'running in an uninitialized project is reported clearly, never '
        'prompting', () async {
      final emptyDir =
          Directory.systemTemp.createTempSync('smartwork_cli_font_empty_');
      addTearDown(() => emptyDir.deleteSync(recursive: true));

      var promptCalled = false;
      late int code;
      final output = await _captureOutput(() async {
        code = await _runFontCommand(emptyDir.path, () {
          promptCalled = true;
          return FontSelection(
            fonts: FontConfig.none(),
            includeHomeSample: false,
          );
        });
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('No Smartwork project found'));
      expect(promptCalled, isFalse);
    });

    test(
        'a missing custom font source file is reported clearly, without '
        'changing the project', () async {
      final configBefore =
          await ProjectConfigFile(projectPath: projectPath).read();

      late int code;
      final output = await _captureOutput(() async {
        code = await _runFontCommand(
          projectPath,
          () => FontSelection(
            fonts: FontConfig.custom(
              CustomFontConfig(
                family: 'MyBrand',
                files: [
                  CustomFontFile(sourcePath: '${tempDir.path}_missing.ttf'),
                ],
              ),
            ),
            includeHomeSample: false,
          ),
        );
      });
      final text = output.join('\n');

      expect(code, 1);
      expect(text, contains('Font file not found'));

      final configAfter =
          await ProjectConfigFile(projectPath: projectPath).read();
      expect(configAfter.fonts.type, configBefore.fonts.type);
    });
  });
}
