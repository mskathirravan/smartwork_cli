import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('Feature lifecycle', () {
    late Directory tempDir;
    late ProjectPaths paths;
    late FileWriter fileWriter;
    late FeatureGenerator generator;
    late ProjectConfig config;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_lifecycle_test_');
      paths = ProjectPaths(projectRoot: tempDir.path);
      fileWriter = FileWriter();
      generator = FeatureGenerator();
      config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      );
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    group('featureExists', () {
      test('is false for a feature that was never generated', () {
        expect(generator.featureExists(paths, 'auth'), isFalse);
      });

      test('is true after a feature has been generated', () async {
        await generator.generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        expect(generator.featureExists(paths, 'auth'), isTrue);
      });

      test('is false for a bare empty directory (not treated as existing)', () {
        Directory(paths.featurePath('auth')).createSync(recursive: true);

        expect(generator.featureExists(paths, 'auth'), isFalse);
      });

      test(
          'is reliable across all 12 architecture x state-management '
          'combinations', () async {
        for (final architecture in Architecture.values) {
          for (final stateManagement in StateManagement.values) {
            final combinationDir = Directory.systemTemp
                .createTempSync('smartwork_lifecycle_matrix_');
            addTearDown(() => combinationDir.deleteSync(recursive: true));

            final combinationPaths =
                ProjectPaths(projectRoot: combinationDir.path);
            final combinationConfig = ProjectConfig(
              projectName: 'demo_app',
              architecture: architecture,
              stateManagement: stateManagement,
              network: Network.http,
              storage: Storage.sharedPreferences,
              initialFeatures: ['home'],
            );

            expect(
              generator.featureExists(combinationPaths, 'auth'),
              isFalse,
              reason: '$architecture + $stateManagement: should not exist '
                  'before generation',
            );

            await generator.generate(
              FeatureConfig(name: 'auth'),
              combinationConfig,
              combinationPaths,
              fileWriter,
            );

            expect(
              generator.featureExists(combinationPaths, 'auth'),
              isTrue,
              reason: '$architecture + $stateManagement: should exist '
                  'after generation',
            );
          }
        }
      });
    });

    group('generate() default safety', () {
      test('generates successfully when the feature is new', () async {
        final result = await generator.generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        expect(result.featureName, 'auth');
        expect(result.fileCount, greaterThan(0));
      });

      test('refuses to regenerate an existing feature by default', () async {
        await generator.generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        expect(
          () => generator.generate(
            FeatureConfig(name: 'auth'),
            config,
            paths,
            fileWriter,
          ),
          throwsA(isA<FeatureAlreadyExistsException>()),
        );
      });

      test('does not modify any files when refusing to regenerate', () async {
        await generator.generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        final blocFile =
            File('${paths.featurePath('auth')}/state/auth_bloc.dart');
        final contentBefore = blocFile.readAsStringSync();
        final modifiedTimeBefore = blocFile.lastModifiedSync();

        try {
          await generator.generate(
            FeatureConfig(name: 'auth'),
            config,
            paths,
            fileWriter,
          );
        } on FeatureAlreadyExistsException {
          // expected
        }

        expect(blocFile.readAsStringSync(), contentBefore);
        expect(blocFile.lastModifiedSync(), modifiedTimeBefore);
      });

      test('force: true bypasses the safety check and regenerates', () async {
        await generator.generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        final result = await generator.generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
          force: true,
        );

        expect(result.featureName, 'auth');
        expect(result.fileCount, greaterThan(0));
      });

      test('multiple features remain independent under the safety check',
          () async {
        await generator.generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        // A different feature name must generate successfully even though
        // 'auth' already exists — the check is scoped per-feature.
        final result = await generator.generate(
          FeatureConfig(name: 'profile'),
          config,
          paths,
          fileWriter,
        );

        expect(result.featureName, 'profile');
        expect(generator.featureExists(paths, 'auth'), isTrue);
        expect(generator.featureExists(paths, 'profile'), isTrue);
      });
    });
  });
}
