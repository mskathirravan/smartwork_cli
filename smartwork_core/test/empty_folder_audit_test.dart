import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// The Empty-Folder Audit (Flutter Project Foundation / SmartWork
/// Architecture Cleanup milestone): the generator must never create a
/// meaningless empty directory. This exercises the real,
/// pipeline-level behavior — `ProjectGenerator`/`FeatureGenerator`,
/// not an architecture generator in isolation (see
/// `architecture_generators_test.dart` for that no-op contract) —
/// across every supported architecture and a range of component
/// selections, since an empty directory could only ever appear as a
/// side effect of the full generation pipeline.
void main() {
  group('Empty-Folder Audit', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_empty_dir_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    /// Every directory under [root] must contain at least one file
    /// somewhere within it (checked recursively) — a directory with
    /// only empty subdirectories is just as meaningless as one with
    /// nothing at all.
    void expectNoEmptyDirectories(String root) {
      final dir = Directory(root);
      if (!dir.existsSync()) return;

      for (final entry in dir.listSync(recursive: true)) {
        if (entry is! Directory) continue;
        final hasAnyFile =
            entry.listSync(recursive: true).whereType<File>().isNotEmpty;
        expect(hasAnyFile, isTrue,
            reason: '${entry.path} is an empty directory (or contains '
                'only empty subdirectories) — the generator must not '
                'create meaningless empty directories');
      }
    }

    test(
        'a full project (Home + a fully-blueprinted feature) has no '
        'empty lib/ directory, for every architecture', () async {
      for (final architecture in Architecture.values) {
        final dir =
            Directory.systemTemp.createTempSync('smartwork_empty_dir_arch_');
        addTearDown(() => dir.deleteSync(recursive: true));

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: architecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['auth'],
        );

        await ProjectGenerator(outputPath: dir.path, config: config).generate();

        final paths = ProjectPaths(projectRoot: dir.path);
        expectNoEmptyDirectories(paths.lib);
      }
    });

    test(
        'MVP never generates an empty contracts/ directory — no '
        'template writes a Contract file', () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.mvp,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );

      await ProjectGenerator(outputPath: tempDir.path, config: config)
          .generate();

      final paths = ProjectPaths(projectRoot: tempDir.path);
      expect(
        Directory('${paths.featurePath('auth')}/contracts').existsSync(),
        isFalse,
      );
    });

    test(
        'a minimal blueprint (page only, like Home) never leaves empty '
        'sibling layer directories behind, for every architecture', () async {
      for (final architecture in Architecture.values) {
        final dir =
            Directory.systemTemp.createTempSync('smartwork_empty_dir_minimal_');
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
        expectNoEmptyDirectories(paths.lib);
      }
    });

    test(
        'every state-management choice produces no empty directory, '
        'for every architecture', () async {
      for (final architecture in Architecture.values) {
        for (final stateManagement in StateManagement.values) {
          final dir =
              Directory.systemTemp.createTempSync('smartwork_empty_dir_sm_');
          addTearDown(() => dir.deleteSync(recursive: true));

          final config = ProjectConfig(
            projectName: 'demo_app',
            architecture: architecture,
            stateManagement: stateManagement,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: ['auth'],
          );

          await ProjectGenerator(outputPath: dir.path, config: config)
              .generate();

          final paths = ProjectPaths(projectRoot: dir.path);
          expectNoEmptyDirectories(paths.lib);
        }
      }
    });

    test(
        'every network/storage combination produces no empty '
        'directory', () async {
      for (final network in Network.values) {
        for (final storage in Storage.values) {
          final dir =
              Directory.systemTemp.createTempSync('smartwork_empty_dir_ns_');
          addTearDown(() => dir.deleteSync(recursive: true));

          final config = ProjectConfig(
            projectName: 'demo_app',
            architecture: Architecture.cleanArchitecture,
            stateManagement: StateManagement.bloc,
            network: network,
            storage: storage,
            initialFeatures: ['auth'],
          );

          await ProjectGenerator(outputPath: dir.path, config: config)
              .generate();

          final paths = ProjectPaths(projectRoot: dir.path);
          expectNoEmptyDirectories(paths.lib);
        }
      }
    });

    test(
        'the standard assets/ folders are the one deliberate exception '
        '— they may be empty, since they are a real project convention, '
        'not future-only architecture', () async {
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
      for (final dir in [
        paths.assetsImages,
        paths.assetsFonts,
        paths.assetsIcons,
        paths.assetsAnimations,
      ]) {
        expect(Directory(dir).existsSync(), isTrue);
        expect(Directory(dir).listSync(), isEmpty);
      }
    });
  });
}
