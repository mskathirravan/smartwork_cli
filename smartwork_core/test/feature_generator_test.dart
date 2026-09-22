import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureGenerator', () {
    late Directory tempDir;
    late ProjectPaths paths;
    late FileWriter fileWriter;
    late FeatureGenerator generator;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_feature_test_');
      paths = ProjectPaths(projectRoot: tempDir.path);
      fileWriter = FileWriter();
      generator = FeatureGenerator();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    group('Clean Architecture + BLoC (reference combination)', () {
      late ProjectConfig config;

      setUp(() {
        config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );
      });

      test(
          'generates the expected Clean Architecture directories for the '
          'requested components', () async {
        await generator.generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        final featurePath = paths.featurePath('auth');
        // The default component set (entity/repository/useCase/
        // dataSource/page) never requests `widgets`, so
        // `presentation/widgets/` must not exist — see the
        // Empty-Folder Audit (a directory is only created when a
        // requested component's file actually needs it).
        for (final dir in [
          path.join(featurePath, 'domain', 'entities'),
          path.join(featurePath, 'domain', 'repositories'),
          path.join(featurePath, 'domain', 'usecases'),
          path.join(featurePath, 'data', 'datasources'),
          path.join(featurePath, 'data', 'models'),
          path.join(featurePath, 'data', 'repositories'),
          path.join(featurePath, 'presentation', 'pages'),
        ]) {
          expect(Directory(dir).existsSync(), isTrue,
              reason: '$dir should exist');
        }
        expect(
          Directory(path.join(featurePath, 'presentation', 'widgets'))
              .existsSync(),
          isFalse,
          reason: 'widgets was not requested, so this directory must not '
              'exist',
        );
      });

      test('generates the expected BLoC state files', () async {
        await generator.generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        final statePath = path.join(paths.featurePath('auth'), 'state');
        expect(
            File(path.join(statePath, 'auth_bloc.dart')).existsSync(), isTrue);
        expect(
            File(path.join(statePath, 'auth_event.dart')).existsSync(), isTrue);
        expect(
            File(path.join(statePath, 'auth_state.dart')).existsSync(), isTrue);
      });

      test('generated Dart identifiers use PascalCase feature name', () async {
        await generator.generate(
          FeatureConfig(name: 'user_profile'),
          config,
          paths,
          fileWriter,
        );

        final statePath = path.join(paths.featurePath('user_profile'), 'state');
        final blocContent = File(path.join(statePath, 'user_profile_bloc.dart'))
            .readAsStringSync();

        expect(blocContent, contains('user_profile'));
        expect(blocContent, isNot(contains('{{')));
      });

      test('uses the existing template system (no unresolved placeholders)',
          () async {
        await generator.generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        final statePath = path.join(paths.featurePath('auth'), 'state');
        for (final file in Directory(statePath).listSync().whereType<File>()) {
          expect(file.readAsStringSync(), isNot(contains('{{')));
        }
      });

      test('does not generate unexpected top-level files or directories',
          () async {
        await generator.generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        final featurePath = paths.featurePath('auth');
        final topLevel = Directory(featurePath)
            .listSync()
            .map((e) => path.basename(e.path))
            .toSet();

        expect(
            topLevel, {'domain', 'data', 'presentation', 'state', 'auth.dart'});
      });

      test('reports accurate file and directory counts', () async {
        final result = await generator.generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        final featurePath = paths.featurePath('auth');
        final entries = Directory(featurePath).listSync(recursive: true);
        final actualFiles = entries.whereType<File>().length;
        final actualDirs = entries.whereType<Directory>().length;

        expect(result.fileCount, actualFiles);
        expect(result.directoryCount, actualDirs);
        expect(result.featureName, 'auth');
      });

      test('does not affect features already listed in initialFeatures',
          () async {
        await generator.generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        // Only 'auth' should exist; 'home' (from initialFeatures) must not
        // be generated as a side effect of feature generation.
        expect(Directory(paths.featurePath('home')).existsSync(), isFalse);
      });
    });

    group(
        'Architecture composition (FeatureGenerator works with all architectures)',
        () {
      test('MVVM + BLoC generates MVVM structure, not Clean layers', () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.mvvm,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await generator.generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        final featurePath = paths.featurePath('auth');
        expect(Directory(path.join(featurePath, 'viewmodels')).existsSync(),
            isTrue);
        expect(
            Directory(path.join(featurePath, 'models')).existsSync(), isTrue);
        expect(Directory(path.join(featurePath, 'views')).existsSync(), isTrue);
        expect(
            Directory(path.join(featurePath, 'domain')).existsSync(), isFalse);

        final statePath = path.join(featurePath, 'state');
        expect(
            File(path.join(statePath, 'auth_bloc.dart')).existsSync(), isTrue);
      });

      test('MVP + BLoC generates MVP structure, not Clean layers', () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.mvp,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await generator.generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        final featurePath = paths.featurePath('auth');
        expect(Directory(path.join(featurePath, 'presenters')).existsSync(),
            isTrue);
        // contracts/ is never created — no template writes a Contract
        // file (see the Empty-Folder Audit: MvpGenerator no longer
        // pre-creates it, since it would otherwise be permanently
        // empty).
        expect(Directory(path.join(featurePath, 'contracts')).existsSync(),
            isFalse);
        expect(
            Directory(path.join(featurePath, 'models')).existsSync(), isTrue);
        expect(
            Directory(path.join(featurePath, 'domain')).existsSync(), isFalse);

        final statePath = path.join(featurePath, 'state');
        expect(
            File(path.join(statePath, 'auth_bloc.dart')).existsSync(), isTrue);
      });
    });
  });
}
