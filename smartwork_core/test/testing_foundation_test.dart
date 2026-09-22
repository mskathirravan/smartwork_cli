import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Generator tests for the Testing Foundation V1 milestone: verifies
/// [CoreTestGenerator]/[ProjectGenerator] actually write the expected
/// `test/core/...` structure, the Home feature test, architecture-
/// specific placement, and that existing feature test generation
/// ([FeatureContentGenerator]'s page/widgets tests) is untouched.
///
/// Like every other generator test in this package, these assert on
/// generated *content*, not runtime behavior — genuine `flutter test`
/// proof happens against the `tmp/` generated-project validation this
/// milestone also requires.
void main() {
  group('CoreTestGenerator / ProjectGenerator (Testing Foundation V1)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_testing_fnd_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'test/core/ carries only Constants + Environment, while '
        'Bootstrap/Network/Storage/Theme/Routing live under '
        'test/services/ and Debug under test/features/debug/', () async {
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

      final paths = ProjectPaths(projectRoot: tempDir.path);
      for (final file in [
        paths.testCoreConstantsFile,
        paths.testCoreEnvironmentFile,
        paths.testServicesBootstrapFile,
        paths.testServicesThemeServiceFile,
        paths.testServicesRoutingFile,
        paths.testServicesNetworkServiceFile,
        paths.testServicesStorageServiceFile,
        paths.testFeaturesDebugFileAt(['state', 'debug_bloc_test.dart']),
        paths.testFeaturesDebugPushTestServiceFile,
      ]) {
        expect(File(file).existsSync(), isTrue, reason: '$file missing');
      }
    });

    test('Home gets a page test under test/features/<homeFeatureName>/',
        () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: [],
        homeFeatureName: 'dashboard',
      );

      await ProjectGenerator(outputPath: tempDir.path, config: config)
          .generate();

      final testFile = File(
        path.join(
          tempDir.path,
          'test',
          'features',
          'dashboard',
          'dashboard_page_test.dart',
        ),
      );
      expect(testFile.existsSync(), isTrue);

      final content = testFile.readAsStringSync();
      expect(content, contains('testWidgets'));
      expect(content, contains('DashboardPage'));
      expect(content, isNot(contains('{{')));
    });

    test(
        'Debug gets both architecture-independent tests and an '
        'architecture-specific screen test', () async {
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

      final paths = ProjectPaths(projectRoot: tempDir.path);
      expect(
        File(paths.testFeaturesDebugFileAt(['state', 'debug_bloc_test.dart']))
            .existsSync(),
        isTrue,
      );
      expect(File(paths.testFeaturesDebugPushTestServiceFile).existsSync(),
          isTrue);
      expect(File(paths.testFeaturesDebugPageFileClean).existsSync(), isTrue);
    });

    test(
        'the architecture-specific Debug screen test is placed correctly '
        'per architecture, while the routing test imports Debug through '
        'its public barrel regardless of architecture', () async {
      for (final architecture in Architecture.values) {
        final dir =
            Directory.systemTemp.createTempSync('smartwork_testing_arch_');
        addTearDown(() => dir.deleteSync(recursive: true));

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: architecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: [],
        );

        await ProjectGenerator(outputPath: dir.path, config: config).generate();

        final paths = ProjectPaths(projectRoot: dir.path);
        final debugPageTestFile = switch (architecture) {
          Architecture.cleanArchitecture =>
            paths.testFeaturesDebugPageFileClean,
          Architecture.mvvm => paths.testFeaturesDebugPageFileMvvm,
          Architecture.mvp => paths.testFeaturesDebugPageFileMvp,
        };
        expect(
          File(debugPageTestFile).existsSync(),
          isTrue,
          reason: '$architecture: $debugPageTestFile missing',
        );

        final routingTestContent =
            File(paths.testServicesRoutingFile).readAsStringSync();
        expect(
          routingTestContent,
          contains("import 'package:demo_app/features/debug/debug.dart';"),
        );
      }
    });

    test('no unwanted test files or empty test directories are generated',
        () async {
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

      final paths = ProjectPaths(projectRoot: tempDir.path);

      // AssetConstants is an empty namespace with no consumer — no test
      // file exists for it.
      expect(
        File(path.join(
                paths.testCore, 'constants', 'asset_constants_test.dart'))
            .existsSync(),
        isFalse,
      );

      // No route_constants.dart anywhere, and no test framework/registry
      // directories.
      final allTestFiles = Directory(paths.test)
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path)
          .toList();
      expect(
        allTestFiles.where((p) => p.contains('route_constants')),
        isEmpty,
      );
      for (final forbidden in [
        'test/framework',
        'test/registry',
        'test/helpers',
        'test/core/testing',
      ]) {
        expect(
          Directory(path.join(tempDir.path, forbidden)).existsSync(),
          isFalse,
          reason: '$forbidden must not be generated (speculative testing '
              'infrastructure)',
        );
      }

      // Every directory under test/ actually contains at least one file
      // (no empty directories).
      for (final dir in Directory(paths.test)
          .listSync(recursive: true)
          .whereType<Directory>()) {
        final hasFile = dir.listSync().whereType<File>().isNotEmpty ||
            dir.listSync(recursive: true).whereType<File>().isNotEmpty;
        expect(hasFile, isTrue, reason: '${dir.path} is an empty directory');
      }
    });

    test(
        'package-name independence: an unusual project name never leaks '
        'the wrong way and every package: import in test/ matches it',
        () async {
      const oddProjectName = 'zephyr_quokka_ledger';
      final config = ProjectConfig(
        projectName: oddProjectName,
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: [],
      );

      await ProjectGenerator(outputPath: tempDir.path, config: config)
          .generate();

      final paths = ProjectPaths(projectRoot: tempDir.path);
      for (final file in Directory(paths.test)
          .listSync(recursive: true)
          .whereType<File>()) {
        final content = file.readAsStringSync();
        for (final match
            in RegExp(r"import 'package:([a-z0-9_]+)/").allMatches(content)) {
          final importedPackage = match.group(1)!;
          if (importedPackage == 'flutter' ||
              importedPackage == 'flutter_test' ||
              importedPackage == 'http' ||
              importedPackage == 'dio' ||
              importedPackage == 'shared_preferences' ||
              importedPackage == 'hive') {
            continue;
          }
          expect(
            importedPackage,
            oddProjectName,
            reason: '${file.path} imports package:$importedPackage/... which '
                'is neither a third-party dependency nor the configured '
                'project name',
          );
        }
      }
    });

    test(
        'routing, environment, theme, network, and storage tests are all '
        'generated with real, non-placeholder content', () async {
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

      final paths = ProjectPaths(projectRoot: tempDir.path);

      final routingContent =
          File(paths.testServicesRoutingFile).readAsStringSync();
      expect(routingContent, contains('AppRouter.home'));
      expect(routingContent, contains('AppRouter.debug'));
      expect(routingContent, isNot(contains('{{')));

      final environmentContent =
          File(paths.testCoreEnvironmentFile).readAsStringSync();
      expect(environmentContent, contains('EnvironmentManager'));
      expect(environmentContent, isNot(contains('{{')));

      final themeContent =
          File(paths.testServicesThemeServiceFile).readAsStringSync();
      expect(themeContent, contains('ThemeService'));
      expect(themeContent, isNot(contains('{{')));

      final networkContent =
          File(paths.testServicesNetworkServiceFile).readAsStringSync();
      expect(networkContent,
          contains('EnvironmentManager.instance.currentBaseUrl'));
      expect(networkContent, isNot(contains('example.com/probe')),
          reason: 'the base URL must never be a literal host');
      expect(networkContent, isNot(contains('{{')));

      final storageContent =
          File(paths.testServicesStorageServiceFile).readAsStringSync();
      expect(storageContent, contains("setString()/getString() round-trip"));
      expect(storageContent, isNot(contains('{{')));

      // No fake assertions anywhere in test/.
      for (final file in Directory(paths.test)
          .listSync(recursive: true)
          .whereType<File>()) {
        final content = file.readAsStringSync();
        expect(content, isNot(contains('expect(true, isTrue)')));
        expect(content, isNot(contains('TODO')));
      }
    });

    test('existing feature test generation (page/widgets) remains intact',
        () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: [],
      );

      final paths = ProjectPaths(projectRoot: tempDir.path);
      await ProjectGenerator(outputPath: tempDir.path, config: config)
          .generate();

      await FeatureGenerator().generate(
        FeatureConfig(
          name: 'auth',
          components: {
            ...FeatureConfig.standardComponents,
            FeatureComponent.widgets,
            FeatureComponent.tests,
          },
        ),
        config,
        paths,
        FileWriter(),
      );

      final pageTestFile = File(
          path.join(paths.test, 'features', 'auth', 'auth_page_test.dart'));
      expect(pageTestFile.existsSync(), isTrue);
      expect(pageTestFile.readAsStringSync(), contains('testWidgets'));

      // Widgets still generate a real source file (not a test) —
      // FeatureContentGenerator's existing behavior, unmodified by this
      // milestone.
      expect(
        File(path.join(
          paths.featurePath('auth'),
          'presentation/widgets/auth_widget.dart',
        )).existsSync(),
        isTrue,
      );
    });
  });
}
