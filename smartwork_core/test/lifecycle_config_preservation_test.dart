import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// A real, previously-undetected data-loss bug found during the V1.1
/// pre-freeze cleanup audit: [FeatureLifecycle]/[ProjectTargetUpdater]/
/// [ServiceLifecycle] each used to hand-roll their own `ProjectConfig`
/// reconstruction after changing one field, naming only the fields each
/// happened to think mattered — silently dropping `fonts`/
/// `localization`/`splash`/`appIcon` from the persisted
/// `.smartwork/project.yaml` (and, for [ServiceLifecycle], corrupting
/// `pubspec.yaml`'s dependency sync too, since
/// `PubspecGenerator.resolveDependencies` reads `fonts`/`localization`
/// from whatever config it is given) every time `smartwork feature`/
/// `smartwork target`/`smartwork service` ran against a project that
/// had any of those four configured. Fixed by routing all three through
/// `ProjectConfig.copyWith` (see its own doc comment). These tests
/// exercise the real, end-to-end lifecycle call — not `copyWith`
/// directly (see `project_config_serialization_test.dart` for that) —
/// so a regression here would be caught even if a future change
/// bypassed `copyWith` again.
void main() {
  ProjectConfig fullyConfigured({Set<AppTarget>? appTargets}) => ProjectConfig(
        projectName: 'demo_app',
        appTargets: appTargets ?? {AppTarget.android},
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        fonts: FontConfig.google(GoogleFontConfig(family: 'Roboto')),
        localization: LocalizationConfig.enabled(
          supportedLocales: const ['en', 'es'],
          defaultLocale: 'en',
        ),
        initialFeatures: ['home'],
      );

  group('FeatureLifecycle preserves fonts/localization across add/remove', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() async {
      tempDir = Directory.systemTemp
          .createTempSync('smartwork_lifecycle_preservation_feature_');
      projectPath = tempDir.path;
      await ProjectGenerator(
        outputPath: projectPath,
        config: fullyConfigured(),
      ).generate();
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('addFeature', () async {
      await FeatureLifecycle().addFeature(
        projectPath: projectPath,
        feature: FeatureConfig(name: 'profile'),
      );

      final config = await ProjectConfigFile(projectPath: projectPath).read();
      expect(config.fonts.type, FontType.google);
      expect(config.fonts.google!.family, 'Roboto');
      expect(config.localization.enabled, isTrue);
      expect(config.localization.supportedLocales, ['en', 'es']);
    });

    test('removeFeature', () async {
      await FeatureLifecycle().addFeature(
        projectPath: projectPath,
        feature: FeatureConfig(name: 'profile'),
      );
      await FeatureLifecycle()
          .removeFeature(projectPath: projectPath, featureName: 'profile');

      final config = await ProjectConfigFile(projectPath: projectPath).read();
      expect(config.fonts.type, FontType.google);
      expect(config.localization.enabled, isTrue);
    });
  });

  group('ServiceLifecycle preserves fonts/localization across add/remove', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() async {
      tempDir = Directory.systemTemp
          .createTempSync('smartwork_lifecycle_preservation_service_');
      projectPath = tempDir.path;
      await ProjectGenerator(
        outputPath: projectPath,
        config: fullyConfigured(),
      ).generate();
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('addService', () async {
      await ServiceLifecycle().addService(
        projectPath: projectPath,
        serviceId: Service.analytics.id,
      );

      final config = await ProjectConfigFile(projectPath: projectPath).read();
      expect(config.fonts.type, FontType.google);
      expect(config.localization.enabled, isTrue);

      // The pubspec-corrupting half of this bug: `resolveDependencies`
      // reads `fonts`/`localization` off whatever config `_syncPubspec`
      // is given, so losing them also stripped `google_fonts`/
      // `flutter_localizations`/`intl` (and the `flutter:` SDK entry's
      // own continuation line) from pubspec.yaml.
      final pubspec = File('$projectPath/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('google_fonts:'));
      expect(pubspec, contains('flutter_localizations:'));
      expect(pubspec, contains('intl:'));
      expect(pubspec, contains('  generate: true'));
    });

    test('removeService', () async {
      await ServiceLifecycle().addService(
        projectPath: projectPath,
        serviceId: Service.analytics.id,
      );
      await ServiceLifecycle().removeService(
        projectPath: projectPath,
        serviceId: Service.analytics.id,
      );

      final config = await ProjectConfigFile(projectPath: projectPath).read();
      expect(config.fonts.type, FontType.google);
      expect(config.localization.enabled, isTrue);

      final pubspec = File('$projectPath/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('google_fonts:'));
      expect(pubspec, contains('flutter_localizations:'));
      expect(pubspec, contains('  generate: true'));
    });
  });

  group('ProjectTargetUpdater preserves fonts/localization across apply', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() async {
      tempDir = Directory.systemTemp
          .createTempSync('smartwork_lifecycle_preservation_target_');
      projectPath = tempDir.path;
      await ProjectGenerator(
        outputPath: projectPath,
        config: fullyConfigured(),
      ).generate();
      // ProjectGenerator.generate() only writes SmartWork's own content
      // — the real `android/` platform folder a genuine `smartwork
      // init` would have already created via FlutterBootstrap is
      // simulated here directly, so the Platforms validation phase
      // sees the pre-existing target as actually present on disk.
      Directory('$projectPath/android').createSync(recursive: true);
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('apply', () async {
      final config = await ProjectConfigFile(projectPath: projectPath).read();

      await ProjectTargetUpdater(
        flutterBootstrap: FlutterBootstrap(
          runProcess: (executable, arguments, {workingDirectory}) async {
            final platformsArg = arguments.firstWhere(
              (a) => a.startsWith('--platforms='),
              orElse: () => '',
            );
            final platforms = platformsArg.isEmpty
                ? <String>{}
                : platformsArg
                    .substring('--platforms='.length)
                    .split(',')
                    .toSet();
            for (final platform in platforms) {
              Directory('$projectPath/$platform').createSync(recursive: true);
            }
            return ProcessResult(0, 0, '', '');
          },
        ),
        projectValidator: ProjectValidator(
          runProcess: (executable, arguments, {workingDirectory}) async =>
              ProcessResult(0, 0, '', ''),
        ),
      ).apply(
        projectPath: projectPath,
        config: config,
        requestedTargets: {AppTarget.android, AppTarget.ios},
      );

      final updatedConfig =
          await ProjectConfigFile(projectPath: projectPath).read();
      expect(updatedConfig.fonts.type, FontType.google);
      expect(updatedConfig.fonts.google!.family, 'Roboto');
      expect(updatedConfig.localization.enabled, isTrue);
      expect(updatedConfig.localization.supportedLocales, ['en', 'es']);
    });
  });
}
