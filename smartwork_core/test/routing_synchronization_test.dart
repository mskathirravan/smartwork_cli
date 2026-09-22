import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Routing Lifecycle Audit: [RoutingGenerator] is the one owner of the
/// generated project's complete routing state — it must produce a
/// route for every routable feature, exclude Home/Debug's reserved
/// names, and [FeatureLifecycle] must keep it synchronized whenever a
/// feature is added or removed.
void main() {
  group('RoutingGenerator — user feature routes', () {
    test(
        'generates an import and a case for each routable feature,'
        ' resolving to /<feature> -> <Feature>Page', () {
      final content = RoutingGenerator().generate(
        homeFeatureName: 'home',
        otherFeatures: ['auth', 'profile'],
      );

      expect(content, contains("import '../../features/auth/auth.dart';"));
      expect(
          content, contains("import '../../features/profile/profile.dart';"));
      expect(content, contains("case '/auth':"));
      expect(
          content,
          contains(
              'return MaterialPageRoute(builder: (_) => const AuthPage());'));
      expect(content, contains("case '/profile':"));
      expect(
        content,
        contains(
            'return MaterialPageRoute(builder: (_) => const ProfilePage());'),
      );
    });

    test(
        'never generates a route for the configured Home feature name'
        ' twice, even if it also appears in otherFeatures', () {
      final content = RoutingGenerator().generate(
        homeFeatureName: 'home',
        otherFeatures: ['home', 'auth'],
      );

      expect(content, isNot(contains("case '/home':")));
      expect(content, contains("case '/auth':"));
      // Home's own import/case must still appear exactly once.
      expect(
        "import '../../features/home/home.dart';".allMatches(content).length,
        1,
      );
    });

    test(
        'never generates an ordinary route for a feature literally named '
        '"debug" — it would collide with the fixed /debug route', () {
      final content = RoutingGenerator().generate(
        homeFeatureName: 'home',
        otherFeatures: ['debug', 'auth'],
      );

      // Only the framework Debug case exists; no duplicate `/debug`.
      expect("case debug:".allMatches(content).length, 1);
      expect(content, isNot(contains("case '/debug':")));
      expect(content, contains("case '/auth':"));
    });

    test('deduplicates a feature name repeated in otherFeatures', () {
      final content = RoutingGenerator().generate(
        homeFeatureName: 'home',
        otherFeatures: ['auth', 'auth'],
      );

      expect("case '/auth':".allMatches(content).length, 1);
    });

    test(
        'produces byte-identical output regardless of input order '
        '(sorted, deterministic)', () {
      final a = RoutingGenerator().generate(
        homeFeatureName: 'home',
        otherFeatures: ['settings', 'auth', 'profile'],
      );
      final b = RoutingGenerator().generate(
        homeFeatureName: 'home',
        otherFeatures: ['profile', 'settings', 'auth'],
      );

      expect(a, b);
    });

    test(
        'an empty otherFeatures list generates only Home and Debug — '
        'unsupported/absent features never leak a route', () {
      final content = RoutingGenerator().generate(
        homeFeatureName: 'home',
      );

      expect(content, contains('static const String home'));
      expect(content, contains('static const String debug'));
      expect(content, isNot(contains("case '/")));
    });

    test(
        'is architecture-independent — Debug is imported through its '
        'public barrel (features/debug/debug.dart), never an '
        'architecture-specific internal path', () {
      final content = RoutingGenerator().generate(
        homeFeatureName: 'home',
        otherFeatures: ['auth'],
      );

      expect(content, contains("case '/auth':"));
      expect(content, contains('AuthPage'));
      expect(content, contains("import '../../features/debug/debug.dart';"));
    });
  });

  group('FeatureLifecycle', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() async {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_lifecycle_test_');
      projectPath = tempDir.path;

      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: [],
      );
      await ProjectGenerator(outputPath: projectPath, config: config)
          .generate();
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('addFeature generates the feature and adds a route for it', () async {
      final result = await FeatureLifecycle().addFeature(
        projectPath: projectPath,
        feature: FeatureConfig(name: 'profile'),
      );

      expect(result.addedToRouting, isTrue);
      expect(
        Directory('$projectPath/lib/features/profile').existsSync(),
        isTrue,
      );

      final router = File('$projectPath/lib/services/routing/app_router.dart')
          .readAsStringSync();
      expect(router, contains("case '/profile':"));
      expect(router, contains('ProfilePage'));

      final config = await ProjectConfigFile(projectPath: projectPath).read();
      expect(config.initialFeatures, contains('profile'));
    });

    test(
        'addFeature also regenerates app_router.dart\'s own test, so it '
        'never goes stale relative to the router it exercises', () async {
      await FeatureLifecycle().addFeature(
        projectPath: projectPath,
        feature: FeatureConfig(name: 'profile'),
      );

      final routerTest =
          File('$projectPath/test/services/routing/app_router_test.dart')
              .readAsStringSync();
      expect(routerTest, contains("initialRoute: '/profile'"));
      expect(routerTest, contains('ProfilePage'));
      expect(routerTest, isNot(contains('{{')));
    });

    test(
        'removeFeature also regenerates app_router.dart\'s own test, so '
        'a removed feature is never left referenced in it', () async {
      await FeatureLifecycle().addFeature(
        projectPath: projectPath,
        feature: FeatureConfig(name: 'profile'),
      );
      await FeatureLifecycle()
          .removeFeature(projectPath: projectPath, featureName: 'profile');

      final routerTest =
          File('$projectPath/test/services/routing/app_router_test.dart')
              .readAsStringSync();
      expect(routerTest, isNot(contains('profile')));
      expect(routerTest, isNot(contains('Profile')));
    });

    test(
        'addFeature does not add a route for a feature generated '
        'without a page component', () async {
      final result = await FeatureLifecycle().addFeature(
        projectPath: projectPath,
        feature: FeatureConfig(
          name: 'shared_utils',
          components: {FeatureComponent.entity},
        ),
      );

      expect(result.addedToRouting, isFalse);

      final router = File('$projectPath/lib/services/routing/app_router.dart')
          .readAsStringSync();
      expect(router, isNot(contains('shared_utils')));

      final config = await ProjectConfigFile(projectPath: projectPath).read();
      expect(config.initialFeatures, isNot(contains('shared_utils')));
    });

    test('removeFeature deletes the feature and its route', () async {
      await FeatureLifecycle().addFeature(
        projectPath: projectPath,
        feature: FeatureConfig(name: 'profile'),
      );

      final result = await FeatureLifecycle()
          .removeFeature(projectPath: projectPath, featureName: 'profile');

      expect(result.wasRouted, isTrue);
      expect(
        Directory('$projectPath/lib/features/profile').existsSync(),
        isFalse,
      );

      final router = File('$projectPath/lib/services/routing/app_router.dart')
          .readAsStringSync();
      expect(router, isNot(contains('profile')));

      final config = await ProjectConfigFile(projectPath: projectPath).read();
      expect(config.initialFeatures, isNot(contains('profile')));
    });

    test('removeFeature also deletes the feature\'s generated tests', () async {
      await FeatureLifecycle().addFeature(
        projectPath: projectPath,
        feature: FeatureConfig(
          name: 'profile',
          components: {
            ...FeatureConfig.standardComponents,
            FeatureComponent.tests
          },
        ),
      );
      expect(
        Directory('$projectPath/test/features/profile').existsSync(),
        isTrue,
      );

      await FeatureLifecycle()
          .removeFeature(projectPath: projectPath, featureName: 'profile');

      expect(
        Directory('$projectPath/test/features/profile').existsSync(),
        isFalse,
      );
    });

    test(
        'removeFeature throws FeatureNotFoundException for a feature '
        'that was never generated', () async {
      await expectLater(
        FeatureLifecycle()
            .removeFeature(projectPath: projectPath, featureName: 'ghost'),
        throwsA(isA<FeatureNotFoundException>()),
      );
    });

    test('removeFeature refuses to remove the configured Home feature',
        () async {
      await expectLater(
        FeatureLifecycle()
            .removeFeature(projectPath: projectPath, featureName: 'home'),
        throwsA(isA<HomeFeatureNotRemovableException>()),
      );

      // Home must still be fully intact.
      expect(
        Directory('$projectPath/lib/features/home').existsSync(),
        isTrue,
      );
      final router = File('$projectPath/lib/services/routing/app_router.dart')
          .readAsStringSync();
      expect(router, contains('HomePage'));
    });

    test(
        'removeFeature refuses to remove the protected Debug feature, '
        'leaving it, its route, and the configuration completely '
        'untouched', () async {
      // Before: Debug genuinely exists.
      expect(
        Directory('$projectPath/lib/features/debug').existsSync(),
        isTrue,
      );
      final configBefore =
          await ProjectConfigFile(projectPath: projectPath).read();

      await expectLater(
        FeatureLifecycle()
            .removeFeature(projectPath: projectPath, featureName: 'debug'),
        throwsA(isA<DebugFeatureNotRemovableException>()),
      );

      // After: command rejected — Debug, its route, and the persisted
      // configuration are exactly as they were.
      expect(
        Directory('$projectPath/lib/features/debug').existsSync(),
        isTrue,
      );
      final router = File('$projectPath/lib/services/routing/app_router.dart')
          .readAsStringSync();
      expect(router, contains('DebugPage'));
      expect(router, contains("static const String debug = '/debug';"));

      final configAfter =
          await ProjectConfigFile(projectPath: projectPath).read();
      expect(configAfter.initialFeatures, configBefore.initialFeatures);
      expect(configAfter.architecture, configBefore.architecture);
      expect(configAfter.stateManagement, configBefore.stateManagement);
    });

    test(
        'synchronization: generate auth, profile, settings, then remove '
        'profile — the router contains auth/settings/home/debug and '
        'never profile', () async {
      for (final name in ['auth', 'profile', 'settings']) {
        await FeatureLifecycle().addFeature(
          projectPath: projectPath,
          feature: FeatureConfig(name: name),
        );
      }

      await FeatureLifecycle()
          .removeFeature(projectPath: projectPath, featureName: 'profile');

      final router = File('$projectPath/lib/services/routing/app_router.dart')
          .readAsStringSync();

      expect(router, contains("case '/auth':"));
      expect(router, contains("case '/settings':"));
      expect(router, contains('HomePage'));
      expect(router, contains('DebugPage'));
      expect(router, isNot(contains('profile')));
      expect(router, isNot(contains('Profile')));

      final config = await ProjectConfigFile(projectPath: projectPath).read();
      expect(config.initialFeatures, containsAll(['auth', 'settings']));
      expect(config.initialFeatures, isNot(contains('profile')));

      expect(
        Directory('$projectPath/lib/features/auth').existsSync(),
        isTrue,
      );
      expect(
        Directory('$projectPath/lib/features/settings').existsSync(),
        isTrue,
      );
      expect(
        Directory('$projectPath/lib/features/profile').existsSync(),
        isFalse,
      );
    });
  });

  group('smartwork init lifecycle — ProjectGenerator.generate() end-to-end',
      () {
    late Directory tempDir;

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'given initialFeatures: [auth, profile, settings], both '
        'app_router.dart and app_router_test.dart contain all three '
        'routes', () async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_init_route_');
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth', 'profile', 'settings'],
      );

      await ProjectGenerator(outputPath: tempDir.path, config: config)
          .generate();

      final paths = ProjectPaths(projectRoot: tempDir.path);
      final router = File(paths.servicesRoutingFile).readAsStringSync();
      final routerTest = File(paths.testServicesRoutingFile).readAsStringSync();

      for (final name in ['auth', 'profile', 'settings']) {
        final pascal = FeatureNames(name).pascal;
        expect(router, contains("case '/$name':"),
            reason: 'app_router.dart missing /$name');
        expect(router, contains('${pascal}Page'),
            reason: 'app_router.dart missing ${pascal}Page');
        expect(routerTest, contains("'/$name'"),
            reason: 'app_router_test.dart missing /$name');
        expect(routerTest, contains('${pascal}Page'),
            reason: 'app_router_test.dart missing ${pascal}Page');
      }
    });

    test(
        'a custom homeFeatureName ("dashboard") combined with other '
        'routable features works end-to-end through FeatureLifecycle '
        'add and remove, not just RoutingGenerator in isolation', () async {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_init_dashboard_');
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        homeFeatureName: 'dashboard',
        initialFeatures: ['auth'],
      );
      await ProjectGenerator(outputPath: tempDir.path, config: config)
          .generate();

      await FeatureLifecycle().addFeature(
        projectPath: tempDir.path,
        feature: FeatureConfig(name: 'profile'),
      );

      final paths = ProjectPaths(projectRoot: tempDir.path);
      var router = File(paths.servicesRoutingFile).readAsStringSync();
      var routerTest = File(paths.testServicesRoutingFile).readAsStringSync();

      expect(router, contains("case '/auth':"));
      expect(router, contains("case '/profile':"));
      expect(router, isNot(contains("case '/dashboard':")),
          reason: 'dashboard is Home — it must never get an ordinary '
              'feature route too');
      expect(router, contains('DashboardPage'));
      expect(routerTest, contains('DashboardPage'));
      expect(routerTest, contains("'the initial route resolves to Home'"));

      await FeatureLifecycle()
          .removeFeature(projectPath: tempDir.path, featureName: 'profile');

      router = File(paths.servicesRoutingFile).readAsStringSync();
      routerTest = File(paths.testServicesRoutingFile).readAsStringSync();
      expect(router, isNot(contains('profile')));
      expect(routerTest, isNot(contains('profile')));
      expect(router, contains("case '/auth':"));
      expect(router, contains('DashboardPage'));
    });

    test(
        'adding a feature that already exists never mutates project '
        'state or routing — the conflict is rejected before anything '
        'is written', () async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_dup_add_');
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: [],
      );
      await ProjectGenerator(outputPath: tempDir.path, config: config)
          .generate();

      await FeatureLifecycle().addFeature(
        projectPath: tempDir.path,
        feature: FeatureConfig(name: 'profile'),
      );

      final paths = ProjectPaths(projectRoot: tempDir.path);
      final routerBefore = File(paths.servicesRoutingFile).readAsStringSync();
      final configBefore =
          await ProjectConfigFile(projectPath: tempDir.path).read();

      await expectLater(
        FeatureLifecycle().addFeature(
          projectPath: tempDir.path,
          feature: FeatureConfig(name: 'profile'),
        ),
        throwsA(isA<FeatureAlreadyExistsException>()),
      );

      final routerAfter = File(paths.servicesRoutingFile).readAsStringSync();
      final configAfter =
          await ProjectConfigFile(projectPath: tempDir.path).read();

      expect(routerAfter, routerBefore);
      expect(configAfter.initialFeatures, configBefore.initialFeatures);
      expect("case '/profile':".allMatches(routerAfter).length, 1,
          reason: 'the route must never be duplicated');
    });

    test(
        'adding an ordinary feature literally named "debug" is refused '
        '— that directory is already the real framework Debug feature, '
        'generated at project creation', () async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_debug_name_');
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: [],
      );
      await ProjectGenerator(outputPath: tempDir.path, config: config)
          .generate();

      await expectLater(
        FeatureLifecycle().addFeature(
          projectPath: tempDir.path,
          feature: FeatureConfig(name: 'debug'),
        ),
        throwsA(isA<FeatureAlreadyExistsException>()),
      );

      final paths = ProjectPaths(projectRoot: tempDir.path);
      final router = File(paths.servicesRoutingFile).readAsStringSync();
      expect(router, isNot(contains("case '/debug':")),
          reason: 'only the framework Debug case (case debug:) may exist');
      expect('case debug:'.allMatches(router).length, 1);

      final savedConfig =
          await ProjectConfigFile(projectPath: tempDir.path).read();
      expect(savedConfig.initialFeatures, isNot(contains('debug')),
          reason: 'a refused add must never mutate initialFeatures');
    });
  });
}
