import '../models/project_config.dart';
import '../models/project_config_file.dart';
import '../models/splash_config.dart';
import '../paths/project_paths.dart';
import '../validator/config_validator.dart';
import 'project_generator.dart';
import 'splash_generator.dart';

class InvalidSplashConfigException implements Exception {
  final List<ValidationError> errors;

  InvalidSplashConfigException(this.errors);

  @override
  String toString() => errors.map((e) => e.toString()).join('; ');
}

class SplashAddResult {
  final String iconAssetPath;

  SplashAddResult({required this.iconAssetPath});
}

class SplashLifecycle {
  Future<SplashAddResult> addSplash({
    required String projectPath,
    required String backgroundColor,
    required String iconPath,
  }) async {
    final splash = SplashConfig(
      backgroundColor: backgroundColor,
      iconPath: iconPath,
    );
    final errors = ConfigValidator.validateSplash(splash);
    if (errors.isNotEmpty) {
      throw InvalidSplashConfigException(errors);
    }

    final config = await ProjectConfigFile(projectPath: projectPath).read();
    final paths = ProjectPaths(projectRoot: projectPath);

    await SplashGenerator().generate(
      splash: splash,
      projectName: config.projectName,
      paths: paths,
    );

    final updatedConfig = _withSplash(config, splash);
    await ProjectConfigFile(projectPath: projectPath).write(updatedConfig);

    await ProjectGenerator(outputPath: projectPath, config: updatedConfig)
        .regenerateSharedUiBarrel();

    return SplashAddResult(
      iconAssetPath: 'assets/icons/${_basename(iconPath)}',
    );
  }

  String _basename(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    return normalized.substring(normalized.lastIndexOf('/') + 1);
  }

  ProjectConfig _withSplash(ProjectConfig config, SplashConfig splash) {
    return config.copyWith(splash: splash);
  }
}
