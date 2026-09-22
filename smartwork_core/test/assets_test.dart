import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The Assets foundation (App Target + Assets milestone): every
/// generated project gets `assets/{images,fonts,icons,animations}/`,
/// a matching `pubspec.yaml` asset declaration, and real
/// `AssetConstants` paths — with no `.placeholder` file anywhere,
/// since an empty folder reference in `pubspec.yaml` is already valid.
void main() {
  group('Assets directories', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_assets_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('all four standard asset folders are generated, empty', () async {
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

      final paths = ProjectPaths(projectRoot: tempDir.path);
      for (final dir in [
        paths.assetsImages,
        paths.assetsFonts,
        paths.assetsIcons,
        paths.assetsAnimations,
      ]) {
        expect(Directory(dir).existsSync(), isTrue, reason: '$dir missing');
        expect(Directory(dir).listSync(), isEmpty);
      }
    });

    test(
        'no .placeholder file exists anywhere under the generated '
        'project — an empty pubspec folder reference is already valid',
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

      final placeholders = Directory(tempDir.path)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.placeholder'));

      expect(placeholders, isEmpty);
    });

    test(
        'generated for every architecture, independent of the '
        'architecture-specific feature layout', () async {
      for (final architecture in Architecture.values) {
        final dir =
            Directory.systemTemp.createTempSync('smartwork_assets_arch_');
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
        expect(Directory(paths.assets).existsSync(), isTrue);
      }
    });
  });

  group('pubspec.yaml asset declaration', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_assets_pub_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'PubspecGenerator.generate() (from-scratch path) declares the '
        'four standard asset folders under flutter:', () async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );

      final yamlText = await PubspecGenerator(
        resolver: VersionResolver(fetch: (_) async => null),
      ).generate(config);
      final doc = loadYaml(yamlText) as YamlMap;

      final flutterSection = doc['flutter'] as YamlMap;
      final assets = (flutterSection['assets'] as YamlList).cast<String>();

      expect(assets, [
        'assets/images/',
        'assets/fonts/',
        'assets/icons/',
        'assets/animations/',
      ]);
      expect(flutterSection['uses-material-design'], isTrue);
    });

    test(
        'PubspecGenerator.mergeInto() inserts the same four asset '
        'folders into an existing flutter-create pubspec, without '
        'corrupting the nested dependencies.flutter SDK entry', () async {
      const existing = '''
name: demo_app
description: "A new Flutter project."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.9.2

dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
''';
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );

      final merged = await PubspecGenerator(
        resolver: VersionResolver(fetch: (_) async => null),
      ).mergeInto(existing, config);
      final doc = loadYaml(merged) as YamlMap;

      final flutterSection = doc['flutter'] as YamlMap;
      final assets = (flutterSection['assets'] as YamlList).cast<String>();
      expect(assets, [
        'assets/images/',
        'assets/fonts/',
        'assets/icons/',
        'assets/animations/',
      ]);

      // The nested dependencies.flutter SDK entry must survive untouched.
      final dependencies = doc['dependencies'] as YamlMap;
      final flutterDependency = dependencies['flutter'] as YamlMap;
      expect(flutterDependency['sdk'], 'flutter');
      expect(dependencies['cupertino_icons'], '^1.0.8');
    });

    test(
        'mergeInto() is idempotent — calling it twice never duplicates '
        'the assets: list', () async {
      const existing = '''
name: demo_app
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.9.2

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
''';
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );

      final generator = PubspecGenerator(
        resolver: VersionResolver(fetch: (_) async => null),
      );
      final once = await generator.mergeInto(existing, config);
      final twice = await generator.mergeInto(once, config);

      expect('assets:'.allMatches(twice).length, 1);
    });
  });

  group('AssetConstants', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_assets_const_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'generated asset_constants.dart declares the standard folder '
        'paths matching pubspec.yaml exactly', () async {
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

      final paths = ProjectPaths(projectRoot: tempDir.path);
      final content = File(paths.coreConstantsAssetFile).readAsStringSync();

      expect(
          content,
          contains("static const String imagesPath = "
              "'assets/images/';"));
      expect(
          content,
          contains("static const String fontsPath = "
              "'assets/fonts/';"));
      expect(
          content,
          contains("static const String iconsPath = "
              "'assets/icons/';"));
      expect(
          content,
          contains("static const String animationsPath = "
              "'assets/animations/';"));
      expect(content, isNot(contains('{{')));
    });
  });
}
