import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Project Safety & Regeneration V1: [ProjectGenerator.
/// clearGeneratedContent] is what makes it possible to call [Project
/// Generator.generate] a second time against a directory that already
/// holds a previous SmartWork generation — without it, `generate()`
/// throws `FeatureAlreadyExistsException` on Home every time (a real
/// bug this milestone found and fixes, confirmed by the first test
/// below reproducing it directly).
void main() {
  group('ProjectGenerator regeneration', () {
    late Directory tempDir;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_regeneration_test_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    ProjectConfig configFor(
      Architecture architecture, {
      StateManagement stateManagement = StateManagement.bloc,
    }) {
      return ProjectConfig(
        projectName: 'my_app',
        architecture: architecture,
        stateManagement: stateManagement,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );
    }

    test(
        'calling generate() a second time without clearing first throws '
        'FeatureAlreadyExistsException on Home — reproduces the bug '
        'clearGeneratedContent() exists to fix', () async {
      await ProjectGenerator(
        outputPath: tempDir.path,
        config: configFor(Architecture.mvp),
      ).generate();

      await expectLater(
        ProjectGenerator(
          outputPath: tempDir.path,
          config: configFor(Architecture.cleanArchitecture),
        ).generate(),
        throwsA(isA<FeatureAlreadyExistsException>()),
      );
    });

    test(
        'clearGeneratedContent() then generate() lets a project be '
        'regenerated under a completely different architecture with no '
        'exception', () async {
      await ProjectGenerator(
        outputPath: tempDir.path,
        config: configFor(Architecture.mvp),
      ).generate();

      final regenerated = ProjectGenerator(
        outputPath: tempDir.path,
        config: configFor(Architecture.cleanArchitecture),
      );
      await regenerated.clearGeneratedContent();
      await regenerated.generate();

      final paths = ProjectPaths(projectRoot: tempDir.path);
      expect(Directory('${paths.featurePath('auth')}/domain').existsSync(),
          isTrue);
    });

    test(
        'regenerating MVP -> Clean leaves no stale MVP-only files '
        'behind (presenters/) alongside the new Clean structure — this '
        'is a regeneration, never an attempted migration', () async {
      final paths = ProjectPaths(projectRoot: tempDir.path);

      await ProjectGenerator(
        outputPath: tempDir.path,
        config:
            configFor(Architecture.mvp, stateManagement: StateManagement.getx),
      ).generate();
      expect(
        Directory('${paths.featurePath('auth')}/presenters').existsSync(),
        isTrue,
      );
      expect(
        Directory('${paths.featurePath('home')}/presenters').existsSync(),
        isTrue,
      );

      final regenerated = ProjectGenerator(
        outputPath: tempDir.path,
        config: configFor(Architecture.cleanArchitecture),
      );
      await regenerated.clearGeneratedContent();
      await regenerated.generate();

      expect(
        Directory('${paths.featurePath('auth')}/presenters').existsSync(),
        isFalse,
        reason: 'stale MVP presenters/ must not survive a Clean regeneration',
      );
      expect(
        Directory('${paths.featurePath('home')}/presenters').existsSync(),
        isFalse,
      );
      expect(
        Directory('${paths.featurePath('auth')}/domain').existsSync(),
        isTrue,
      );
      expect(
        Directory('${paths.featurePath('auth')}/data').existsSync(),
        isTrue,
      );
      expect(
        Directory('${paths.featurePath('auth')}/presentation').existsSync(),
        isTrue,
      );
    });

    test(
        'clearGeneratedContent() never touches pubspec.yaml, '
        'assets/, or .smartwork/ — only what generate() itself owns', () async {
      final paths = ProjectPaths(projectRoot: tempDir.path);

      await ProjectGenerator(
        outputPath: tempDir.path,
        config: configFor(Architecture.mvp),
      ).generate();

      // Simulate a developer's own file dropped into assets/images/ —
      // clearGeneratedContent() must never delete it.
      File('${paths.assetsImages}/logo.png').writeAsStringSync('fake-png');
      final pubspecBefore = File(paths.pubspecFile).readAsStringSync();

      await ProjectGenerator(
        outputPath: tempDir.path,
        config: configFor(Architecture.cleanArchitecture),
      ).clearGeneratedContent();

      expect(File(paths.pubspecFile).readAsStringSync(), pubspecBefore);
      expect(File('${paths.assetsImages}/logo.png').existsSync(), isTrue);
      expect(File(paths.projectConfigFile).existsSync(), isTrue);
    });

    test(
        'clearGeneratedContent() is a safe no-op when nothing has been '
        'generated yet', () async {
      final generator = ProjectGenerator(
        outputPath: tempDir.path,
        config: configFor(Architecture.cleanArchitecture),
      );

      await generator.clearGeneratedContent();
      await generator.generate();

      final paths = ProjectPaths(projectRoot: tempDir.path);
      expect(Directory(paths.features).existsSync(), isTrue);
    });

    test(
        'clearGeneratedContent() removes lib/core, lib/features, '
        'lib/main.dart, test/core, and test/features specifically', () async {
      final paths = ProjectPaths(projectRoot: tempDir.path);
      final generator = ProjectGenerator(
        outputPath: tempDir.path,
        config: configFor(Architecture.cleanArchitecture),
      );
      await generator.generate();

      expect(Directory(paths.core).existsSync(), isTrue);
      expect(Directory(paths.features).existsSync(), isTrue);
      expect(File(paths.mainDartFile).existsSync(), isTrue);
      expect(Directory(paths.testCore).existsSync(), isTrue);
      expect(Directory(paths.testFeatures).existsSync(), isTrue);

      await generator.clearGeneratedContent();

      expect(Directory(paths.core).existsSync(), isFalse);
      expect(Directory(paths.features).existsSync(), isFalse);
      expect(File(paths.mainDartFile).existsSync(), isFalse);
      expect(Directory(paths.testCore).existsSync(), isFalse);
      expect(Directory(paths.testFeatures).existsSync(), isFalse);
    });
  });
}
