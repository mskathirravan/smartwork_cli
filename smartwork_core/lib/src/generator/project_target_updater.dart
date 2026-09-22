import '../flutter/flutter_bootstrap.dart';
import '../models/project_config.dart';
import '../models/project_config_file.dart';
import '../models/target_change_plan.dart';
import '../validator/project_validator.dart';
import '../validator/target_state_detector.dart';
import 'project_generator.dart';

class TargetChangeResult {
  final TargetChangePlan plan;
  final Set<AppTarget> platformsCreated;
  final ProjectValidationResult validation;

  TargetChangeResult({
    required this.plan,
    required this.platformsCreated,
    required this.validation,
  });
}

class ProjectTargetUpdater {
  final TargetStateDetector _detector;
  final FlutterBootstrap _flutterBootstrap;
  final ProjectValidator _projectValidator;

  ProjectTargetUpdater({
    TargetStateDetector? detector,
    FlutterBootstrap? flutterBootstrap,
    ProjectValidator? projectValidator,
  })  : _detector = detector ?? TargetStateDetector(),
        _flutterBootstrap = flutterBootstrap ?? FlutterBootstrap(),
        _projectValidator = projectValidator ?? ProjectValidator();

  Future<TargetChangeResult> apply({
    required String projectPath,
    required ProjectConfig config,
    required Set<AppTarget> requestedTargets,
  }) async {
    final plan = TargetChangePlan.compute(
      current: config.appTargets,
      requested: requestedTargets,
    );

    final onDisk = _detector.existingPlatforms(projectPath);
    final trulyMissing = plan.added.where((t) => !onDisk.contains(t)).toSet();

    final generator = ProjectGenerator(
      outputPath: projectPath,
      config: _withAppTargets(config, requestedTargets),
    );

    if (trulyMissing.isNotEmpty) {
      await _flutterBootstrap.create(
        projectName: config.projectName,
        targetPath: projectPath,
        platforms: trulyMissing.map((t) => t.platformFolder).toSet(),
      );
      await generator.removeStaleFlutterWidgetTest();
    }

    final updatedConfig = _withAppTargets(config, requestedTargets);
    await ProjectConfigFile(projectPath: projectPath).write(updatedConfig);

    final validation = await _projectValidator.validate(
      projectPath,
      appTargets: updatedConfig.appTargets,
      localizationEnabled: updatedConfig.localization.enabled,
    );
    if (!validation.passed) {
      throw ProjectValidationFailedException(validation);
    }

    await generator.generateDocumentation();

    return TargetChangeResult(
      plan: plan,
      platformsCreated: trulyMissing,
      validation: validation,
    );
  }

  ProjectConfig _withAppTargets(
    ProjectConfig config,
    Set<AppTarget> appTargets,
  ) {
    return config.copyWith(appTargets: appTargets);
  }
}
