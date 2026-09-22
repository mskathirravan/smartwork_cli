import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectConfig', () {
    test('toYaml converts config to map correctly', () {
      final config = ProjectConfig(
        projectName: 'my_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.dio,
        storage: Storage.hive,
        services: {'notification', 'analytics'},
        initialFeatures: ['home', 'profile'],
      );

      final yaml = config.toYaml();

      expect(yaml['projectName'], equals('my_app'));
      expect(yaml['architecture'], equals('cleanArchitecture'));
      expect(yaml['stateManagement'], equals('bloc'));
      expect(yaml['network'], equals('dio'));
      expect(yaml['storage'], equals('hive'));
      expect(yaml['services'], containsAll(['notification', 'analytics']));
      expect(yaml['initialFeatures'], equals(['home', 'profile']));
    });

    test('fromYaml creates config from map correctly', () {
      final yaml = {
        'projectName': 'test_app',
        'architecture': 'mvvm',
        'stateManagement': 'cubit',
        'network': 'http',
        'storage': 'sharedPreferences',
        'services': ['deeplink', 'crashReporting'],
        'initialFeatures': ['onboarding'],
      };

      final config = ProjectConfig.fromYaml(yaml);

      expect(config.projectName, equals('test_app'));
      expect(config.architecture, equals(Architecture.mvvm));
      expect(config.stateManagement, equals(StateManagement.cubit));
      expect(config.network, equals(Network.http));
      expect(config.storage, equals(Storage.sharedPreferences));
      expect(config.services, containsAll(['deeplink', 'crashReporting']));
      expect(config.initialFeatures, equals(['onboarding']));
    });

    test('fromYaml handles empty optional fields', () {
      final yaml = {
        'projectName': 'minimal_app',
        'architecture': 'cleanArchitecture',
        'stateManagement': 'bloc',
        'network': 'dio',
        'storage': 'hive',
      };

      final config = ProjectConfig.fromYaml(yaml);

      expect(config.projectName, equals('minimal_app'));
      expect(config.services, isEmpty);
      expect(config.initialFeatures, isEmpty);
    });

    test('roundtrip: toYaml -> fromYaml preserves config', () {
      final original = ProjectConfig(
        projectName: 'roundtrip_test',
        architecture: Architecture.mvvm,
        stateManagement: StateManagement.getx,
        network: Network.http,
        storage: Storage.sharedPreferences,
        services: {'logger', 'crashReporting'},
        initialFeatures: ['splash', 'dashboard'],
      );

      final yaml = original.toYaml();
      final restored = ProjectConfig.fromYaml(yaml);

      expect(restored.projectName, equals(original.projectName));
      expect(restored.architecture, equals(original.architecture));
      expect(restored.stateManagement, equals(original.stateManagement));
      expect(restored.network, equals(original.network));
      expect(restored.storage, equals(original.storage));
      expect(restored.services, equals(original.services));
      expect(restored.initialFeatures, equals(original.initialFeatures));
    });

    test(
        'roundtrip: Network.other/Storage.other survive toYaml/fromYaml '
        'as first-class values, not an error or a fallback', () {
      final original = ProjectConfig(
        projectName: 'other_roundtrip',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.other,
        storage: Storage.other,
        initialFeatures: ['home'],
      );

      final yaml = original.toYaml();
      expect(yaml['network'], equals('other'));
      expect(yaml['storage'], equals('other'));

      final restored = ProjectConfig.fromYaml(yaml);
      expect(restored.network, equals(Network.other));
      expect(restored.storage, equals(Storage.other));
    });

    test('MVP architecture is supported', () {
      final config = ProjectConfig(
        projectName: 'mvp_app',
        architecture: Architecture.mvp,
        stateManagement: StateManagement.bloc,
        network: Network.dio,
        storage: Storage.hive,
      );

      final yaml = config.toYaml();
      expect(yaml['architecture'], equals('mvp'));

      final restored = ProjectConfig.fromYaml(yaml);
      expect(restored.architecture, equals(Architecture.mvp));
    });

    test('Riverpod state management is supported', () {
      final config = ProjectConfig(
        projectName: 'riverpod_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.riverpod,
        network: Network.http,
        storage: Storage.sharedPreferences,
      );

      final yaml = config.toYaml();
      expect(yaml['stateManagement'], equals('riverpod'));

      final restored = ProjectConfig.fromYaml(yaml);
      expect(restored.stateManagement, equals(StateManagement.riverpod));
    });

    test('MVP + Riverpod combination is supported', () {
      final config = ProjectConfig(
        projectName: 'mvp_riverpod',
        architecture: Architecture.mvp,
        stateManagement: StateManagement.riverpod,
        network: Network.dio,
        storage: Storage.hive,
        initialFeatures: ['home', 'settings'],
      );

      final yaml = config.toYaml();
      final restored = ProjectConfig.fromYaml(yaml);

      expect(restored.architecture, equals(Architecture.mvp));
      expect(restored.stateManagement, equals(StateManagement.riverpod));
      expect(restored.initialFeatures, equals(['home', 'settings']));
    });

    group('copyWith', () {
      ProjectConfig fullyConfigured() => ProjectConfig(
            projectName: 'demo_app',
            appTargets: {AppTarget.android},
            architecture: Architecture.cleanArchitecture,
            stateManagement: StateManagement.bloc,
            network: Network.http,
            storage: Storage.sharedPreferences,
            services: {'secureSession'},
            fonts: FontConfig.google(GoogleFontConfig(family: 'Roboto')),
            localization: LocalizationConfig.enabled(
              supportedLocales: const ['en', 'es'],
              defaultLocale: 'en',
            ),
            splash: SplashConfig(
              backgroundColor: '#FFFFFF',
              iconPath: 'icon.png',
            ),
            appIcon: AppIconConfig(sourcePath: 'icon.png'),
            initialFeatures: ['home', 'profile'],
          );

      test(
          'changing appTargets/services/initialFeatures preserves every '
          'other field, including fonts/localization/splash/appIcon — '
          'the real, previously-undetected data-loss bug this '
          'milestone\'s own E2E audit found in FeatureLifecycle/'
          'ProjectTargetUpdater/ServiceLifecycle\'s own hand-rolled '
          'ProjectConfig reconstruction', () {
        final original = fullyConfigured();

        final updated = original.copyWith(
          appTargets: {AppTarget.android, AppTarget.ios},
          services: {'secureSession', 'analytics'},
          initialFeatures: ['home', 'profile', 'settings'],
        );

        expect(updated.appTargets, {AppTarget.android, AppTarget.ios});
        expect(updated.services, {'secureSession', 'analytics'});
        expect(updated.initialFeatures, ['home', 'profile', 'settings']);

        // Everything else survives untouched.
        expect(updated.projectName, original.projectName);
        expect(updated.architecture, original.architecture);
        expect(updated.stateManagement, original.stateManagement);
        expect(updated.network, original.network);
        expect(updated.storage, original.storage);
        expect(updated.fonts.type, FontType.google);
        expect(updated.fonts.google!.family, 'Roboto');
        expect(updated.localization.enabled, isTrue);
        expect(updated.localization.supportedLocales, ['en', 'es']);
        expect(updated.splash!.backgroundColor, 'FFFFFF');
        expect(updated.appIcon!.sourcePath, 'icon.png');
        expect(updated.homeFeatureName, original.homeFeatureName);
      });

      test('changing splash/appIcon preserves every other field', () {
        final original = fullyConfigured();

        final newSplash =
            SplashConfig(backgroundColor: '#000000', iconPath: 'new.png');
        final newAppIcon = AppIconConfig(sourcePath: 'new_icon.png');
        final updated =
            original.copyWith(splash: newSplash, appIcon: newAppIcon);

        expect(updated.splash, same(newSplash));
        expect(updated.appIcon, same(newAppIcon));
        expect(updated.appTargets, original.appTargets);
        expect(updated.services, original.services);
        expect(updated.fonts.type, FontType.google);
        expect(updated.localization.enabled, isTrue);
        expect(updated.initialFeatures, original.initialFeatures);
      });

      test('called with no arguments returns an equivalent config', () {
        final original = fullyConfigured();
        final copy = original.copyWith();

        expect(copy.toYaml(), original.toYaml());
      });
    });
  });
}
