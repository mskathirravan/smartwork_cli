import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

import '../filesystem/file_writer.dart';
import '../models/app_icon_config.dart';
import '../models/project_config.dart';
import '../models/project_config_file.dart';
import '../validator/config_validator.dart';
import 'app_icon_generator.dart';

class InvalidAppIconConfigException implements Exception {
  final List<ValidationError> errors;

  InvalidAppIconConfigException(this.errors);

  @override
  String toString() => errors.map((e) => e.toString()).join('; ');
}

class AppIconTransparencyException implements Exception {
  @override
  String toString() =>
      'App Icon source contains transparency, but the iOS App Store '
      'marketing icon (1024x1024) must be fully opaque. SmartWork does '
      'not automatically flatten transparency — doing so would require '
      'choosing an arbitrary background color. Provide a fully opaque '
      'source image (no partially- or fully-transparent pixels) and try '
      'again.';
}

class NoSupportedPlatformFoundException implements Exception {
  @override
  String toString() =>
      'No supported platform folder (android/, ios/, macos/, or web/) '
      'was found under this project — there is nothing to generate an '
      'App Icon into.';
}

class AppIconResult {
  final List<String> generatedFiles;

  AppIconResult({required this.generatedFiles});
}

class AppIconLifecycle {
  final AppIconGenerator _generator;

  AppIconLifecycle({AppIconGenerator? generator})
      : _generator = generator ?? AppIconGenerator();

  Future<AppIconResult> setAppIcon({
    required String projectPath,
    required String sourcePath,
  }) async {
    final appIcon = AppIconConfig(sourcePath: sourcePath);
    final errors = ConfigValidator.validateAppIcon(appIcon);
    if (errors.isNotEmpty) {
      throw InvalidAppIconConfigException(errors);
    }

    final config = await ProjectConfigFile(projectPath: projectPath).read();

    final sourceBytes = await File(sourcePath).readAsBytes();
    final source = _generator.decode(sourceBytes)!;

    if (_generator.hasVisibleTransparency(source)) {
      throw AppIconTransparencyException();
    }

    final outputs = <String, List<int>>{};

    if (Directory(path.join(projectPath, 'android')).existsSync()) {
      for (final entry in AppIconGenerator.androidMipmapSizes.entries) {
        final targetPath = path.join(
          projectPath,
          'android',
          'app',
          'src',
          'main',
          'res',
          entry.key,
          'ic_launcher.png',
        );
        outputs[targetPath] = _generator.resizeToPng(source, entry.value);
      }
    }

    await _resolveAppIconSet(
      outputs: outputs,
      source: source,
      contentsJsonPath: path.join(
        projectPath,
        'ios',
        'Runner',
        'Assets.xcassets',
        'AppIcon.appiconset',
        'Contents.json',
      ),
      appIconSetDir: path.join(
        projectPath,
        'ios',
        'Runner',
        'Assets.xcassets',
        'AppIcon.appiconset',
      ),
    );

    await _resolveAppIconSet(
      outputs: outputs,
      source: source,
      contentsJsonPath: path.join(
        projectPath,
        'macos',
        'Runner',
        'Assets.xcassets',
        'AppIcon.appiconset',
        'Contents.json',
      ),
      appIconSetDir: path.join(
        projectPath,
        'macos',
        'Runner',
        'Assets.xcassets',
        'AppIcon.appiconset',
      ),
    );

    if (Directory(path.join(projectPath, 'web')).existsSync()) {
      outputs[path.join(projectPath, 'web', 'favicon.png')] =
          _generator.resizeToPng(source, AppIconGenerator.webFaviconSize);
      for (final size in AppIconGenerator.webIconSizes) {
        outputs[path.join(projectPath, 'web', 'icons', 'Icon-$size.png')] =
            _generator.resizeToPng(source, size);
        outputs[path.join(
          projectPath,
          'web',
          'icons',
          'Icon-maskable-$size.png',
        )] = _generator.resizeToMaskablePng(source, size);
      }
    }

    if (outputs.isEmpty) {
      throw NoSupportedPlatformFoundException();
    }

    final fileWriter = FileWriter();
    for (final entry in outputs.entries) {
      await fileWriter.writeBytes(entry.key, entry.value);
    }

    final updatedConfig = _withAppIcon(config, appIcon);
    await ProjectConfigFile(projectPath: projectPath).write(updatedConfig);

    return AppIconResult(
      generatedFiles:
          outputs.keys.map((p) => path.relative(p, from: projectPath)).toList(),
    );
  }

  Future<void> _resolveAppIconSet({
    required Map<String, List<int>> outputs,
    required img.Image source,
    required String contentsJsonPath,
    required String appIconSetDir,
  }) async {
    final contentsFile = File(contentsJsonPath);
    if (!await contentsFile.exists()) return;

    final targets = _generator.parseAppIconSetTargets(
      await contentsFile.readAsString(),
    );
    for (final target in targets) {
      outputs[path.join(appIconSetDir, target.fileName)] =
          _generator.resizeToPng(source, target.size);
    }
  }

  ProjectConfig _withAppIcon(ProjectConfig config, AppIconConfig appIcon) {
    return config.copyWith(appIcon: appIcon);
  }
}
