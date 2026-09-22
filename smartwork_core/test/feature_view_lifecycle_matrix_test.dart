import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Feature View Lifecycle Cross-check: confirms `page` already is the
/// View/UI abstraction for all three architectures, with the correct,
/// architecture-specific folder placement, and that `smartwork feature
/// add`/`remove` (via [FeatureLifecycle]) generate/remove that
/// structure completely and keep routing synchronized — for every
/// architecture, not only Clean (the only one prior milestones'
/// `FeatureLifecycle`-level tests ever exercised).
///
/// No production code changes came out of this cross-check: `page`
/// already generates `presentation/pages/<name>_page.dart` (Clean) or
/// `views/<name>_page.dart` (MVVM/MVP) — exactly the folder each
/// architecture's own conventions call for — and
/// `FeatureLifecycle.removeFeature` already deletes the whole feature
/// directory regardless of architecture, so View removal was never
/// architecture-specific to begin with. These tests exist to prove
/// that via real execution, not to fix a bug.
void main() {
  group('Feature View lifecycle — architecture matrix', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() {
      tempDir = Directory.systemTemp
          .createTempSync('smartwork_view_lifecycle_matrix_');
      projectPath = tempDir.path;
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    /// The View/UI folder(s) `page` must produce for [architecture],
    /// per that architecture's own documented convention — never a
    /// generic, artificial `view/` folder common to all three.
    List<String> expectedViewFolders(Architecture architecture) {
      return switch (architecture) {
        Architecture.cleanArchitecture => ['presentation'],
        Architecture.mvvm => ['views', 'viewmodels'],
        Architecture.mvp => ['views', 'presenters'],
      };
    }

    /// The exact generated View/page file `page` must produce.
    String expectedPageFile(Architecture architecture, String featureName) {
      return switch (architecture) {
        Architecture.cleanArchitecture =>
          '$featureName/presentation/pages/${featureName}_page.dart',
        Architecture.mvvm ||
        Architecture.mvp =>
          '$featureName/views/${featureName}_page.dart',
      };
    }

    for (final architecture in Architecture.values) {
      group(architecture.name, () {
        late ProjectPaths paths;

        setUp(() async {
          paths = ProjectPaths(projectRoot: projectPath);
          final config = ProjectConfig(
            projectName: 'my_app',
            architecture: architecture,
            stateManagement: StateManagement.bloc,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: ['auth'],
          );
          await ProjectGenerator(outputPath: projectPath, config: config)
              .generate();
        });

        test(
            'add profile generates the architecture-correct View/UI '
            'structure — never an artificial common view/ folder', () async {
          await FeatureLifecycle().addFeature(
            projectPath: projectPath,
            feature: FeatureConfig(name: 'profile'),
          );

          for (final folder in expectedViewFolders(architecture)) {
            expect(
              Directory('${paths.featurePath('profile')}/$folder').existsSync(),
              isTrue,
              reason: '$architecture: expected $folder/ under profile/',
            );
          }
          expect(
            File(
              '${paths.features}/${expectedPageFile(architecture, 'profile')}',
            ).existsSync(),
            isTrue,
            reason: '$architecture: expected View file missing',
          );

          // Never an artificial, architecture-agnostic "view/" folder.
          expect(
            Directory('${paths.featurePath('profile')}/view').existsSync(),
            isFalse,
          );
        });

        test(
            'add profile registers its route in AppRouter, imported '
            'through the feature barrel, not an internal path', () async {
          await FeatureLifecycle().addFeature(
            projectPath: projectPath,
            feature: FeatureConfig(name: 'profile'),
          );

          final router = File(paths.servicesRoutingFile).readAsStringSync();
          expect(router, contains("case '/profile':"));
          expect(router, contains('ProfilePage'));
          expect(
            router,
            contains("import '../../features/profile/profile.dart';"),
          );
          expect(router, isNot(contains('presentation/pages/profile')));
          expect(router, isNot(contains('views/profile')));
        });

        test(
            'remove profile deletes the complete feature, including its '
            'View/UI files, and updates routing — while Home, Debug, '
            'and other features remain fully intact', () async {
          await FeatureLifecycle().addFeature(
            projectPath: projectPath,
            feature: FeatureConfig(name: 'profile'),
          );
          expect(
            Directory(paths.featurePath('profile')).existsSync(),
            isTrue,
          );

          final removeResult = await FeatureLifecycle().removeFeature(
            projectPath: projectPath,
            featureName: 'profile',
          );

          expect(removeResult.wasRouted, isTrue);
          expect(
            Directory(paths.featurePath('profile')).existsSync(),
            isFalse,
            reason: 'the entire profile/ directory, View included, must '
                'be gone',
          );

          final router = File(paths.servicesRoutingFile).readAsStringSync();
          expect(router, isNot(contains("case '/profile':")));
          expect(router, isNot(contains('Profile')));

          // Home, Debug, and the other pre-existing feature (auth) are
          // untouched by removing an unrelated feature.
          expect(Directory(paths.featurePath('home')).existsSync(), isTrue);
          expect(Directory(paths.featuresDebug).existsSync(), isTrue);
          expect(Directory(paths.featurePath('auth')).existsSync(), isTrue);
          expect(router, contains('HomePage'));
          expect(router, contains('DebugPage'));
          expect(router, contains("case '/auth':"));

          final config =
              await ProjectConfigFile(projectPath: projectPath).read();
          expect(config.initialFeatures, contains('auth'));
          expect(config.initialFeatures, isNot(contains('profile')));
        });

        test(
            'adding a feature that already exists is refused, never '
            'silently duplicating its View files or route', () async {
          await FeatureLifecycle().addFeature(
            projectPath: projectPath,
            feature: FeatureConfig(name: 'profile'),
          );

          await expectLater(
            FeatureLifecycle().addFeature(
              projectPath: projectPath,
              feature: FeatureConfig(name: 'profile'),
            ),
            throwsA(isA<FeatureAlreadyExistsException>()),
          );

          final router = File(paths.servicesRoutingFile).readAsStringSync();
          expect("case '/profile':".allMatches(router).length, 1);
        });

        test(
            'adding an ordinary feature literally named "debug" is refused '
            '— that directory is already the real framework Debug feature',
            () async {
          await expectLater(
            FeatureLifecycle().addFeature(
              projectPath: projectPath,
              feature: FeatureConfig(name: 'debug'),
            ),
            throwsA(isA<FeatureAlreadyExistsException>()),
          );

          // The real framework Debug capability is untouched.
          expect(Directory(paths.featuresDebug).existsSync(), isTrue);
          expect(File(paths.featuresDebugFile).existsSync(), isTrue);

          final router = File(paths.servicesRoutingFile).readAsStringSync();
          expect('case debug:'.allMatches(router).length, 1);
          expect(router, isNot(contains("case '/debug':")));
        });

        test('removing the configured Home feature is refused', () async {
          await expectLater(
            FeatureLifecycle().removeFeature(
              projectPath: projectPath,
              featureName: 'home',
            ),
            throwsA(isA<HomeFeatureNotRemovableException>()),
          );

          expect(Directory(paths.featurePath('home')).existsSync(), isTrue);
        });
      });
    }
  });

  group('Component dependency cross-check (View-relevant combinations)', () {
    Set<FeatureComponent> resolve(Set<FeatureComponent> requested) =>
        FeatureConfig(name: 'profile', components: requested)
            .resolveDependencies()
            .components;

    test('--components page requests exactly the View, nothing else', () {
      expect(resolve({FeatureComponent.page}), {FeatureComponent.page});
    });

    test(
        '--components page,widgets keeps both independent — neither '
        'pulls in the other or anything else', () {
      expect(
        resolve({FeatureComponent.page, FeatureComponent.widgets}),
        {FeatureComponent.page, FeatureComponent.widgets},
      );
    });

    test(
        '--components page,tests is already fully satisfied — tests '
        "requiring page adds nothing new when page is already requested", () {
      expect(
        resolve({FeatureComponent.page, FeatureComponent.tests}),
        {FeatureComponent.page, FeatureComponent.tests},
      );
    });

    test(
        '--components repository,useCase,dataSource,page resolves to '
        'exactly the domain/data layers plus the View, with no missing '
        'transitive dependency', () {
      expect(
        resolve({
          FeatureComponent.repository,
          FeatureComponent.useCase,
          FeatureComponent.dataSource,
          FeatureComponent.page,
        }),
        {
          FeatureComponent.repository,
          FeatureComponent.useCase,
          FeatureComponent.dataSource,
          FeatureComponent.page,
          FeatureComponent.entity,
        },
      );
    });
  });
}
