import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// A real, valid, square PNG — used as a valid App Icon source across
/// these tests. Fully opaque unless [alphaValue] is given.
List<int> _squarePng(int size, {int? alphaValue}) {
  final image = img.Image(
    width: size,
    height: size,
    numChannels: alphaValue != null ? 4 : 3,
  );
  if (alphaValue != null) {
    img.fill(image, color: img.ColorRgba8(0, 120, 215, alphaValue));
  } else {
    img.fill(image, color: img.ColorRgb8(0, 120, 215));
  }
  return img.encodePng(image);
}

/// A minimal but real iOS `Contents.json` — covers a shared-file
/// dedup case (iPhone/iPad both declaring `20x20@2x`), a decimal size
/// (`83.5x83.5`), and the 1024 marketing icon.
const _sampleIosContentsJson = '''
{
  "images": [
    {"size": "20x20", "idiom": "iphone", "filename": "Icon-App-20x20@2x.png", "scale": "2x"},
    {"size": "20x20", "idiom": "ipad", "filename": "Icon-App-20x20@2x.png", "scale": "2x"},
    {"size": "83.5x83.5", "idiom": "ipad", "filename": "Icon-App-83.5x83.5@2x.png", "scale": "2x"},
    {"size": "1024x1024", "idiom": "ios-marketing", "filename": "Icon-App-1024x1024@1x.png", "scale": "1x"}
  ],
  "info": {"version": 1, "author": "xcode"}
}
''';

const _sampleMacosContentsJson = '''
{
  "images": [
    {"size": "16x16", "idiom": "mac", "filename": "app_icon_16.png", "scale": "1x"},
    {"size": "512x512", "idiom": "mac", "filename": "app_icon_1024.png", "scale": "2x"}
  ],
  "info": {"version": 1, "author": "xcode"}
}
''';

