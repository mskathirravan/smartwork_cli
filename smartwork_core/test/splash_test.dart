import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// A real, minimal, valid 4x4 PNG — not a placeholder byte sequence —
/// so anything that actually decodes it (a future real Flutter E2E
/// `Image.asset` load) sees a genuine image, not garbage.
final List<int> _validPngBytes = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x04, //
  0x08, 0x02, 0x00, 0x00, 0x00, 0x26, 0x93, 0x09, //
  0x29, 0x00, 0x00, 0x00, 0x15, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x62, 0x62, 0x60, 0x60, 0xF8, //
  0xCF, 0x40, 0x01, 0x00, 0x00, 0xFF, 0xFF, 0x03, //
  0x00, 0x02, 0x9C, 0x01, 0x9E, 0x97, 0xF6, 0x25, //
  0x0F, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, //
  0x44, 0xAE, 0x42, 0x60, 0x82, //
];

void main() {
  group('SplashConfig', () {
    test('strips a leading # from backgroundColor, storing bare hex', () {
      final config =
          SplashConfig(backgroundColor: '#2E7D32', iconPath: 'x.png');
      expect(config.backgroundColor, '2E7D32');
    });

    test('accepts a backgroundColor already given without #', () {
      final config = SplashConfig(backgroundColor: 'FF0000', iconPath: 'x.png');
      expect(config.backgroundColor, 'FF0000');
    });

    test('toYaml/fromYaml round-trips losslessly', () {
      final config = SplashConfig(
        backgroundColor: '2E7D32',
        iconPath: '/dev/icon.png',
      );

      final restored = SplashConfig.fromYaml(config.toYaml());

      expect(restored.backgroundColor, config.backgroundColor);
      expect(restored.iconPath, config.iconPath);
    });
  });

  group('ProjectConfig.splash', () {
    test('defaults to null when not given', () {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
      );

      expect(config.splash, isNull);
    });

    test('round-trips through toYaml/fromYaml when present', () {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        splash:
            SplashConfig(backgroundColor: '2E7D32', iconPath: '/dev/icon.png'),
      );

      final restored = ProjectConfig.fromYaml(config.toYaml());

      expect(restored.splash, isNotNull);
      expect(restored.splash!.backgroundColor, '2E7D32');
      expect(restored.splash!.iconPath, '/dev/icon.png');
    });

    test(
        'is absent from toYaml entirely when null — backward compatible '
        'with a pre-V1.1-8 project.yaml', () {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
      );

      expect(config.toYaml().containsKey('splash'), isFalse);
    });

    test(
        'fromYaml resolves splash to null when the key is entirely '
        'absent (a real pre-V1.1-8 project.yaml)', () {
      final yaml = {
        'projectName': 'demo_app',
        'appTargets': ['android', 'ios'],
        'architecture': 'cleanArchitecture',
        'stateManagement': 'bloc',
        'network': 'http',
        'storage': 'sharedPreferences',
        'services': [],
        'initialFeatures': ['home'],
        'homeFeatureName': 'home',
      };

      final config = ProjectConfig.fromYaml(yaml);

      expect(config.splash, isNull);
    });
  });

  group('ConfigValidator.validateSplash', () {
    test('accepts a valid #RRGGBB color and an existing supported icon', () {
      final tempFile = File(
        '${Directory.systemTemp.path}/smartwork_splash_valid_icon.png',
      )..writeAsBytesSync(_validPngBytes);
      addTearDown(() => tempFile.deleteSync());

      final errors = ConfigValidator.validateSplash(
        SplashConfig(backgroundColor: '#2E7D32', iconPath: tempFile.path),
      );

      expect(errors, isEmpty);
    });

    test('rejects a background color that is not 6 hex digits', () {
      final errors = ConfigValidator.validateSplash(
        SplashConfig(backgroundColor: 'not-a-color', iconPath: 'icon.png'),
      );

      expect(errors, isNotEmpty);
      expect(errors.first.toString(), contains('background color'));
    });

    test('rejects a 3-digit shorthand hex — only 6 digits are accepted', () {
      final errors = ConfigValidator.validateSplash(
        SplashConfig(backgroundColor: 'FFF', iconPath: 'icon.png'),
      );

      expect(errors, isNotEmpty);
    });

    test('rejects an icon path that does not exist', () {
      final errors = ConfigValidator.validateSplash(
        SplashConfig(
          backgroundColor: '2E7D32',
          iconPath: '/no/such/icon.png',
        ),
      );

      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.toString().contains('not found')), isTrue);
    });

    test('rejects an icon with an unsupported extension', () {
      final tempFile = File(
        '${Directory.systemTemp.path}/smartwork_splash_bad_ext.svg',
      )..writeAsStringSync('<svg></svg>');
      addTearDown(() => tempFile.deleteSync());

      final errors = ConfigValidator.validateSplash(
        SplashConfig(backgroundColor: '2E7D32', iconPath: tempFile.path),
      );

      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.toString().contains('.png or .jpg')), isTrue);
    });

    test('rejects an empty icon path', () {
      final errors = ConfigValidator.validateSplash(
        SplashConfig(backgroundColor: '2E7D32', iconPath: ''),
      );

      expect(errors, isNotEmpty);
    });
  });

  group('SplashLifecycle.addSplash', () {
    late Directory tempDir;
    late String projectPath;
    late File iconFile;

    ProjectConfig baseConfig({
      FontConfig? fonts,
      Architecture architecture = Architecture.cleanArchitecture,
      StateManagement stateManagement = StateManagement.bloc,
    }) {
      return ProjectConfig(
        projectName: 'demo_app',
        architecture: architecture,
        stateManagement: stateManagement,
        network: Network.http,
        storage: Storage.sharedPreferences,
        fonts: fonts,
        initialFeatures: ['home'],
      );
    }

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_splash_test_');
      projectPath = tempDir.path;
      iconFile = File('${tempDir.path}_icon.png')
        ..writeAsBytesSync(_validPngBytes);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
      if (iconFile.existsSync()) iconFile.deleteSync();
    });

    test('generates lib/shared/ui/splash_screen.dart and its test', () async {
      await ProjectGenerator(outputPath: projectPath, config: baseConfig())
          .generate();

      await SplashLifecycle().addSplash(
        projectPath: projectPath,
        backgroundColor: '#2E7D32',
        iconPath: iconFile.path,
      );

      expect(
        File('$projectPath/lib/shared/ui/splash_screen.dart').existsSync(),
        isTrue,
      );
      expect(
        File('$projectPath/test/shared/ui/splash_screen_test.dart')
            .existsSync(),
        isTrue,
      );
    });

    test(
        'copies the icon into assets/icons/, never modifying other '
        'asset folders', () async {
      await ProjectGenerator(outputPath: projectPath, config: baseConfig())
          .generate();
      final iconsDirBefore = Directory('$projectPath/assets/images').listSync();

      final result = await SplashLifecycle().addSplash(
        projectPath: projectPath,
        backgroundColor: '2E7D32',
        iconPath: iconFile.path,
      );

      expect(result.iconAssetPath,
          'assets/icons/${iconFile.uri.pathSegments.last}');
      expect(
        File('$projectPath/${result.iconAssetPath}').existsSync(),
        isTrue,
      );
      expect(
        File('$projectPath/${result.iconAssetPath}').readAsBytesSync(),
        _validPngBytes,
      );
      expect(
        Directory('$projectPath/assets/images').listSync().length,
        iconsDirBefore.length,
      );
    });

    test(
        'the generated background color is baked in as a Color(0xFF...) '
        'literal', () async {
      await ProjectGenerator(outputPath: projectPath, config: baseConfig())
          .generate();

      await SplashLifecycle().addSplash(
        projectPath: projectPath,
        backgroundColor: '#2e7d32',
        iconPath: iconFile.path,
      );

      final content = File('$projectPath/lib/shared/ui/splash_screen.dart')
          .readAsStringSync();
      expect(content, contains('Color(0xFF2E7D32)'));
    });

    test(
        'the generated widget uses FractionallySizedBox(widthFactor: '
        '0.6) so the icon is 60% of the available width', () async {
      await ProjectGenerator(outputPath: projectPath, config: baseConfig())
          .generate();

      await SplashLifecycle().addSplash(
        projectPath: projectPath,
        backgroundColor: '2E7D32',
        iconPath: iconFile.path,
      );

      final content = File('$projectPath/lib/shared/ui/splash_screen.dart')
          .readAsStringSync();
      expect(content, contains('widthFactor: 0.6'));
      expect(content, contains('fit: BoxFit.contain'));
    });

    test(
        'the generated widget centers its content and covers the full '
        'screen via Scaffold + Center', () async {
      await ProjectGenerator(outputPath: projectPath, config: baseConfig())
          .generate();

      await SplashLifecycle().addSplash(
        projectPath: projectPath,
        backgroundColor: '2E7D32',
        iconPath: iconFile.path,
      );

      final content = File('$projectPath/lib/shared/ui/splash_screen.dart')
          .readAsStringSync();
      expect(content, contains('class SplashScreen extends StatelessWidget'));
      expect(content, contains('Scaffold('));
      expect(content, contains('backgroundColor:'));
      expect(content, contains('body: Center('));
    });

    test(
        'the generated widget has no state management construct of '
        'any kind', () async {
      await ProjectGenerator(outputPath: projectPath, config: baseConfig())
          .generate();

      await SplashLifecycle().addSplash(
        projectPath: projectPath,
        backgroundColor: '2E7D32',
        iconPath: iconFile.path,
      );

      final content = File('$projectPath/lib/shared/ui/splash_screen.dart')
          .readAsStringSync();
      expect(content, isNot(contains('Bloc')));
      expect(content, isNot(contains('Cubit')));
      expect(content, isNot(contains('GetxController')));
      expect(content, isNot(contains('StateNotifier')));
      expect(content, isNot(contains('Provider')));
      expect(content, isNot(contains('Navigator')));
      expect(content, isNot(contains('Timer')));
      expect(content, isNot(contains('Service')));
    });

    test('adds splash_screen.dart to the Shared UI barrel', () async {
      await ProjectGenerator(outputPath: projectPath, config: baseConfig())
          .generate();
      final barrelBefore =
          File('$projectPath/lib/shared/ui/shared_ui.dart').readAsStringSync();
      expect(barrelBefore, isNot(contains('splash_screen.dart')));

      await SplashLifecycle().addSplash(
        projectPath: projectPath,
        backgroundColor: '2E7D32',
        iconPath: iconFile.path,
      );

      final barrelAfter =
          File('$projectPath/lib/shared/ui/shared_ui.dart').readAsStringSync();
      expect(barrelAfter, contains("export 'splash_screen.dart';"));
      // Every existing export survives untouched.
      for (final export in [
        'accessible.dart',
        'app_alert.dart',
        'empty_state_view.dart',
        'error_state_view.dart',
        'loading_indicator.dart',
        'maintenance_view.dart',
      ]) {
        expect(barrelAfter, contains("export '$export';"));
      }
    });

    test(
        'touches pubspec.yaml\'s modification time (never its content) '
        'so Flutter\'s own tooling notices the newly-added icon asset',
        () async {
      await ProjectGenerator(outputPath: projectPath, config: baseConfig())
          .generate();
      final pubspecFile = File('$projectPath/pubspec.yaml');
      final contentBefore = pubspecFile.readAsStringSync();
      final mtimeBefore = pubspecFile.lastModifiedSync();
      await Future<void>.delayed(const Duration(seconds: 1));

      await SplashLifecycle().addSplash(
        projectPath: projectPath,
        backgroundColor: '2E7D32',
        iconPath: iconFile.path,
      );

      expect(pubspecFile.readAsStringSync(), contentBefore);
      expect(
        pubspecFile.lastModifiedSync().isAfter(mtimeBefore),
        isTrue,
      );
    });

    test(
        'persists SplashConfig to .smartwork/project.yaml, preserving '
        'Fonts and every other field', () async {
      await ProjectGenerator(
        outputPath: projectPath,
        config: baseConfig(
          fonts: FontConfig.google(GoogleFontConfig(family: 'Roboto')),
        ),
      ).generate();

      await SplashLifecycle().addSplash(
        projectPath: projectPath,
        backgroundColor: '2E7D32',
        iconPath: iconFile.path,
      );

      final config = await ProjectConfigFile(projectPath: projectPath).read();
      expect(config.splash, isNotNull);
      expect(config.splash!.backgroundColor, '2E7D32');
      expect(config.fonts.type, FontType.google);
      expect(config.fonts.google!.family, 'Roboto');
      expect(config.initialFeatures, ['home']);
    });

    test(
        'throws InvalidSplashConfigException for an invalid color, '
        'writing nothing at all', () async {
      await ProjectGenerator(outputPath: projectPath, config: baseConfig())
          .generate();

      expect(
        () => SplashLifecycle().addSplash(
          projectPath: projectPath,
          backgroundColor: 'not-a-color',
          iconPath: iconFile.path,
        ),
        throwsA(isA<InvalidSplashConfigException>()),
      );
      expect(
        File('$projectPath/lib/shared/ui/splash_screen.dart').existsSync(),
        isFalse,
      );
      final config = await ProjectConfigFile(projectPath: projectPath).read();
      expect(config.splash, isNull);
    });

    test('throws InvalidSplashConfigException for a missing icon file',
        () async {
      await ProjectGenerator(outputPath: projectPath, config: baseConfig())
          .generate();

      expect(
        () => SplashLifecycle().addSplash(
          projectPath: projectPath,
          backgroundColor: '2E7D32',
          iconPath: '/no/such/icon.png',
        ),
        throwsA(isA<InvalidSplashConfigException>()),
      );
    });

    test(
        'throws FileSystemException for a directory that is not a '
        'SmartWork project', () async {
      expect(
        () => SplashLifecycle().addSplash(
          projectPath: projectPath,
          backgroundColor: '2E7D32',
          iconPath: iconFile.path,
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test(
        'is idempotent: re-running with the same configuration produces '
        'byte-identical output', () async {
      await ProjectGenerator(outputPath: projectPath, config: baseConfig())
          .generate();

      await SplashLifecycle().addSplash(
        projectPath: projectPath,
        backgroundColor: '2E7D32',
        iconPath: iconFile.path,
      );
      final firstContent = File('$projectPath/lib/shared/ui/splash_screen.dart')
          .readAsStringSync();

      await SplashLifecycle().addSplash(
        projectPath: projectPath,
        backgroundColor: '2E7D32',
        iconPath: iconFile.path,
      );
      final secondContent =
          File('$projectPath/lib/shared/ui/splash_screen.dart')
              .readAsStringSync();

      expect(secondContent, firstContent);
      final barrel =
          File('$projectPath/lib/shared/ui/shared_ui.dart').readAsStringSync();
      expect(
        "export 'splash_screen.dart';".allMatches(barrel).length,
        1,
      );
    });

    test(
        'running again with a different backgroundColor/icon updates '
        'the generated widget in place, never duplicating it', () async {
      await ProjectGenerator(outputPath: projectPath, config: baseConfig())
          .generate();
      await SplashLifecycle().addSplash(
        projectPath: projectPath,
        backgroundColor: '2E7D32',
        iconPath: iconFile.path,
      );

      await SplashLifecycle().addSplash(
        projectPath: projectPath,
        backgroundColor: 'FF0000',
        iconPath: iconFile.path,
      );

      final content = File('$projectPath/lib/shared/ui/splash_screen.dart')
          .readAsStringSync();
      expect(content, contains('Color(0xFFFF0000)'));
      expect(content, isNot(contains('Color(0xFF2E7D32)')));
      expect(
        'class SplashScreen'.allMatches(content).length,
        1,
      );
    });

    test(
        'is architecture-independent: byte-identical generated widget '
        'across Clean+BLoC and MVVM+Riverpod', () async {
      final cleanDir =
          Directory.systemTemp.createTempSync('smartwork_splash_clean_');
      final mvvmDir =
          Directory.systemTemp.createTempSync('smartwork_splash_mvvm_');
      addTearDown(() => cleanDir.deleteSync(recursive: true));
      addTearDown(() => mvvmDir.deleteSync(recursive: true));

      await ProjectGenerator(
        outputPath: cleanDir.path,
        config: baseConfig(architecture: Architecture.cleanArchitecture),
      ).generate();
      await ProjectGenerator(
        outputPath: mvvmDir.path,
        config: baseConfig(
          architecture: Architecture.mvvm,
          stateManagement: StateManagement.riverpod,
        ),
      ).generate();

      await SplashLifecycle().addSplash(
        projectPath: cleanDir.path,
        backgroundColor: '2E7D32',
        iconPath: iconFile.path,
      );
      await SplashLifecycle().addSplash(
        projectPath: mvvmDir.path,
        backgroundColor: '2E7D32',
        iconPath: iconFile.path,
      );

      final cleanContent =
          File('${cleanDir.path}/lib/shared/ui/splash_screen.dart')
              .readAsStringSync();
      final mvvmContent =
          File('${mvvmDir.path}/lib/shared/ui/splash_screen.dart')
              .readAsStringSync();
      expect(cleanContent, mvvmContent);
    });

    test(
        'a full smartwork init regeneration keeps exporting an '
        'already-added Splash Screen from the Shared UI barrel', () async {
      final config = baseConfig();
      final generator =
          ProjectGenerator(outputPath: projectPath, config: config);
      await generator.generate();
      await SplashLifecycle().addSplash(
        projectPath: projectPath,
        backgroundColor: '2E7D32',
        iconPath: iconFile.path,
      );

      await generator.clearGeneratedContent();
      await generator.generate();

      final barrel =
          File('$projectPath/lib/shared/ui/shared_ui.dart').readAsStringSync();
      expect(barrel, contains("export 'splash_screen.dart';"));
      // clearGeneratedContent() never touches lib/shared/, so the
      // widget itself survives a regeneration untouched too.
      expect(
        File('$projectPath/lib/shared/ui/splash_screen.dart').existsSync(),
        isTrue,
      );
    });
  });
}
