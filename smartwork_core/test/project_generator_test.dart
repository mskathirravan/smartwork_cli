import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectGenerator', () {
    late Directory tempDir;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_projectgen_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('writes .smartwork/project.yaml (existing behavior preserved)',
        () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );

      final generator =
          ProjectGenerator(outputPath: tempDir.path, config: config);
      await generator.generate();

      expect(
        File(path.join(tempDir.path, '.smartwork', 'project.yaml'))
            .existsSync(),
        isTrue,
      );
    });

    test('invokes architecture generation for a single feature', () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );

      final generator =
          ProjectGenerator(outputPath: tempDir.path, config: config);
      await generator.generate();

      final featurePath = path.join(tempDir.path, 'lib', 'features', 'auth');
      expect(Directory(path.join(featurePath, 'domain')).existsSync(), isTrue);
      expect(Directory(path.join(featurePath, 'data')).existsSync(), isTrue);
      expect(
        Directory(path.join(featurePath, 'presentation')).existsSync(),
        isTrue,
      );
    });

    test('invokes state-management generation for a single feature', () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );

      final generator =
          ProjectGenerator(outputPath: tempDir.path, config: config);
      await generator.generate();

      final statePath =
          path.join(tempDir.path, 'lib', 'features', 'auth', 'state');
      expect(File(path.join(statePath, 'auth_bloc.dart')).existsSync(), isTrue);
      expect(
        File(path.join(statePath, 'auth_event.dart')).existsSync(),
        isTrue,
      );
      expect(
        File(path.join(statePath, 'auth_state.dart')).existsSync(),
        isTrue,
      );
    });

    test('generates every feature listed in initialFeatures', () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth', 'profile'],
      );

      final generator =
          ProjectGenerator(outputPath: tempDir.path, config: config);
      final result = await generator.generate();

      expect(
        Directory(path.join(tempDir.path, 'lib', 'features', 'auth'))
            .existsSync(),
        isTrue,
      );
      expect(
        Directory(path.join(tempDir.path, 'lib', 'features', 'profile'))
            .existsSync(),
        isTrue,
      );
      // Home is always generated in addition to initialFeatures.
      expect(
        Directory(path.join(tempDir.path, 'lib', 'features', 'home'))
            .existsSync(),
        isTrue,
      );
      expect(result.featureCount, 3);
    });

    test('reports aggregate file/directory counts across all features',
        () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth', 'profile'],
      );

      final generator =
          ProjectGenerator(outputPath: tempDir.path, config: config);
      final result = await generator.generate();

      final authFeature = Directory(
        path.join(tempDir.path, 'lib', 'features', 'auth'),
      ).listSync(recursive: true);
      final profileFeature = Directory(
        path.join(tempDir.path, 'lib', 'features', 'profile'),
      ).listSync(recursive: true);
      // Home is always generated in addition to initialFeatures.
      final homeFeature = Directory(
        path.join(tempDir.path, 'lib', 'features', 'home'),
      ).listSync(recursive: true);

      final expectedFiles = authFeature.whereType<File>().length +
          profileFeature.whereType<File>().length +
          homeFeature.whereType<File>().length;
      final expectedDirs = authFeature.whereType<Directory>().length +
          profileFeature.whereType<Directory>().length +
          homeFeature.whereType<Directory>().length;

      expect(result.fileCount, expectedFiles);
      expect(result.directoryCount, expectedDirs);
    });

    test('empty initialFeatures still generates the default Home feature',
        () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: [],
      );

      final generator =
          ProjectGenerator(outputPath: tempDir.path, config: config);
      final result = await generator.generate();

      // Home is always generated, even with no initialFeatures.
      expect(result.featureCount, 1);
      expect(result.fileCount, greaterThan(0));
      expect(
        File(path.join(tempDir.path, '.smartwork', 'project.yaml'))
            .existsSync(),
        isTrue,
      );
      expect(
        Directory(path.join(tempDir.path, 'lib', 'features', 'home'))
            .existsSync(),
        isTrue,
      );
    });

    test(
        're-running generate does not silently overwrite already-generated '
        'features', () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.mvvm,
        stateManagement: StateManagement.riverpod,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );

      final generator =
          ProjectGenerator(outputPath: tempDir.path, config: config);
      await generator.generate();

      // Re-running init-style generation must refuse rather than silently
      // regenerate a feature that already has content on disk — the same
      // safety guarantee `smartwork feature <name>` provides, inherited
      // here because ProjectGenerator delegates to FeatureGenerator.
      expect(
        () => generator.generate(),
        throwsA(isA<FeatureAlreadyExistsException>()),
      );
    });

    test('propagates a clear failure for an invalid feature name', () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['Invalid-Name'],
      );

      final generator =
          ProjectGenerator(outputPath: tempDir.path, config: config);

      expect(
        () => generator.generate(),
        throwsA(isA<InvalidFeatureNameException>()),
      );
    });

    group('all 12 architecture x state-management combinations', () {
      for (final architecture in Architecture.values) {
        for (final stateManagement in StateManagement.values) {
          test('$architecture + $stateManagement composes correctly', () async {
            final combinationDir = Directory.systemTemp
                .createTempSync('smartwork_projectgen_matrix_');
            addTearDown(() => combinationDir.deleteSync(recursive: true));

            final config = ProjectConfig(
              projectName: 'demo_app',
              architecture: architecture,
              stateManagement: stateManagement,
              network: Network.http,
              storage: Storage.sharedPreferences,
              initialFeatures: ['home'],
            );

            final generator = ProjectGenerator(
              outputPath: combinationDir.path,
              config: config,
            );
            final result = await generator.generate();

            expect(
              File(path.join(
                combinationDir.path,
                '.smartwork',
                'project.yaml',
              )).existsSync(),
              isTrue,
            );
            expect(
              Directory(path.join(
                combinationDir.path,
                'lib',
                'features',
                'home',
              )).existsSync(),
              isTrue,
            );
            expect(result.fileCount, greaterThan(0));
            expect(result.featureCount, 1);
          });
        }
      }
    });

    group('pubspec.yaml generation', () {
      test('generate() produces a pubspec.yaml alongside project.yaml',
          () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        final generator =
            ProjectGenerator(outputPath: tempDir.path, config: config);
        await generator.generate();

        expect(
          File(path.join(tempDir.path, 'pubspec.yaml')).existsSync(),
          isTrue,
        );
      });

      test(
          'the generated pubspec reflects this project\'s architecture, '
          'state management, and network choice', () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.mvvm,
          stateManagement: StateManagement.riverpod,
          network: Network.dio,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        final generator =
            ProjectGenerator(outputPath: tempDir.path, config: config);
        await generator.generate();

        final content =
            File(path.join(tempDir.path, 'pubspec.yaml')).readAsStringSync();
        expect(content, contains('name: demo_app'));
        expect(RegExp(r'  riverpod: \^\d+\.\d+\.\d+').hasMatch(content), isTrue,
            reason: 'riverpod must be declared with a real semver, whether '
                'resolved live or from the offline fallback:\n$content');
        expect(RegExp(r'  dio: \^\d+\.\d+\.\d+').hasMatch(content), isTrue,
            reason: 'dio must be declared with a real semver, whether '
                'resolved live or from the offline fallback:\n$content');
        expect(content, isNot(contains('get:')));
        expect(content, isNot(contains('http:')));
      });

      test(
          'pubspec generation does not affect feature scaffolding '
          '(regression)', () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        final generator =
            ProjectGenerator(outputPath: tempDir.path, config: config);
        final result = await generator.generate();

        expect(result.featureCount, 1);
        expect(
          Directory(path.join(tempDir.path, 'lib', 'features', 'home'))
              .existsSync(),
          isTrue,
        );
      });
    });

    group('bootstrap generation (Core Constants V1)', () {
      test(
          'generates exactly the eight expected constants files — no '
          'speculative extras, and no route_constants.dart', () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await ProjectGenerator(outputPath: tempDir.path, config: config)
            .generate();

        final constantsDir =
            Directory(path.join(tempDir.path, 'lib', 'core', 'constants'));
        final generatedFiles = constantsDir
            .listSync()
            .whereType<File>()
            .map((f) => path.basename(f.path))
            .toSet();

        expect(
          generatedFiles,
          {
            'app_constants.dart',
            'api_constants.dart',
            'asset_constants.dart',
            'storage_constants.dart',
            'app_colors.dart',
            'app_dimensions.dart',
            'screen_dimensions.dart',
            'constants.dart',
          },
          reason: 'exactly the framework-namespace constants files — '
              'routing is deliberately not part of this foundation, so '
              'route_constants.dart must never appear',
        );
      });

      test(
          'generates exactly the six expected utilities files, in the '
          'sibling lib/core/utilities/ folder, never inside '
          'lib/core/constants/ — the five approved general-purpose '
          'utilities from the Constants & Utils gap analysis, and no '
          'other speculative extra', () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await ProjectGenerator(outputPath: tempDir.path, config: config)
            .generate();

        final utilitiesDir =
            Directory(path.join(tempDir.path, 'lib', 'core', 'utilities'));
        final generatedFiles = utilitiesDir
            .listSync()
            .whereType<File>()
            .map((f) => path.basename(f.path))
            .toSet();

        expect(
          generatedFiles,
          {
            'app_platform.dart',
            'date_time_extensions.dart',
            'string_extensions.dart',
            'color_hex.dart',
            'file_size.dart',
            'utilities.dart',
          },
          reason: 'exactly the five approved general-purpose utilities '
              'plus their barrel — no validation, currency, debounce/'
              'throttle, or other speculative utility the gap analysis '
              'explicitly rejected',
        );

        final constantsDir =
            Directory(path.join(tempDir.path, 'lib', 'core', 'constants'));
        final constantsFiles = constantsDir
            .listSync()
            .whereType<File>()
            .map((f) => path.basename(f.path))
            .toSet();
        for (final utilityFile in generatedFiles) {
          expect(constantsFiles, isNot(contains(utilityFile)),
              reason: '$utilityFile must live only under '
                  'lib/core/utilities/, never duplicated into '
                  'lib/core/constants/');
        }
      });

      test('app_constants.dart declares appName from ProjectConfig.projectName',
          () async {
        final config = ProjectConfig(
          projectName: 'my_cool_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await ProjectGenerator(outputPath: tempDir.path, config: config)
            .generate();

        final content = File(path.join(
                tempDir.path, 'lib', 'core', 'constants', 'app_constants.dart'))
            .readAsStringSync();

        expect(content, contains('class AppConstants'));
        expect(content, contains("static const appName = 'my_cool_app';"));
        // No fabricated fields beyond what the current generator
        // actually needs.
        expect(content, isNot(contains('fromJson')));
      });

      test(
          'constants.dart is a barrel exporting all six non-app-only '
          'constant files, via relative exports, with no route export',
          () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await ProjectGenerator(outputPath: tempDir.path, config: config)
            .generate();

        final content = File(path.join(
                tempDir.path, 'lib', 'core', 'constants', 'constants.dart'))
            .readAsStringSync();

        expect(content, contains("export 'app_constants.dart';"));
        expect(content, contains("export 'api_constants.dart';"));
        expect(content, contains("export 'asset_constants.dart';"));
        expect(content, contains("export 'storage_constants.dart';"));
        expect(content, contains("export 'app_colors.dart';"));
        expect(content, contains("export 'app_dimensions.dart';"));
        expect(content, contains("export 'screen_dimensions.dart';"));
        expect(content, isNot(contains('route')));
        expect(content, isNot(contains('package:')));
      });

      test(
          'lib/main.dart is generated even when initialFeatures is empty, '
          'with the fixed routing-based shape', () async {
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

        final content = File(path.join(tempDir.path, 'lib', 'main.dart'))
            .readAsStringSync();

        expect(
            content, contains("import 'services/bootstrap/bootstrap.dart';"));
        expect(content, contains("import 'core/constants/constants.dart';"));
        expect(content, contains("import 'services/routing/app_router.dart';"));
        expect(
            content, contains("import 'services/theme/theme_service.dart';"));
        expect(content, contains('Future<void> main() async {'));
        expect(content, contains('WidgetsFlutterBinding.ensureInitialized();'));
        expect(content, contains('await Bootstrap.initialize();'));
        expect(content, contains('runApp(const MyApp());'));
        expect(content, contains('class MyApp extends StatelessWidget'));
        expect(content, contains('listenable: ThemeService.instance'));
        expect(content, contains('onGenerateRoute: AppRouter.onGenerateRoute'));
        expect(content, contains('initialRoute: AppRouter.home'));
        expect(content, isNot(contains('{{')));

        // Bootstrap must run strictly before runApp().
        final bootstrapCallIndex = content.indexOf('Bootstrap.initialize()');
        final runAppIndex = content.indexOf('runApp(');
        expect(bootstrapCallIndex, greaterThan(0));
        expect(bootstrapCallIndex, lessThan(runAppIndex));
      });

      test(
          'lib/main.dart never references any feature directly — Home is '
          'resolved through routing, not initialFeatures, regardless of '
          'architecture', () async {
        for (final architecture in Architecture.values) {
          final dir =
              Directory.systemTemp.createTempSync('smartwork_bootstrap_');
          addTearDown(() => dir.deleteSync(recursive: true));

          final config = ProjectConfig(
            projectName: 'demo_app',
            architecture: architecture,
            stateManagement: StateManagement.bloc,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: ['home', 'settings'],
          );

          await ProjectGenerator(outputPath: dir.path, config: config)
              .generate();

          final content =
              File(path.join(dir.path, 'lib', 'main.dart')).readAsStringSync();

          expect(
            content,
            isNot(contains("import 'features/")),
            reason: '$architecture: main.dart must never import a feature '
                'directly — AppRouter owns resolving Home',
          );
          expect(content, isNot(contains('package:demo_app')),
              reason: 'internal imports must not depend on the '
                  'project package name');
          expect(content, isNot(contains('SettingsPage')),
              reason: 'main.dart never names a feature Page directly');
          expect(content, isNot(contains('HomePage')),
              reason: 'main.dart never names a feature Page directly');
        }
      });

      test(
          'the generated app class name is always the fixed "MyApp" — '
          'never derived from (and so never awkward for) the project '
          'name', () async {
        for (final projectName in ['demo_app', 'crimson_falcon_toolkit']) {
          final dir =
              Directory.systemTemp.createTempSync('smartwork_bootstrap_');
          addTearDown(() => dir.deleteSync(recursive: true));

          final config = ProjectConfig(
            projectName: projectName,
            architecture: Architecture.cleanArchitecture,
            stateManagement: StateManagement.bloc,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: [],
          );

          await ProjectGenerator(outputPath: dir.path, config: config)
              .generate();

          final content =
              File(path.join(dir.path, 'lib', 'main.dart')).readAsStringSync();

          expect(content, contains('class MyApp extends StatelessWidget'));
          expect(content, contains('runApp(const MyApp());'));
        }
      });
    });

    group('bootstrap.dart generation (Bootstrap Guard V1)', () {
      test(
          'lib/services/bootstrap/bootstrap.dart is generated with a '
          'single Bootstrap.initialize() entry point', () async {
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

        final bootstrapFile = File(path.join(
            tempDir.path, 'lib', 'services', 'bootstrap', 'bootstrap.dart'));
        expect(bootstrapFile.existsSync(), isTrue);

        final content = bootstrapFile.readAsStringSync();
        expect(content, contains('class Bootstrap'));
        expect(content, contains('static Future<void> initialize() async {'));
        expect(content, isNot(contains('{{')));
      });

      test('bootstrap.dart contains no feature-specific or business logic',
          () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth'],
        );

        await ProjectGenerator(outputPath: tempDir.path, config: config)
            .generate();

        final content = File(path.join(
                tempDir.path, 'lib', 'services', 'bootstrap', 'bootstrap.dart'))
            .readAsStringSync();

        // Bootstrap is project-level only: no reference to any specific
        // feature, page, or entity, regardless of what the project
        // actually has configured.
        expect(content, isNot(contains('Auth')));
        expect(content, isNot(contains('Page')));
        expect(content, isNot(contains('Repository')));
        // No plugin/registry framework was introduced.
        expect(content, isNot(contains('Registry')));
        expect(content, isNot(contains('Plugin')));
      });

      test('bootstrap.dart uses no package:<projectName>/ internal import',
          () async {
        final config = ProjectConfig(
          projectName: 'zephyr_quokka_ledger',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: [],
        );

        await ProjectGenerator(outputPath: tempDir.path, config: config)
            .generate();

        final content = File(path.join(
                tempDir.path, 'lib', 'services', 'bootstrap', 'bootstrap.dart'))
            .readAsStringSync();

        expect(content, isNot(contains('package:zephyr_quokka_ledger')));
        expect(content, isNot(contains('package:')));
      });
    });

    group('constants foundation completion', () {
      final expectedNamespaces = {
        'api_constants.dart': 'ApiConstants',
        'asset_constants.dart': 'AssetConstants',
        'storage_constants.dart': 'StorageConstants',
        'app_colors.dart': 'AppColors',
        'app_dimensions.dart': 'AppDimensions',
      };

      test(
          'each new namespace file declares its class with a private '
          'constructor, and only api_constants/app_colors/app_dimensions '
          'carry the real, concrete values this milestone requires', () async {
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

        for (final entry in expectedNamespaces.entries) {
          final file = File(
              path.join(tempDir.path, 'lib', 'core', 'constants', entry.key));
          expect(file.existsSync(), isTrue, reason: '${entry.key} missing');

          final content = file.readAsStringSync();
          expect(content, contains('class ${entry.value}'));
          expect(content, contains('const ${entry.value}._();'));
          expect(content, isNot(contains('{{')));

          switch (entry.key) {
            case 'api_constants.dart':
              // Real scaffold URLs are this milestone's whole point —
              // Network and EnvironmentUrls both resolve through these.
              expect(content, contains("static const String prodUrl ="));
              expect(content, contains("static const String stageUrl ="));
              expect(content, contains("static const String devUrl ="));
              expect(content, contains('https://'));
            case 'app_colors.dart':
              // Brand seed colors (unchanged since V1.1-1), semantic
              // status colors with no Material ColorScheme role, an
              // overlay scrim, and the two shadow colors AppTheme
              // consumes. Every value is declared via color_hex.dart's
              // HexColor.toColor() (static final, not static const —
              // an extension method can never be const-evaluated) per
              // the Constants & Utils gap analysis follow-up wiring
              // AppColors through the new shared hex-color utility.
              expect(
                  content, contains("import 'package:flutter/material.dart';"));
              expect(
                  content, contains("import '../utilities/color_hex.dart';"));
              expect(content, contains('static final Color lightSeedColor'));
              expect(content, contains('static final Color darkSeedColor'));
              expect(content, contains('static final Color success'));
              expect(content, contains('static final Color warning'));
              expect(content, contains('static final Color info'));
              expect(content, contains('static final Color overlay'));
              expect(content, contains('static final Color shadow'));
              expect(content, contains('static final Color shadowDark'));
            case 'app_dimensions.dart':
              // maxContentWidth (unchanged since V1.1-1) plus the new
              // screen padding, spacing scale, and border-radius scale.
              expect(content, contains('static const double maxContentWidth'));
              expect(content, contains('static const double screenPadding'));
              expect(content, contains('static const double spacingXs'));
              expect(content, contains('static const double spacingSm'));
              expect(content, contains('static const double spacingMd'));
              expect(content, contains('static const double spacingLg'));
              expect(content, contains('static const double spacingXl'));
              expect(content, contains('static const double radiusSmall'));
              expect(content, contains('static const double radiusMedium'));
              expect(content, contains('static const double radiusLarge'));
            default:
              // asset_constants.dart and storage_constants.dart carry no
              // invented application-specific values beyond their real,
              // required keys: no hex color, no fabricated numeric
              // dimension.
              expect(content, isNot(matches(RegExp(r'0x[0-9A-Fa-f]{6,8}'))),
                  reason: '${entry.key} must not invent a color constant');
              expect(content, isNot(matches(RegExp(r"static const \w+ = \d"))),
                  reason: '${entry.key} must not invent a numeric constant');
          }
        }
      });

      test(
          'route_constants.dart is never generated, anywhere — routing '
          'lives in services/routing/app_router.dart instead', () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await ProjectGenerator(outputPath: tempDir.path, config: config)
            .generate();

        final routeConstantFiles = Directory(tempDir.path)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => path.basename(f.path).contains('route_constants'));

        expect(routeConstantFiles, isEmpty,
            reason: 'routing is intentionally outside the constants '
                'foundation; no route_constants.dart or similar file '
                'should exist anywhere in the generated project');

        // The router itself is the one, real routing home — it must
        // exist, just never as a constants-style file.
        expect(
          File(path.join(tempDir.path, 'lib', 'services', 'routing',
                  'app_router.dart'))
              .existsSync(),
          isTrue,
        );
      });

      test(
          'the five new namespace files never depend on the generated '
          'package name', () async {
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

        for (final fileName in expectedNamespaces.keys) {
          final content = File(
                  path.join(tempDir.path, 'lib', 'core', 'constants', fileName))
              .readAsStringSync();
          expect(content, isNot(contains(oddProjectName)));
          // app_colors.dart legitimately depends on the third-party
          // package:flutter for Color/Colors — only a dependency on the
          // *generated project's own* package name is disallowed.
          if (fileName != 'app_colors.dart') {
            expect(content, isNot(contains('package:')));
          } else {
            expect(content, isNot(contains('package:$oddProjectName')));
          }
        }
      });
    });

    group('localization (V1.1-6)', () {
      ProjectConfig configWith(LocalizationConfig localization) {
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

      String mainDart() =>
          File(path.join(tempDir.path, 'lib', 'main.dart')).readAsStringSync();

      test(
          'disabled generates no l10n.yaml, no lib/l10n/, and main.dart '
          'unchanged', () async {
        await ProjectGenerator(
          outputPath: tempDir.path,
          config: configWith(LocalizationConfig.disabled()),
        ).generate();

        expect(
            File(path.join(tempDir.path, 'l10n.yaml')).existsSync(), isFalse);
        expect(Directory(path.join(tempDir.path, 'lib', 'l10n')).existsSync(),
            isFalse);
        expect(mainDart(), isNot(contains('AppLocalizations')));
        expect(mainDart(), isNot(contains('l10n/')));
      });

      test(
          'enabled generates l10n.yaml and one baseline ARB file per '
          'supported locale, and wires main.dart', () async {
        await ProjectGenerator(
          outputPath: tempDir.path,
          config: configWith(LocalizationConfig.enabled(
            supportedLocales: ['en', 'fr', 'de'],
            defaultLocale: 'en',
          )),
        ).generate();

        final l10nYaml =
            File(path.join(tempDir.path, 'l10n.yaml')).readAsStringSync();
        expect(l10nYaml, contains('arb-dir: lib/l10n'));
        expect(l10nYaml, contains('template-arb-file: app_en.arb'));
        expect(l10nYaml,
            contains('output-localization-file: app_localizations.dart'));

        for (final locale in ['en', 'fr', 'de']) {
          final arb =
              File(path.join(tempDir.path, 'lib', 'l10n', 'app_$locale.arb'))
                  .readAsStringSync();
          expect(arb, contains('"@@locale": "$locale"'));
          expect(arb, contains('"appTitle": "demo_app"'));
        }

        final content = mainDart();
        expect(content, contains("import 'l10n/app_localizations.dart';"));
        expect(
          content,
          contains(
              'onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,'),
        );
        expect(
          content,
          contains(
              'localizationsDelegates: AppLocalizations.localizationsDelegates,'),
        );
        expect(content, contains("Locale('en')"));
        expect(content, contains("Locale('fr')"));
        expect(content, contains("Locale('de')"));
        // defaultLocale ('en') must be first, per orderedLocales.
        expect(
          content.indexOf("Locale('en')"),
          lessThan(content.indexOf("Locale('fr')")),
        );
      });

      test(
          'a country-qualified locale renders as Locale(language, '
          'country) in main.dart', () async {
        await ProjectGenerator(
          outputPath: tempDir.path,
          config: configWith(LocalizationConfig.enabled(
            supportedLocales: ['en', 'pt', 'pt_BR'],
            defaultLocale: 'en',
          )),
        ).generate();

        expect(mainDart(), contains("Locale('pt', 'BR')"));
      });

      test(
          'supportedLocales wraps onto multiple lines, matching real '
          '`dart format` output, when the single-line form would '
          'exceed 80 columns', () async {
        await ProjectGenerator(
          outputPath: tempDir.path,
          config: configWith(LocalizationConfig.enabled(
            supportedLocales: ['en', 'pt', 'pt_BR'],
            defaultLocale: 'pt_BR',
          )),
        ).generate();

        final content = mainDart();
        expect(
          content,
          contains('supportedLocales: const [\n'
              "            Locale('pt', 'BR'),\n"
              "            Locale('en'),\n"
              "            Locale('pt'),\n"
              '          ],'),
        );
        for (final line in content.split('\n')) {
          expect(line.length, lessThanOrEqualTo(80));
        }
      });

      test(
          'an existing ARB file with real translations is never '
          'overwritten on regeneration', () async {
        final config = configWith(LocalizationConfig.enabled(
          supportedLocales: ['en', 'fr'],
          defaultLocale: 'en',
        ));
        await ProjectGenerator(outputPath: tempDir.path, config: config)
            .generate();

        final frArb =
            File(path.join(tempDir.path, 'lib', 'l10n', 'app_fr.arb'));
        frArb.writeAsStringSync('''{
  "@@locale": "fr",
  "appTitle": "Vraie Traduction"
}
''');

        final generator =
            ProjectGenerator(outputPath: tempDir.path, config: config);
        await generator.clearGeneratedContent();
        await generator.generate();

        expect(frArb.readAsStringSync(), contains('Vraie Traduction'));
      });

      test(
          'removing a locale from supportedLocales never deletes its '
          'existing ARB file — SmartWork cannot positively identify it '
          'as safe to delete', () async {
        await ProjectGenerator(
          outputPath: tempDir.path,
          config: configWith(LocalizationConfig.enabled(
            supportedLocales: ['en', 'fr', 'de'],
            defaultLocale: 'en',
          )),
        ).generate();

        final deFile =
            File(path.join(tempDir.path, 'lib', 'l10n', 'app_de.arb'));
        expect(deFile.existsSync(), isTrue);

        final regenerator = ProjectGenerator(
          outputPath: tempDir.path,
          config: configWith(LocalizationConfig.enabled(
            supportedLocales: ['en', 'es'],
            defaultLocale: 'en',
          )),
        );
        await regenerator.clearGeneratedContent();
        await regenerator.generate();

        expect(deFile.existsSync(), isTrue,
            reason: 'a locale dropped from config must not delete its ARB '
                'file');
        expect(
          File(path.join(tempDir.path, 'lib', 'l10n', 'app_es.arb'))
              .existsSync(),
          isTrue,
        );
      });

      test(
          'disabling localization after it was enabled deletes '
          'l10n.yaml but preserves lib/l10n/\'s ARB files', () async {
        await ProjectGenerator(
          outputPath: tempDir.path,
          config: configWith(LocalizationConfig.enabled(
            supportedLocales: ['en'],
            defaultLocale: 'en',
          )),
        ).generate();

        final disabler = ProjectGenerator(
          outputPath: tempDir.path,
          config: configWith(LocalizationConfig.disabled()),
        );
        await disabler.clearGeneratedContent();
        await disabler.generate();

        expect(
            File(path.join(tempDir.path, 'l10n.yaml')).existsSync(), isFalse);
        expect(
          File(path.join(tempDir.path, 'lib', 'l10n', 'app_en.arb'))
              .existsSync(),
          isTrue,
          reason: 'a developer\'s ARB file is never deleted, even when '
              'localization is disabled again',
        );
        expect(mainDart(), isNot(contains('AppLocalizations')));
      });

      test(
          'localization output is independent of architecture/state '
          'management', () async {
        final contents = <String>[];
        for (final combo in [
          (Architecture.cleanArchitecture, StateManagement.bloc),
          (Architecture.mvvm, StateManagement.riverpod),
          (Architecture.mvp, StateManagement.getx),
        ]) {
          final dir =
              Directory.systemTemp.createTempSync('smartwork_l10n_arch_');
          addTearDown(() => dir.deleteSync(recursive: true));

          await ProjectGenerator(
            outputPath: dir.path,
            config: ProjectConfig(
              projectName: 'demo_app',
              architecture: combo.$1,
              stateManagement: combo.$2,
              network: Network.http,
              storage: Storage.sharedPreferences,
              localization: LocalizationConfig.enabled(
                supportedLocales: ['en', 'fr'],
                defaultLocale: 'en',
              ),
              initialFeatures: ['home'],
            ),
          ).generate();

          contents.add(
            File(path.join(dir.path, 'lib', 'l10n', 'app_en.arb'))
                .readAsStringSync(),
          );
        }

        expect(contents.toSet(), hasLength(1),
            reason: 'the ARB baseline must not vary by architecture/state '
                'management');
      });
    });
  });
}