void main() {
  group('ConfigValidator.validateAppIcon', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_appicon_cfg_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('a valid, decodable, square source passes with no errors', () {
      final sourcePath = '${tempDir.path}/icon.png';
      File(sourcePath).writeAsBytesSync(_squarePng(512));

      final errors = ConfigValidator.validateAppIcon(
          AppIconConfig(sourcePath: sourcePath));

      expect(errors, isEmpty);
    });

    test('an empty source path is rejected', () {
      final errors =
          ConfigValidator.validateAppIcon(AppIconConfig(sourcePath: ''));

      expect(errors, isNotEmpty);
      expect(errors.first.toString(), contains('cannot be empty'));
    });

    test('a nonexistent source path is rejected', () {
      final errors = ConfigValidator.validateAppIcon(
        AppIconConfig(sourcePath: '${tempDir.path}/does_not_exist.png'),
      );

      expect(errors, isNotEmpty);
      expect(errors.first.toString(), contains('not found'));
    });

    test('an unsupported file extension is rejected', () {
      final sourcePath = '${tempDir.path}/icon.gif';
      File(sourcePath).writeAsBytesSync(_squarePng(64));

      final errors = ConfigValidator.validateAppIcon(
          AppIconConfig(sourcePath: sourcePath));

      expect(errors, isNotEmpty);
      expect(errors.first.toString(), contains('must be a'));
    });

    test('a corrupt/invalid image fails clearly, not with a crash', () {
      final sourcePath = '${tempDir.path}/icon.png';
      File(sourcePath).writeAsBytesSync([0x00, 0x01, 0x02, 0x03, 0x04]);

      final errors = ConfigValidator.validateAppIcon(
          AppIconConfig(sourcePath: sourcePath));

      expect(errors, isNotEmpty);
      expect(errors.first.toString(), contains('could not be decoded'));
    });

    test('a non-square image is rejected, never stretched or distorted', () {
      final sourcePath = '${tempDir.path}/icon.png';
      final wide = img.Image(width: 200, height: 100, numChannels: 3);
      img.fill(wide, color: img.ColorRgb8(0, 0, 0));
      File(sourcePath).writeAsBytesSync(img.encodePng(wide));

      final errors = ConfigValidator.validateAppIcon(
          AppIconConfig(sourcePath: sourcePath));

      expect(errors, isNotEmpty);
      expect(errors.first.toString(), contains('must be square'));
      expect(errors.first.toString(), contains('200x100'));
    });

    test(
        'ProjectConfig.validate skips App Icon entirely when appIcon is '
        'null', () {
      final config = ProjectConfig(
        projectName: 'demo',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      );

      expect(config.appIcon, isNull);
      expect(ConfigValidator.validate(config), isEmpty);
    });

    test(
        'ProjectConfig.validate surfaces an invalid App Icon configured '
        'directly on a ProjectConfig', () {
      final config = ProjectConfig(
        projectName: 'demo',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
        appIcon: AppIconConfig(sourcePath: ''),
      );

      final errors = ConfigValidator.validate(config);
      expect(errors, isNotEmpty);
      expect(errors.first.toString(), contains('cannot be empty'));
    });
  });

  group('AppIconGenerator', () {
    final generator = AppIconGenerator();

    test('decode() decodes a valid PNG and returns null for garbage', () {
      expect(generator.decode(Uint8List.fromList(_squarePng(64))), isNotNull);
      expect(generator.decode(Uint8List.fromList([1, 2, 3])), isNull);
    });

    test('resizeToPng produces exact Android dimensions, all decodable', () {
      final source = generator.decode(Uint8List.fromList(_squarePng(1024)))!;

      for (final entry in AppIconGenerator.androidMipmapSizes.entries) {
        final bytes = generator.resizeToPng(source, entry.value);
        final decoded = img.decodePng(bytes)!;
        expect(decoded.width, entry.value, reason: entry.key);
        expect(decoded.height, entry.value, reason: entry.key);
      }
    });

    test('resizeToPng produces exact Web dimensions, all decodable', () {
      final source = generator.decode(Uint8List.fromList(_squarePng(1024)))!;

      final sizes = {
        AppIconGenerator.webFaviconSize,
        ...AppIconGenerator.webIconSizes
      };
      for (final size in sizes) {
        final decoded = img.decodePng(generator.resizeToPng(source, size))!;
        expect(decoded.width, size);
        expect(decoded.height, size);
      }
    });

    test(
        'resizeToPng produces exact iOS/macOS dimensions parsed from a '
        'real Contents.json, all decodable', () {
      final source = generator.decode(Uint8List.fromList(_squarePng(1024)))!;
      final targets = generator.parseAppIconSetTargets(_sampleIosContentsJson);

      for (final target in targets) {
        final decoded =
            img.decodePng(generator.resizeToPng(source, target.size))!;
        expect(decoded.width, target.size, reason: target.fileName);
        expect(decoded.height, target.size, reason: target.fileName);
      }
    });

    test(
        'resizeToMaskablePng produces the exact canvas size, with '
        'content padded inside a transparent safe zone (not a naive '
        'full-bleed resize)', () {
      final source = generator.decode(Uint8List.fromList(_squarePng(1024)))!;

      for (final size in AppIconGenerator.webIconSizes) {
        final decoded =
            img.decodePng(generator.resizeToMaskablePng(source, size))!;
        expect(decoded.width, size);
        expect(decoded.height, size);
        expect(decoded.hasAlpha, isTrue);

        // The corner is outside the 80% safe zone — must be transparent.
        expect(decoded.getPixel(0, 0).aNormalized, 0.0);
        expect(decoded.getPixel(size - 1, 0).aNormalized, 0.0);
        // The center is inside the safe zone — must carry the source's
        // own opaque color, proving content was actually drawn, not
        // just an empty transparent canvas.
        final center = decoded.getPixel(size ~/ 2, size ~/ 2);
        expect(center.aNormalized, 1.0);
        expect(center.b, greaterThan(150));
      }
    });

    test('hasVisibleTransparency is false for an opaque source', () {
      final source = generator.decode(Uint8List.fromList(_squarePng(64)))!;
      expect(generator.hasVisibleTransparency(source), isFalse);
    });

    test(
        'hasVisibleTransparency is false for a source with an alpha '
        'channel that is fully opaque everywhere (not merely "has an '
        'alpha channel")', () {
      final source = generator
          .decode(Uint8List.fromList(_squarePng(64, alphaValue: 255)))!;
      expect(source.hasAlpha, isTrue);
      expect(generator.hasVisibleTransparency(source), isFalse);
    });

    test('hasVisibleTransparency is true for a genuinely transparent source',
        () {
      final source = generator
          .decode(Uint8List.fromList(_squarePng(64, alphaValue: 128)))!;
      expect(generator.hasVisibleTransparency(source), isTrue);
    });

    test(
        'parseAppIconSetTargets deduplicates a file declared more than '
        'once, and resolves a decimal size x scale correctly', () {
      final targets = generator.parseAppIconSetTargets(_sampleIosContentsJson);
      final byFile = {for (final t in targets) t.fileName: t.size};

      expect(targets, hasLength(3));
      expect(byFile['Icon-App-20x20@2x.png'], 40);
      expect(byFile['Icon-App-83.5x83.5@2x.png'], 167);
      expect(byFile['Icon-App-1024x1024@1x.png'], 1024);
    });
  });

  group('AppIconLifecycle.setAppIcon', () {
    late Directory tempDir;
    late String projectPath;
    late File sourceFile;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartwork_appicon_lc_');
      projectPath = tempDir.path;
      sourceFile = File('${tempDir.path}_source.png')
        ..writeAsBytesSync(_squarePng(1024));

      await ProjectConfigFile(projectPath: projectPath).write(
        ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
        ),
      );
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
      if (sourceFile.existsSync()) sourceFile.deleteSync();
    });

    Future<void> createAndroid(String root) async {
      final manifestPath = '$root/android/app/src/main/AndroidManifest.xml';
      await File(manifestPath).create(recursive: true);
      await File(manifestPath)
          .writeAsString('<manifest>ORIGINAL_MANIFEST</manifest>');
      for (final dir in AppIconGenerator.androidMipmapSizes.keys) {
        final f = File('$root/android/app/src/main/res/$dir/ic_launcher.png');
        await f.create(recursive: true);
        await f.writeAsBytes([0, 0, 0]);
      }
    }

    Future<void> createIos(String root, {String? contentsJson}) async {
      final dir = '$root/ios/Runner/Assets.xcassets/AppIcon.appiconset';
      await Directory(dir).create(recursive: true);
      await File('$dir/Contents.json')
          .writeAsString(contentsJson ?? _sampleIosContentsJson);
    }

    Future<void> createMacos(String root, {String? contentsJson}) async {
      final dir = '$root/macos/Runner/Assets.xcassets/AppIcon.appiconset';
      await Directory(dir).create(recursive: true);
      await File('$dir/Contents.json')
          .writeAsString(contentsJson ?? _sampleMacosContentsJson);
    }

    Future<void> createWeb(String root) async {
      await Directory('$root/web/icons').create(recursive: true);
      await File('$root/web/index.html')
          .writeAsString('<html>ORIGINAL_INDEX</html>');
      await File('$root/web/manifest.json')
          .writeAsString('{"name": "ORIGINAL_MANIFEST"}');
      await File('$root/web/favicon.png').writeAsBytes([0]);
      await File('$root/web/icons/Icon-192.png').writeAsBytes([0]);
      await File('$root/web/icons/Icon-512.png').writeAsBytes([0]);
      await File('$root/web/icons/Icon-maskable-192.png').writeAsBytes([0]);
      await File('$root/web/icons/Icon-maskable-512.png').writeAsBytes([0]);
    }

    test(
        'a successful generation writes every in-scope target at the '
        'correct dimensions, leaves native config untouched, and '
        'persists the config', () async {
      await createAndroid(projectPath);
      await createIos(projectPath);
      await createMacos(projectPath);
      await createWeb(projectPath);

      final result = await AppIconLifecycle().setAppIcon(
        projectPath: projectPath,
        sourcePath: sourceFile.path,
      );

      expect(result.generatedFiles, isNotEmpty);

      for (final entry in AppIconGenerator.androidMipmapSizes.entries) {
        final decoded = img.decodePng(File(
          '$projectPath/android/app/src/main/res/${entry.key}/ic_launcher.png',
        ).readAsBytesSync())!;
        expect(decoded.width, entry.value, reason: entry.key);
      }

      String iosPath(String name) =>
          '$projectPath/ios/Runner/Assets.xcassets/AppIcon.appiconset/$name';
      expect(
        img
            .decodePng(
                File(iosPath('Icon-App-20x20@2x.png')).readAsBytesSync())!
            .width,
        40,
      );
      expect(
        img
            .decodePng(
                File(iosPath('Icon-App-83.5x83.5@2x.png')).readAsBytesSync())!
            .width,
        167,
      );
      expect(
        img
            .decodePng(
                File(iosPath('Icon-App-1024x1024@1x.png')).readAsBytesSync())!
            .width,
        1024,
      );

      String macosPath(String name) =>
          '$projectPath/macos/Runner/Assets.xcassets/AppIcon.appiconset/$name';
      expect(
        img
            .decodePng(File(macosPath('app_icon_16.png')).readAsBytesSync())!
            .width,
        16,
      );
      expect(
        img
            .decodePng(File(macosPath('app_icon_1024.png')).readAsBytesSync())!
            .width,
        1024,
      );

      expect(
        img
            .decodePng(File('$projectPath/web/favicon.png').readAsBytesSync())!
            .width,
        16,
      );
      expect(
        img
            .decodePng(
                File('$projectPath/web/icons/Icon-192.png').readAsBytesSync())!
            .width,
        192,
      );
      final maskable = img.decodePng(
        File('$projectPath/web/icons/Icon-maskable-192.png').readAsBytesSync(),
      )!;
      expect(maskable.width, 192);
      expect(maskable.getPixel(0, 0).aNormalized, 0.0);

      // Native/config files that reference these icons are never
      // rewritten — only the PNG bytes they already point at change.
      expect(
        File('$projectPath/android/app/src/main/AndroidManifest.xml')
            .readAsStringSync(),
        '<manifest>ORIGINAL_MANIFEST</manifest>',
      );
      expect(
        File(
          '$projectPath/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
        ).readAsStringSync(),
        _sampleIosContentsJson,
      );
      expect(
        File(
          '$projectPath/macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
        ).readAsStringSync(),
        _sampleMacosContentsJson,
      );
      expect(
        File('$projectPath/web/index.html').readAsStringSync(),
        '<html>ORIGINAL_INDEX</html>',
      );
      expect(
        File('$projectPath/web/manifest.json').readAsStringSync(),
        '{"name": "ORIGINAL_MANIFEST"}',
      );

      final updatedConfig =
          await ProjectConfigFile(projectPath: projectPath).read();
      expect(updatedConfig.appIcon?.sourcePath, sourceFile.path);
    });

    test(
        'throws FileSystemException for a directory that is not a '
        'SmartWork project', () async {
      final emptyDir =
          Directory.systemTemp.createTempSync('smartwork_no_project_');
      addTearDown(() => emptyDir.deleteSync(recursive: true));

      expect(
        () => AppIconLifecycle().setAppIcon(
            projectPath: emptyDir.path, sourcePath: sourceFile.path),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('throws InvalidAppIconConfigException for a nonexistent source',
        () async {
      await createWeb(projectPath);

      expect(
        () => AppIconLifecycle().setAppIcon(
          projectPath: projectPath,
          sourcePath: '${tempDir.path}/nope.png',
        ),
        throwsA(isA<InvalidAppIconConfigException>()),
      );
    });

    test('throws InvalidAppIconConfigException for a corrupt image', () async {
      await createWeb(projectPath);
      final badSource = File('${tempDir.path}_bad.png')
        ..writeAsBytesSync([1, 2, 3]);
      addTearDown(() => badSource.deleteSync());

      expect(
        () => AppIconLifecycle().setAppIcon(
          projectPath: projectPath,
          sourcePath: badSource.path,
        ),
        throwsA(isA<InvalidAppIconConfigException>()),
      );
    });

    test('throws InvalidAppIconConfigException for a non-square source',
        () async {
      await createWeb(projectPath);
      final wide = img.Image(width: 100, height: 50, numChannels: 3);
      img.fill(wide, color: img.ColorRgb8(0, 0, 0));
      final wideSource = File('${tempDir.path}_wide.png')
        ..writeAsBytesSync(img.encodePng(wide));
      addTearDown(() => wideSource.deleteSync());

      expect(
        () => AppIconLifecycle().setAppIcon(
          projectPath: projectPath,
          sourcePath: wideSource.path,
        ),
        throwsA(isA<InvalidAppIconConfigException>()),
      );
    });

    test(
        'throws AppIconTransparencyException for a source with visible '
        'transparency, without writing anything', () async {
      await createAndroid(projectPath);
      await createWeb(projectPath);
      final transparentSource = File('${tempDir.path}_transparent.png')
        ..writeAsBytesSync(_squarePng(64, alphaValue: 128));
      addTearDown(() => transparentSource.deleteSync());

      final originalBytes = File(
        '$projectPath/android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
      ).readAsBytesSync();

      expect(
        () => AppIconLifecycle().setAppIcon(
          projectPath: projectPath,
          sourcePath: transparentSource.path,
        ),
        throwsA(isA<AppIconTransparencyException>()),
      );

      expect(
        File(
          '$projectPath/android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
        ).readAsBytesSync(),
        originalBytes,
      );
    });

    test(
        'throws NoSupportedPlatformFoundException when no in-scope '
        'platform folder exists at all', () async {
      expect(
        () => AppIconLifecycle().setAppIcon(
          projectPath: projectPath,
          sourcePath: sourceFile.path,
        ),
        throwsA(isA<NoSupportedPlatformFoundException>()),
      );
    });

    test(
        'a project missing some platform folders only generates icons '
        'for the platforms that actually exist (no error)', () async {
      await createWeb(projectPath);

      final result = await AppIconLifecycle().setAppIcon(
        projectPath: projectPath,
        sourcePath: sourceFile.path,
      );

      expect(result.generatedFiles, hasLength(5));
      expect(Directory('$projectPath/android').existsSync(), isFalse);
      expect(Directory('$projectPath/ios').existsSync(), isFalse);
      expect(Directory('$projectPath/macos').existsSync(), isFalse);
    });

    test(
        'all target paths are resolved before any write — a failure '
        'partway through (an unparseable Contents.json) leaves no '
        'partial output, not even for unrelated platforms', () async {
      await createAndroid(projectPath);
      await createIos(projectPath, contentsJson: 'not valid json {{{');
      await createWeb(projectPath);

      final originalAndroidBytes = File(
        '$projectPath/android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
      ).readAsBytesSync();
      final originalWebBytes =
          File('$projectPath/web/favicon.png').readAsBytesSync();

      await expectLater(
        AppIconLifecycle().setAppIcon(
          projectPath: projectPath,
          sourcePath: sourceFile.path,
        ),
        throwsA(anything),
      );

      expect(
        File(
          '$projectPath/android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
        ).readAsBytesSync(),
        originalAndroidBytes,
      );
      expect(
        File('$projectPath/web/favicon.png').readAsBytesSync(),
        originalWebBytes,
      );
    });

    test('repeated generation replaces the existing icon files', () async {
      await createAndroid(projectPath);
      await createWeb(projectPath);

      await AppIconLifecycle()
          .setAppIcon(projectPath: projectPath, sourcePath: sourceFile.path);
      final firstBytes = File(
        '$projectPath/android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
      ).readAsBytesSync();

      final secondSource = File('${tempDir.path}_source2.png');
      // A different-colored square, so the re-encoded PNG bytes differ.
      final differentColor =
          img.Image(width: 1024, height: 1024, numChannels: 3);
      img.fill(differentColor, color: img.ColorRgb8(10, 200, 30));
      await secondSource.writeAsBytes(img.encodePng(differentColor));
      addTearDown(() => secondSource.deleteSync());

      await AppIconLifecycle()
          .setAppIcon(projectPath: projectPath, sourcePath: secondSource.path);
      final secondBytes = File(
        '$projectPath/android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
      ).readAsBytesSync();

      expect(secondBytes, isNot(equals(firstBytes)));

      final updatedConfig =
          await ProjectConfigFile(projectPath: projectPath).read();
      expect(updatedConfig.appIcon?.sourcePath, secondSource.path);
    });

    test('unrelated project files remain unchanged', () async {
      await createAndroid(projectPath);
      await createWeb(projectPath);
      final unrelatedFile = File('$projectPath/lib/main.dart');
      await unrelatedFile.create(recursive: true);
      await unrelatedFile.writeAsString('void main() {}');

      await AppIconLifecycle()
          .setAppIcon(projectPath: projectPath, sourcePath: sourceFile.path);

      expect(unrelatedFile.readAsStringSync(), 'void main() {}');
    });
  });
}
