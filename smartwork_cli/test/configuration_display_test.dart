import 'dart:async';
import 'dart:io';

import 'package:smartwork_cli/src/commands/configuration_display.dart';
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Runs [body], capturing everything printed via `print()` during it —
/// the same convention `init_command_validation_test.dart` already
/// establishes.
Future<List<String>> _captureOutput(void Function() body) async {
  final lines = <String>[];
  await runZoned(
    () async => body(),
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines;
}

ProjectConfig _configWithFonts(FontConfig fonts) {
  return ProjectConfig(
    projectName: 'demo_app',
    architecture: Architecture.cleanArchitecture,
    stateManagement: StateManagement.bloc,
    network: Network.http,
    storage: Storage.sharedPreferences,
    fonts: fonts,
    initialFeatures: ['home'],
  );
}

ProjectConfig _configWithLocalization(LocalizationConfig localization) {
  return ProjectConfig(
    projectName: 'demo_app',
    architecture: Architecture.cleanArchitecture,
    stateManagement: StateManagement.bloc,
    network: Network.http,
    storage: Storage.sharedPreferences,
    localization: localization,
    initialFeatures: ['home'],
  );
}

/// V1.1-5: `ConfigurationDisplay`'s summary gained one new line for
/// `ProjectConfig.fonts` (a single categorical choice, like
/// Network/Storage — never a diff display, since none of those get one
/// either).
void main() {
  test('summary shows "None" when no font is configured', () async {
    final lines = await _captureOutput(
      () => ConfigurationDisplay().displaySummary(_configWithFonts(
        FontConfig.none(),
      )),
    );

    expect(lines, contains('Fonts:                  None'));
  });

  test('summary shows the custom font family', () async {
    final tempDir =
        Directory.systemTemp.createTempSync('smartwork_display_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final fontFile = '${tempDir.path}/Schyler-Regular.ttf';
    File(fontFile).writeAsBytesSync([0, 1, 2, 3]);

    final lines = await _captureOutput(
      () => ConfigurationDisplay().displaySummary(_configWithFonts(
        FontConfig.custom(CustomFontConfig(
          family: 'Schyler',
          files: [CustomFontFile(sourcePath: fontFile)],
        )),
      )),
    );

    expect(lines, contains('Fonts:                  Custom (Schyler)'));
  });

  test('summary shows the Google Font family', () async {
    final lines = await _captureOutput(
      () => ConfigurationDisplay().displaySummary(_configWithFonts(
        FontConfig.google(GoogleFontConfig(family: 'Poppins')),
      )),
    );

    expect(
      lines,
      contains('Fonts:                  Google Font (Poppins)'),
    );
  });

  test('summary shows "Disabled" when localization is off', () async {
    final lines = await _captureOutput(
      () => ConfigurationDisplay().displaySummary(_configWithLocalization(
        LocalizationConfig.disabled(),
      )),
    );

    expect(lines, contains('Localization:           Disabled'));
  });

  test('summary shows supported locales and the default', () async {
    final lines = await _captureOutput(
      () => ConfigurationDisplay().displaySummary(_configWithLocalization(
        LocalizationConfig.enabled(
          supportedLocales: ['en', 'fr', 'de'],
          defaultLocale: 'fr',
        ),
      )),
    );

    expect(
      lines,
      contains('Localization:           Enabled (en, fr, de; default: fr)'),
    );
  });
}
