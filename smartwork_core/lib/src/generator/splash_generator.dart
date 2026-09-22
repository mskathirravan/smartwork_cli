import 'dart:io';

import 'package:path/path.dart' as path;

import '../filesystem/file_writer.dart';
import '../models/splash_config.dart';
import '../paths/project_paths.dart';
import '../template/splash/splash_templates.dart';

class SplashGenerator {
  Future<void> generate({
    required SplashConfig splash,
    required String projectName,
    required ProjectPaths paths,
  }) async {
    final fileWriter = FileWriter();
    final iconFileName = path.basename(splash.iconPath);
    final iconAssetPath = 'assets/icons/$iconFileName';
    final backgroundColorHex = normalizeHex(splash.backgroundColor);

    await fileWriter.copyFile(
      splash.iconPath,
      path.join(paths.assetsIcons, iconFileName),
    );

    await fileWriter.write(
      paths.sharedUiFile('splash_screen.dart'),
      SplashTemplates.splashScreenSource(
        backgroundColorHex: backgroundColorHex,
        iconAssetPath: iconAssetPath,
      ),
    );

    await fileWriter.write(
      path.join(paths.testSharedUi, 'splash_screen_test.dart'),
      SplashTemplates.splashScreenTestSource(
        projectName: projectName,
        backgroundColorHex: backgroundColorHex,
      ),
    );

    await _touchPubspec(paths);
  }

  Future<void> _touchPubspec(ProjectPaths paths) async {
    final pubspec = File(paths.pubspecFile);
    if (await pubspec.exists()) {
      await pubspec.setLastModified(DateTime.now());
    }
  }

  static String normalizeHex(String backgroundColor) {
    return backgroundColor.replaceFirst('#', '').toUpperCase();
  }
}
