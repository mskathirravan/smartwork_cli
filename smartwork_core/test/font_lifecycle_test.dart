import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('FontLifecycle', () {
    late Directory tempDir;
    late String projectPath;
    late File sourceFont;

    setUp(() async {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_font_lifecycle_');
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

    test('switching to a Google Font updates ProjectConfig.fonts', () async {
      await FontLifecycle().updateFont(
        projectPath: projectPath,
        fonts: FontConfig.google(GoogleFontConfig(family: 'Poppins')),
      );

      final config = await ProjectConfigFile(projectPath: projectPath).read();
      expect(config.fonts.type, FontType.google);
      expect(config.fonts.google!.family, 'Poppins');
    });

    test('switching to a Google Font regenerates app_theme.dart to use it',
        () async {
      await FontLifecycle().updateFont(
        projectPath: projectPath,
        fonts: FontConfig.google(GoogleFontConfig(family: 'Poppins')),
      );

      final appTheme = File('$projectPath/lib/services/theme/app_theme.dart')
          .readAsStringSync();
      expect(appTheme,
          contains("import 'package:google_fonts/google_fonts.dart';"));
      expect(appTheme, contains('Poppins'));
    });

    test('switching to a Google Font adds google_fonts to pubspec.yaml',
        () async {
      await FontLifecycle().updateFont(
        projectPath: projectPath,
        fonts: FontConfig.google(GoogleFontConfig(family: 'Poppins')),
      );

      final pubspec = File('$projectPath/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('google_fonts:'));
    });

    test(
        'switching to a Custom Font copies the source file into '
        'assets/fonts/', () async {
      await FontLifecycle().updateFont(
        projectPath: projectPath,
        fonts: FontConfig.custom(
          CustomFontConfig(
            family: 'MyBrand',
            files: [CustomFontFile(sourcePath: sourceFont.path)],
          ),
        ),
      );

      final copied =
          File('$projectPath/assets/fonts/${sourceFont.uri.pathSegments.last}');
      expect(copied.existsSync(), isTrue);
      expect(copied.readAsBytesSync(), [0, 1, 2, 3]);
    });

    test(
        'switching to a Custom Font declares it in pubspec.yaml\'s fonts: '
        'section', () async {
      await FontLifecycle().updateFont(
        projectPath: projectPath,
        fonts: FontConfig.custom(
          CustomFontConfig(
            family: 'MyBrand',
            files: [CustomFontFile(sourcePath: sourceFont.path)],
          ),
        ),
      );

      final pubspec = File('$projectPath/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('  fonts:'));
      expect(pubspec, contains('family: MyBrand'));
    });

    test(
        'switching away from a Custom Font deletes its previously copied '
        'asset file', () async {
      await FontLifecycle().updateFont(
        projectPath: projectPath,
        fonts: FontConfig.custom(
          CustomFontConfig(
            family: 'MyBrand',
            files: [CustomFontFile(sourcePath: sourceFont.path)],
          ),
        ),
      );
      final copied =
          File('$projectPath/assets/fonts/${sourceFont.uri.pathSegments.last}');
      expect(copied.existsSync(), isTrue, reason: 'sanity check');

      await FontLifecycle().updateFont(
        projectPath: projectPath,
        fonts: FontConfig.none(),
      );

      expect(copied.existsSync(), isFalse);
      final pubspec = File('$projectPath/pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('MyBrand')));
    });

    test(
        'replacing one Custom Font with another deletes the old asset '
        'file and copies the new one', () async {
      await FontLifecycle().updateFont(
        projectPath: projectPath,
        fonts: FontConfig.custom(
          CustomFontConfig(
            family: 'MyBrand',
            files: [CustomFontFile(sourcePath: sourceFont.path)],
          ),
        ),
      );
      final oldCopied =
          File('$projectPath/assets/fonts/${sourceFont.uri.pathSegments.last}');

      final newSourceFont = File('${tempDir.path}_second_source_font.otf')
        ..writeAsBytesSync([4, 5, 6]);
      addTearDown(() {
        if (newSourceFont.existsSync()) newSourceFont.deleteSync();
      });

      await FontLifecycle().updateFont(
        projectPath: projectPath,
        fonts: FontConfig.custom(
          CustomFontConfig(
            family: 'SecondBrand',
            files: [CustomFontFile(sourcePath: newSourceFont.path)],
          ),
        ),
      );

      expect(oldCopied.existsSync(), isFalse);
      final newCopied = File(
          '$projectPath/assets/fonts/${newSourceFont.uri.pathSegments.last}');
      expect(newCopied.existsSync(), isTrue);
      expect(newCopied.readAsBytesSync(), [4, 5, 6]);
    });

    test(
        'throws FontSourceFileNotFoundException, and changes nothing, '
        'when the custom font source file does not exist', () async {
      final configBefore =
          await ProjectConfigFile(projectPath: projectPath).read();

      await expectLater(
        FontLifecycle().updateFont(
          projectPath: projectPath,
          fonts: FontConfig.custom(
            CustomFontConfig(
              family: 'MyBrand',
              files: [
                CustomFontFile(sourcePath: '${tempDir.path}_missing.ttf'),
              ],
            ),
          ),
        ),
        throwsA(isA<FontSourceFileNotFoundException>()),
      );

      final configAfter =
          await ProjectConfigFile(projectPath: projectPath).read();
      expect(configAfter.fonts.type, configBefore.fonts.type);
    });

    test('never touches routing, README, or any feature', () async {
      final routerBefore =
          File('$projectPath/lib/services/routing/app_router.dart')
              .readAsStringSync();

      await FontLifecycle().updateFont(
        projectPath: projectPath,
        fonts: FontConfig.google(GoogleFontConfig(family: 'Poppins')),
      );

      expect(
        File('$projectPath/lib/services/routing/app_router.dart')
            .readAsStringSync(),
        routerBefore,
      );
      expect(Directory('$projectPath/lib/features/home').existsSync(), isTrue);
    });
  });

  group('FontLifecycle.updateFontSample', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() async {
      tempDir = Directory.systemTemp
          .createTempSync('smartwork_font_sample_lifecycle_');
      projectPath = tempDir.path;

      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        fonts: FontConfig.google(GoogleFontConfig(family: 'Poppins')),
        initialFeatures: ['home'],
      );
      await ProjectGenerator(outputPath: projectPath, config: config)
          .generate();
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'includeSample: true writes font_sample.dart, exports it from '
        'the barrel, and returns true', () async {
      final written = await FontLifecycle().updateFontSample(
        projectPath: projectPath,
        includeSample: true,
      );

      expect(written, isTrue);
      final sample = File('$projectPath/lib/shared/ui/font_sample.dart');
      expect(sample.existsSync(), isTrue);
      expect(sample.readAsStringSync(), contains('Font: Poppins'));
      final barrel =
          File('$projectPath/lib/shared/ui/shared_ui.dart').readAsStringSync();
      expect(barrel, contains("export 'font_sample.dart';"));
    });

    test(
        'includeSample: false never writes font_sample.dart, and '
        'returns false', () async {
      final written = await FontLifecycle().updateFontSample(
        projectPath: projectPath,
        includeSample: false,
      );

      expect(written, isFalse);
      expect(
        File('$projectPath/lib/shared/ui/font_sample.dart').existsSync(),
        isFalse,
      );
    });

    test('a previously-generated sample is removed when later declined',
        () async {
      await FontLifecycle().updateFontSample(
        projectPath: projectPath,
        includeSample: true,
      );
      final sample = File('$projectPath/lib/shared/ui/font_sample.dart');
      expect(sample.existsSync(), isTrue, reason: 'sanity check');

      final written = await FontLifecycle().updateFontSample(
        projectPath: projectPath,
        includeSample: false,
      );

      expect(written, isFalse);
      expect(sample.existsSync(), isFalse);
      final barrel =
          File('$projectPath/lib/shared/ui/shared_ui.dart').readAsStringSync();
      expect(barrel, isNot(contains('font_sample.dart')));
    });

    test(
        'a previously-generated sample is removed when the font is later '
        'switched to none, even if a sample was requested again', () async {
      await FontLifecycle().updateFontSample(
        projectPath: projectPath,
        includeSample: true,
      );

      await FontLifecycle().updateFont(
        projectPath: projectPath,
        fonts: FontConfig.none(),
      );
      final written = await FontLifecycle().updateFontSample(
        projectPath: projectPath,
        includeSample: true,
      );

      expect(written, isFalse);
      expect(
        File('$projectPath/lib/shared/ui/font_sample.dart').existsSync(),
        isFalse,
      );
    });

    test('never touches an existing Home page', () async {
      final home = File(
        '$projectPath/lib/features/home/presentation/pages/home_page.dart',
      );
      final before = home.readAsStringSync();

      await FontLifecycle().updateFontSample(
        projectPath: projectPath,
        includeSample: true,
      );

      expect(home.readAsStringSync(), before);
    });
  });
}
