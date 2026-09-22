import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('StateManagementGenerators', () {
    late Directory tempDir;
    late ProjectPaths paths;
    late FileWriter fileWriter;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_sm_test_');
      paths = ProjectPaths(projectRoot: tempDir.path);
      fileWriter = FileWriter();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    group('BlocGenerator', () {
      late BlocGenerator generator;

      setUp(() {
        generator = BlocGenerator();
      });

      test('generates BLoC files for single feature', () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await generator.generate(config, paths, fileWriter);

        final statePath =
            path.join(tempDir.path, 'lib', 'features', 'home', 'state');
        expect(
          await File(path.join(statePath, 'home_bloc.dart')).exists(),
          isTrue,
        );
        expect(
          await File(path.join(statePath, 'home_event.dart')).exists(),
          isTrue,
        );
        expect(
          await File(path.join(statePath, 'home_state.dart')).exists(),
          isTrue,
        );
      });

      test('generates BLoC files for multiple features', () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth', 'home', 'profile'],
        );

        await generator.generate(config, paths, fileWriter);

        for (final feature in ['auth', 'home', 'profile']) {
          final statePath =
              path.join(tempDir.path, 'lib', 'features', feature, 'state');
          expect(
            await File(path.join(statePath, '${feature}_bloc.dart')).exists(),
            isTrue,
          );
          expect(
            await File(path.join(statePath, '${feature}_event.dart')).exists(),
            isTrue,
          );
          expect(
            await File(path.join(statePath, '${feature}_state.dart')).exists(),
            isTrue,
          );
        }
      });

      test('does not generate Cubit files', () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await generator.generate(config, paths, fileWriter);

        final statePath =
            path.join(tempDir.path, 'lib', 'features', 'home', 'state');
        expect(
          await File(path.join(statePath, 'home_cubit.dart')).exists(),
          isFalse,
        );
      });

      test('works with all architectures', () async {
        for (final arch in [
          Architecture.cleanArchitecture,
          Architecture.mvvm,
          Architecture.mvp,
        ]) {
          final tempDir2 =
              Directory.systemTemp.createTempSync('smartwork_bloc_arch_');
          try {
            final config = ProjectConfig(
              projectName: 'test_app',
              architecture: arch,
              stateManagement: StateManagement.bloc,
              network: Network.http,
              storage: Storage.sharedPreferences,
              initialFeatures: ['home'],
            );

            final paths2 = ProjectPaths(projectRoot: tempDir2.path);
            await generator.generate(config, paths2, fileWriter);

            final statePath =
                path.join(tempDir2.path, 'lib', 'features', 'home', 'state');
            expect(
              await File(path.join(statePath, 'home_bloc.dart')).exists(),
              isTrue,
              reason: 'BLoC files should exist for $arch',
            );
          } finally {
            tempDir2.deleteSync(recursive: true);
          }
        }
      });
    });

    group('CubitGenerator', () {
      late CubitGenerator generator;

      setUp(() {
        generator = CubitGenerator();
      });

      test('generates Cubit files for single feature', () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.cubit,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await generator.generate(config, paths, fileWriter);

        final statePath =
            path.join(tempDir.path, 'lib', 'features', 'home', 'state');
        expect(
          await File(path.join(statePath, 'home_cubit.dart')).exists(),
          isTrue,
        );
        expect(
          await File(path.join(statePath, 'home_state.dart')).exists(),
          isTrue,
        );
      });

      test('does not generate Event files (unlike BLoC)', () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.cubit,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await generator.generate(config, paths, fileWriter);

        final statePath =
            path.join(tempDir.path, 'lib', 'features', 'home', 'state');
        expect(
          await File(path.join(statePath, 'home_event.dart')).exists(),
          isFalse,
        );
      });

      test('generates Cubit files for multiple features', () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.cubit,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth', 'home'],
        );

        await generator.generate(config, paths, fileWriter);

        for (final feature in ['auth', 'home']) {
          final statePath =
              path.join(tempDir.path, 'lib', 'features', feature, 'state');
          expect(
            await File(path.join(statePath, '${feature}_cubit.dart')).exists(),
            isTrue,
          );
        }
      });

      test('does not generate BLoC files', () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.cubit,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await generator.generate(config, paths, fileWriter);

        final statePath =
            path.join(tempDir.path, 'lib', 'features', 'home', 'state');
        expect(
          await File(path.join(statePath, 'home_bloc.dart')).exists(),
          isFalse,
        );
      });
    });

    group('GetxGenerator', () {
      late GetxGenerator generator;

      setUp(() {
        generator = GetxGenerator();
      });

      test('generates controller for Clean Architecture', () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.getx,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await generator.generate(config, paths, fileWriter);

        final getxPath = path.join(
          tempDir.path,
          'lib',
          'features',
          'home',
          'presentation',
          'getx',
        );
        expect(
          await File(path.join(getxPath, 'home_controller.dart')).exists(),
          isTrue,
        );
      });

      test('does not generate files for MVVM (ViewModel already exists)',
          () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.mvvm,
          stateManagement: StateManagement.getx,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await generator.generate(config, paths, fileWriter);

        // GetX for MVVM doesn't create additional files
        // ViewModel is created by architecture generator
        final getxPath = path.join(
          tempDir.path,
          'lib',
          'features',
          'home',
          'presentation',
          'getx',
        );
        expect(
          await Directory(getxPath).exists(),
          isFalse,
        );
      });

      test('does not generate files for MVP (Presenter already exists)',
          () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.mvp,
          stateManagement: StateManagement.getx,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await generator.generate(config, paths, fileWriter);

        // GetX for MVP doesn't create additional files
        // Presenter is created by architecture generator
        final getxPath = path.join(
          tempDir.path,
          'lib',
          'features',
          'home',
          'presentation',
          'getx',
        );
        expect(
          await Directory(getxPath).exists(),
          isFalse,
        );
      });

      test('generates controller for multiple features in Clean Architecture',
          () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.getx,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth', 'home', 'profile'],
        );

        await generator.generate(config, paths, fileWriter);

        for (final feature in ['auth', 'home', 'profile']) {
          final getxPath = path.join(
            tempDir.path,
            'lib',
            'features',
            feature,
            'presentation',
            'getx',
          );
          expect(
            await File(path.join(getxPath, '${feature}_controller.dart'))
                .exists(),
            isTrue,
          );
        }
      });
    });

    group('RiverpodGenerator', () {
      late RiverpodGenerator generator;

      setUp(() {
        generator = RiverpodGenerator();
      });

      test(
          'generates provider files inside presentation for Clean Architecture',
          () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.riverpod,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await generator.generate(config, paths, fileWriter);

        // Clean Architecture: providers should be under presentation/
        final providersPath = path.join(
          tempDir.path,
          'lib',
          'features',
          'home',
          'presentation',
          'providers',
        );
        expect(
          await File(path.join(providersPath, 'home_state.dart')).exists(),
          isTrue,
        );
        expect(
          await File(path.join(providersPath, 'home_provider.dart')).exists(),
          isTrue,
        );
      });

      test('does not generate providers at feature root for Clean Architecture',
          () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.riverpod,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await generator.generate(config, paths, fileWriter);

        // Should NOT create at feature root level
        final featureProvidersPath = path.join(
          tempDir.path,
          'lib',
          'features',
          'home',
          'providers',
        );
        expect(
          await Directory(featureProvidersPath).exists(),
          isFalse,
        );
      });

      test('generates provider files for MVVM', () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.mvvm,
          stateManagement: StateManagement.riverpod,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await generator.generate(config, paths, fileWriter);

        final providersPath = path.join(
          tempDir.path,
          'lib',
          'features',
          'home',
          'providers',
        );
        expect(
          await File(path.join(providersPath, 'home_state.dart')).exists(),
          isTrue,
        );
        expect(
          await File(path.join(providersPath, 'home_provider.dart')).exists(),
          isTrue,
        );
      });

      test('generates provider files for MVP', () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.mvp,
          stateManagement: StateManagement.riverpod,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await generator.generate(config, paths, fileWriter);

        final providersPath = path.join(
          tempDir.path,
          'lib',
          'features',
          'home',
          'providers',
        );
        expect(
          await File(path.join(providersPath, 'home_state.dart')).exists(),
          isTrue,
        );
        expect(
          await File(path.join(providersPath, 'home_provider.dart')).exists(),
          isTrue,
        );
      });

      test(
          'generates provider files for multiple features in Clean Architecture',
          () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.riverpod,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth', 'home', 'details'],
        );

        await generator.generate(config, paths, fileWriter);

        for (final feature in ['auth', 'home', 'details']) {
          final providersPath = path.join(
            tempDir.path,
            'lib',
            'features',
            feature,
            'presentation',
            'providers',
          );
          expect(
            await File(path.join(providersPath, '${feature}_state.dart'))
                .exists(),
            isTrue,
          );
          expect(
            await File(path.join(providersPath, '${feature}_provider.dart'))
                .exists(),
            isTrue,
          );
        }
      });
    });

    group('State management separation', () {
      test('BLoC generator does not create Cubit/GetX/Riverpod files',
          () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        final blocGenerator = BlocGenerator();
        await blocGenerator.generate(config, paths, fileWriter);

        final featurePath = path.join(tempDir.path, 'lib', 'features', 'home');
        expect(
          await File(path.join(featurePath, 'state', 'home_cubit.dart'))
              .exists(),
          isFalse,
        );
        expect(
          await Directory(path.join(featurePath, 'presentation', 'getx'))
              .exists(),
          isFalse,
        );
        expect(
          await Directory(path.join(featurePath, 'providers')).exists(),
          isFalse,
        );
      });

      test('Cubit generator does not create BLoC/GetX/Riverpod files',
          () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.cubit,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        final cubitGenerator = CubitGenerator();
        await cubitGenerator.generate(config, paths, fileWriter);

        final featurePath = path.join(tempDir.path, 'lib', 'features', 'home');
        expect(
          await File(path.join(featurePath, 'state', 'home_event.dart'))
              .exists(),
          isFalse,
        );
        expect(
          await Directory(path.join(featurePath, 'presentation', 'getx'))
              .exists(),
          isFalse,
        );
        expect(
          await Directory(path.join(featurePath, 'providers')).exists(),
          isFalse,
        );
      });

      test('all generators handle empty feature list', () async {
        final config = ProjectConfig(
          projectName: 'test_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: [],
        );

        final blocGenerator = BlocGenerator();
        final cubitGenerator = CubitGenerator();
        final getxGenerator = GetxGenerator();
        final riverpodGenerator = RiverpodGenerator();

        await blocGenerator.generate(config, paths, fileWriter);
        await cubitGenerator.generate(config, paths, fileWriter);
        await getxGenerator.generate(config, paths, fileWriter);
        await riverpodGenerator.generate(config, paths, fileWriter);

        final featuresDir =
            Directory(path.join(tempDir.path, 'lib', 'features'));
        expect(await featuresDir.exists(), isFalse);
      });
    });
  });
}
