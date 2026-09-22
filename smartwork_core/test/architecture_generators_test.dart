import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Tests for the architecture generators' corrected contract: they no
/// longer pre-create every layer directory unconditionally (an earlier
/// design that left permanently empty directories on disk regardless of
/// which components a feature actually requested — see the
/// Empty-Folder Audit in the Flutter Project Foundation / SmartWork
/// Architecture Cleanup milestone). Directory creation is now entirely
/// [FeatureContentGenerator]'s responsibility, via `FileWriter`'s
/// automatic parent-directory creation when it actually writes a file.
///
/// See `empty_folder_audit_test.dart` for the meaningful, pipeline-level
/// proof that no empty directory is ever generated in practice.
void main() {
  group('Architecture generators are directory-creation no-ops', () {
    late Directory tempDir;
    late ProjectPaths paths;
    late FileWriter fileWriter;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_arch_test_');
      paths = ProjectPaths(projectRoot: tempDir.path);
      fileWriter = FileWriter();
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('CleanArchitectureGenerator creates no directories on its own',
        () async {
      final config = ProjectConfig(
        projectName: 'test_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      );

      await CleanArchitectureGenerator().generate(config, paths, fileWriter);

      expect(Directory(paths.features).existsSync(), isFalse,
          reason: 'directory creation belongs to FeatureContentGenerator, '
              'triggered only by an actual file being written');
    });

    test('MvvmGenerator creates no directories on its own', () async {
      final config = ProjectConfig(
        projectName: 'test_app',
        architecture: Architecture.mvvm,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      );

      await MvvmGenerator().generate(config, paths, fileWriter);

      expect(Directory(paths.features).existsSync(), isFalse);
    });

    test('MvpGenerator creates no directories on its own', () async {
      final config = ProjectConfig(
        projectName: 'test_app',
        architecture: Architecture.mvp,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      );

      await MvpGenerator().generate(config, paths, fileWriter);

      expect(Directory(paths.features).existsSync(), isFalse);
    });
  });
}
