import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Project Safety & Regeneration V1: [TargetStateDetector] classifies a
/// `smartwork init` target directory before any destructive operation
/// runs. These tests exercise detection alone — no confirmation, no
/// generation — proving the classification is correct for every state
/// `InitCommand` needs to distinguish.
void main() {
  group('TargetStateDetector', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_target_state_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('a directory that does not exist on disk at all is empty', () async {
      final missingPath = '${tempDir.path}/does_not_exist';
      final result = await TargetStateDetector().detect(missingPath);

      expect(result.state, TargetProjectState.empty);
    });

    test('an existing but empty directory is empty', () async {
      final result = await TargetStateDetector().detect(tempDir.path);

      expect(result.state, TargetProjectState.empty);
    });

    test(
        'a directory with unrelated files but no Flutter indicators is '
        'a non-Flutter project', () async {
      File('${tempDir.path}/README.md').writeAsStringSync('hello');
      File('${tempDir.path}/notes.txt').writeAsStringSync('notes');

      final result = await TargetStateDetector().detect(tempDir.path);

      expect(result.state, TargetProjectState.nonFlutterProject);
    });

    test(
        'a bare Dart package (pubspec.yaml + lib/, no platform folder) '
        'is a non-Flutter project, never misclassified as Flutter', () async {
      File('${tempDir.path}/pubspec.yaml')
          .writeAsStringSync('name: some_dart_pkg\n');
      Directory('${tempDir.path}/lib').createSync();
      File('${tempDir.path}/lib/some_dart_pkg.dart')
          .writeAsStringSync('int x = 1;\n');

      final result = await TargetStateDetector().detect(tempDir.path);

      expect(result.state, TargetProjectState.nonFlutterProject);
    });

    test(
        'pubspec.yaml and lib/ together with at least one platform '
        'folder is a Flutter project', () async {
      File('${tempDir.path}/pubspec.yaml')
          .writeAsStringSync('name: some_app\n');
      Directory('${tempDir.path}/lib').createSync();
      Directory('${tempDir.path}/android').createSync();

      final result = await TargetStateDetector().detect(tempDir.path);

      expect(result.state, TargetProjectState.flutterProject);
    });

    test(
        'any single platform folder is sufficient (ios/web/linux/macos/'
        'windows, not only android)', () async {
      for (final platform in [
        'ios',
        'web',
        'linux',
        'macos',
        'windows',
      ]) {
        final dir =
            Directory.systemTemp.createTempSync('smartwork_platform_check_');
        addTearDown(() => dir.deleteSync(recursive: true));

        File('${dir.path}/pubspec.yaml').writeAsStringSync('name: app\n');
        Directory('${dir.path}/lib').createSync();
        Directory('${dir.path}/$platform').createSync();

        final result = await TargetStateDetector().detect(dir.path);
        expect(result.state, TargetProjectState.flutterProject,
            reason: 'platform folder "$platform" should be recognized');
      }
    });

    test(
        'a real Flutter project structure with .smartwork/project.yaml '
        'is a SmartWork project, not merely a Flutter project — '
        'SmartWork detection takes precedence', () async {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('name: my_app\n');
      Directory('${tempDir.path}/lib').createSync();
      Directory('${tempDir.path}/android').createSync();

      await ProjectConfigFile(projectPath: tempDir.path).write(
        ProjectConfig(
          projectName: 'my_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth'],
        ),
      );

      final result = await TargetStateDetector().detect(tempDir.path);

      expect(result.state, TargetProjectState.smartworkProject);
      expect(result.existingConfig, isNotNull);
      expect(result.existingConfig!.projectName, 'my_app');
      expect(
          result.existingConfig!.architecture, Architecture.cleanArchitecture);
    });

    test(
        'a directory with .smartwork/project.yaml but none of the '
        'Flutter platform folders is still a SmartWork project', () async {
      await ProjectConfigFile(projectPath: tempDir.path).write(
        ProjectConfig(
          projectName: 'my_app',
          architecture: Architecture.mvvm,
          stateManagement: StateManagement.riverpod,
          network: Network.dio,
          storage: Storage.hive,
          initialFeatures: [],
        ),
      );

      final result = await TargetStateDetector().detect(tempDir.path);

      expect(result.state, TargetProjectState.smartworkProject);
      expect(result.existingConfig!.architecture, Architecture.mvvm);
    });

    test(
        'invalid YAML syntax in .smartwork/project.yaml is reported as '
        'malformed, never crashes detection', () async {
      Directory('${tempDir.path}/.smartwork').createSync();
      File('${tempDir.path}/.smartwork/project.yaml').writeAsStringSync(
        'projectName: [unterminated\n  - broken',
      );

      final result = await TargetStateDetector().detect(tempDir.path);

      expect(result.state, TargetProjectState.malformedSmartworkProject);
      expect(result.detectionError, isNotNull);
      expect(result.detectionError, isNotEmpty);
    });

    test(
        'well-formed YAML missing a required field (e.g. architecture) '
        'is reported as malformed, never crashes detection — '
        'ProjectConfig.fromYaml throws a raw TypeError here, not just '
        'FileSystemException', () async {
      Directory('${tempDir.path}/.smartwork').createSync();
      File('${tempDir.path}/.smartwork/project.yaml').writeAsStringSync(
        "projectName: 'my_app'\n",
      );

      final result = await TargetStateDetector().detect(tempDir.path);

      expect(result.state, TargetProjectState.malformedSmartworkProject);
      expect(result.detectionError, isNotNull);
    });

    test(
        'an empty .smartwork/project.yaml file is reported as '
        'malformed', () async {
      Directory('${tempDir.path}/.smartwork').createSync();
      File('${tempDir.path}/.smartwork/project.yaml').writeAsStringSync('');

      final result = await TargetStateDetector().detect(tempDir.path);

      expect(result.state, TargetProjectState.malformedSmartworkProject);
    });
  });

  group('TargetStateDetector.existingPlatforms', () {
    late Directory tempDir;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_existing_platforms_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('reports no platforms for an empty directory', () {
      expect(TargetStateDetector().existingPlatforms(tempDir.path), isEmpty);
    });

    test('reports exactly the platform folders that exist, nothing more', () {
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();
      // A folder that happens to share a name unrelated to any target
      // must never be misread as a platform.
      Directory('${tempDir.path}/scripts').createSync();

      expect(
        TargetStateDetector().existingPlatforms(tempDir.path),
        {AppTarget.android, AppTarget.ios},
      );
    });

    test('reports all six when every platform folder exists', () {
      for (final target in AppTarget.values) {
        Directory('${tempDir.path}/${target.platformFolder}').createSync();
      }

      expect(
        TargetStateDetector().existingPlatforms(tempDir.path),
        unorderedEquals(AppTarget.values),
      );
    });

    test('detect() populates existingPlatforms for a flutterProject state',
        () async {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('name: app\n');
      Directory('${tempDir.path}/lib').createSync();
      Directory('${tempDir.path}/android').createSync();
      Directory('${tempDir.path}/ios').createSync();

      final result = await TargetStateDetector().detect(tempDir.path);

      expect(result.state, TargetProjectState.flutterProject);
      expect(result.existingPlatforms, {AppTarget.android, AppTarget.ios});
    });

    test(
        'detect() populates existingPlatforms for a smartworkProject '
        'state too', () async {
      Directory('${tempDir.path}/web').createSync();
      await ProjectConfigFile(projectPath: tempDir.path).write(
        ProjectConfig(
          projectName: 'my_app',
          appTargets: {AppTarget.web},
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth'],
        ),
      );

      final result = await TargetStateDetector().detect(tempDir.path);

      expect(result.state, TargetProjectState.smartworkProject);
      expect(result.existingPlatforms, {AppTarget.web});
    });

    test(
        'detect() reports an empty existingPlatforms for an empty '
        'directory', () async {
      final result = await TargetStateDetector().detect(tempDir.path);

      expect(result.state, TargetProjectState.empty);
      expect(result.existingPlatforms, isEmpty);
    });
  });
}
