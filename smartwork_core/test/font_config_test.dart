import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Fonts (V1.1-5): [FontConfig]/[CustomFontConfig]/[GoogleFontConfig]
/// model behavior, [ProjectConfig.fonts] serialization, and
/// [ConfigValidator] font rules. Real generated-source/pubspec behavior
/// is covered in `project_generator_test.dart`/`pubspec_generator_test.dart`.
void main() {
  late Directory tempDir;
  late String fontFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('smartwork_font_test_');
    fontFile = '${tempDir.path}/TestFont-Regular.ttf';
    File(fontFile).writeAsBytesSync([0, 1, 2, 3]);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  ProjectConfig baseConfig({FontConfig? fonts}) {
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

  group('FontConfig defaults', () {
    test('ProjectConfig defaults to FontConfig.none when omitted', () {
      final config = baseConfig();
      expect(config.fonts.type, FontType.none);
      expect(config.fonts.custom, isNull);
      expect(config.fonts.google, isNull);
    });

    test(
        'FontConfig.none/.custom/.google set type and the matching '
        'nested config, leaving the other null', () {
      final none = FontConfig.none();
      expect(none.type, FontType.none);
      expect(none.custom, isNull);
      expect(none.google, isNull);

      final custom = FontConfig.custom(
        CustomFontConfig(family: 'Foo', files: [
          CustomFontFile(sourcePath: fontFile),
        ]),
      );
      expect(custom.type, FontType.custom);
      expect(custom.custom, isNotNull);
      expect(custom.google, isNull);

      final google = FontConfig.google(GoogleFontConfig(family: 'Roboto'));
      expect(google.type, FontType.google);
      expect(google.google, isNotNull);
      expect(google.custom, isNull);
    });
  });

  group('CustomFontFile', () {
    test('assetFileName is the sourcePath\'s own basename', () {
      final file = CustomFontFile(sourcePath: '/a/b/MyFont-Bold.ttf');
      expect(file.assetFileName, 'MyFont-Bold.ttf');
    });

    test('weight/italic default to null/false when not given', () {
      final file = CustomFontFile(sourcePath: fontFile);
      expect(file.weight, isNull);
      expect(file.italic, isFalse);
    });
  });

  group('Serialization (ProjectConfig.toYaml/fromYaml)', () {
    test('round-trips FontType.none', () {
      final restored = ProjectConfig.fromYaml(baseConfig().toYaml());
      expect(restored.fonts.type, FontType.none);
    });

    test('round-trips a custom font, including weight/italic', () {
      final config = baseConfig(
        fonts: FontConfig.custom(CustomFontConfig(
          family: 'Schyler',
          files: [
            CustomFontFile(sourcePath: fontFile),
            CustomFontFile(sourcePath: fontFile, weight: 700, italic: true),
          ],
        )),
      );

      final restored = ProjectConfig.fromYaml(config.toYaml());

      expect(restored.fonts.type, FontType.custom);
      expect(restored.fonts.custom!.family, 'Schyler');
      expect(restored.fonts.custom!.files, hasLength(2));
      expect(restored.fonts.custom!.files[0].weight, isNull);
      expect(restored.fonts.custom!.files[0].italic, isFalse);
      expect(restored.fonts.custom!.files[1].weight, 700);
      expect(restored.fonts.custom!.files[1].italic, isTrue);
    });

    test('round-trips a Google Font', () {
      final config = baseConfig(
        fonts: FontConfig.google(GoogleFontConfig(family: 'Poppins')),
      );

      final restored = ProjectConfig.fromYaml(config.toYaml());

      expect(restored.fonts.type, FontType.google);
      expect(restored.fonts.google!.family, 'Poppins');
    });

    test(
        'fromYaml defaults to FontConfig.none when the "fonts" key is '
        'absent — every .smartwork/project.yaml written before V1.1-5', () {
      final yaml = baseConfig().toYaml()..remove('fonts');
      final restored = ProjectConfig.fromYaml(yaml);
      expect(restored.fonts.type, FontType.none);
    });

    test(
        'toYaml always includes a "fonts" key, matching every other '
        'field\'s "always present" convention', () {
      expect(baseConfig().toYaml(), contains('fonts'));
    });
  });

  group('ConfigValidator: fonts', () {
    test('FontType.none is always valid', () {
      final errors = ConfigValidator.validate(baseConfig());
      expect(
          errors.map((e) => e.toString()), isNot(contains(contains('font'))));
    });

    test('a valid custom font configuration produces no errors', () {
      final config = baseConfig(
        fonts: FontConfig.custom(CustomFontConfig(
          family: 'Schyler',
          files: [CustomFontFile(sourcePath: fontFile)],
        )),
      );
      expect(ConfigValidator.validate(config), isEmpty);
    });

    test('a valid Google Font configuration produces no errors', () {
      final config = baseConfig(
        fonts: FontConfig.google(GoogleFontConfig(family: 'Roboto')),
      );
      expect(ConfigValidator.validate(config), isEmpty);
    });

    test('custom font with an empty family is rejected', () {
      final config = baseConfig(
        fonts: FontConfig.custom(CustomFontConfig(
          family: '',
          files: [CustomFontFile(sourcePath: fontFile)],
        )),
      );
      final errors = ConfigValidator.validate(config);
      expect(errors.map((e) => e.toString()),
          contains(contains('family cannot be empty')));
    });

    test('custom font with no files is rejected', () {
      final config = baseConfig(
        fonts:
            FontConfig.custom(CustomFontConfig(family: 'Schyler', files: [])),
      );
      final errors = ConfigValidator.validate(config);
      expect(errors.map((e) => e.toString()),
          contains(contains('requires at least one font file')));
    });

    test('a missing font file is rejected with a clear message', () {
      final config = baseConfig(
        fonts: FontConfig.custom(CustomFontConfig(
          family: 'Schyler',
          files: [CustomFontFile(sourcePath: '${tempDir.path}/nope.ttf')],
        )),
      );
      final errors = ConfigValidator.validate(config);
      expect(errors.map((e) => e.toString()), contains(contains('not found')));
    });

    test('an unsupported font file extension is rejected', () {
      final wrongExt = '${tempDir.path}/font.woff';
      File(wrongExt).writeAsBytesSync([0]);
      final config = baseConfig(
        fonts: FontConfig.custom(CustomFontConfig(
          family: 'Schyler',
          files: [CustomFontFile(sourcePath: wrongExt)],
        )),
      );
      final errors = ConfigValidator.validate(config);
      expect(
          errors.map((e) => e.toString()), contains(contains('.ttf or .otf')));
    });

    test('an invalid font weight is rejected', () {
      final config = baseConfig(
        fonts: FontConfig.custom(CustomFontConfig(
          family: 'Schyler',
          files: [CustomFontFile(sourcePath: fontFile, weight: 450)],
        )),
      );
      final errors = ConfigValidator.validate(config);
      expect(errors.map((e) => e.toString()), contains(contains('invalid')));
    });

    test('google font with an empty family is rejected', () {
      final config = baseConfig(
        fonts: FontConfig.google(GoogleFontConfig(family: '  ')),
      );
      final errors = ConfigValidator.validate(config);
      expect(errors.map((e) => e.toString()),
          contains(contains('family cannot be empty')));
    });
  });
}
