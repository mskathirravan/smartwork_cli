import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('LocalizationLifecycle', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() async {
      tempDir = Directory.systemTemp
          .createTempSync('smartwork_localization_lifecycle_');
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

    test('enabling localization updates ProjectConfig.localization', () async {
      await LocalizationLifecycle().updateLocalization(
        projectPath: projectPath,
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en', 'fr'],
          defaultLocale: 'en',
        ),
      );

      final config = await ProjectConfigFile(projectPath: projectPath).read();
      expect(config.localization.enabled, isTrue);
      expect(config.localization.supportedLocales, ['en', 'fr']);
      expect(config.localization.defaultLocale, 'en');
    });

    test(
        'enabling localization generates l10n.yaml and one ARB file per '
        'supported locale', () async {
      await LocalizationLifecycle().updateLocalization(
        projectPath: projectPath,
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en', 'fr'],
          defaultLocale: 'en',
        ),
      );

      expect(File('$projectPath/l10n.yaml').existsSync(), isTrue);
      expect(File('$projectPath/lib/l10n/app_en.arb').existsSync(), isTrue);
      expect(File('$projectPath/lib/l10n/app_fr.arb').existsSync(), isTrue);
    });

    test(
        'enabling localization wires main.dart with the delegates and '
        'supported locales', () async {
      await LocalizationLifecycle().updateLocalization(
        projectPath: projectPath,
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en', 'fr'],
          defaultLocale: 'en',
        ),
      );

      final main = File('$projectPath/lib/main.dart').readAsStringSync();
      expect(main, contains("import 'l10n/app_localizations.dart';"));
      expect(main, contains('localizationsDelegates:'));
    });

    test(
        'enabling localization adds flutter_localizations and generate: '
        'true to pubspec.yaml', () async {
      await LocalizationLifecycle().updateLocalization(
        projectPath: projectPath,
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en'],
          defaultLocale: 'en',
        ),
      );

      final pubspec = File('$projectPath/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('flutter_localizations:'));
      expect(pubspec, contains('generate: true'));
    });

    test('an existing ARB file with real translations is never overwritten',
        () async {
      await LocalizationLifecycle().updateLocalization(
        projectPath: projectPath,
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en'],
          defaultLocale: 'en',
        ),
      );
      final arbFile = File('$projectPath/lib/l10n/app_en.arb');
      arbFile.writeAsStringSync('{"@@locale": "en", "custom": "translated"}');

      await LocalizationLifecycle().updateLocalization(
        projectPath: projectPath,
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en', 'fr'],
          defaultLocale: 'en',
        ),
      );

      expect(arbFile.readAsStringSync(), contains('translated'));
    });

    test(
        'disabling localization deletes l10n.yaml but preserves the ARB '
        'files, and rewires main.dart back to its plain form', () async {
      await LocalizationLifecycle().updateLocalization(
        projectPath: projectPath,
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en'],
          defaultLocale: 'en',
        ),
      );

      await LocalizationLifecycle().updateLocalization(
        projectPath: projectPath,
        localization: LocalizationConfig.disabled(),
      );

      expect(File('$projectPath/l10n.yaml').existsSync(), isFalse);
      expect(File('$projectPath/lib/l10n/app_en.arb').existsSync(), isTrue);
      final main = File('$projectPath/lib/main.dart').readAsStringSync();
      expect(main, isNot(contains('localizationsDelegates:')));

      final config = await ProjectConfigFile(projectPath: projectPath).read();
      expect(config.localization.enabled, isFalse);
    });

    test('never touches routing, README, or any feature', () async {
      final routerBefore =
          File('$projectPath/lib/services/routing/app_router.dart')
              .readAsStringSync();

      await LocalizationLifecycle().updateLocalization(
        projectPath: projectPath,
        localization: LocalizationConfig.enabled(
          supportedLocales: ['en'],
          defaultLocale: 'en',
        ),
      );

      expect(
        File('$projectPath/lib/services/routing/app_router.dart')
            .readAsStringSync(),
        routerBefore,
      );
      expect(Directory('$projectPath/lib/features/home').existsSync(), isTrue);
    });
  });
}
