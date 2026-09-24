import '../flutter/flutter_bootstrap.dart';
import '../models/project_config.dart';
import '../validator/project_validator.dart';
import 'project_generator.dart';

class ProjectInitResult {
  final ProjectGenerationResult generation;
  final ProjectValidationResult validation;

  ProjectInitResult({required this.generation, required this.validation});
}

class ProjectInitializer {
  final FlutterBootstrap _flutterBootstrap;
  final ProjectValidator _projectValidator;

  ProjectInitializer({
    FlutterBootstrap? flutterBootstrap,
    ProjectValidator? projectValidator,
  })  : _flutterBootstrap = flutterBootstrap ?? FlutterBootstrap(),
        _projectValidator = projectValidator ?? ProjectValidator();

  Future<ProjectInitResult> initialize({
    required String projectPath,
    required ProjectConfig config,
    bool clearExisting = false,
    bool includeFontSample = false,
    String? projectDescription,
  }) async {
    await _flutterBootstrap.create(
      projectName: config.projectName,
      targetPath: projectPath,
      platforms: config.appTargets.map((t) => t.platformFolder).toSet(),
    );

    final generator = ProjectGenerator(
      outputPath: projectPath,
      config: config,
      includeFontSample: includeFontSample,
      projectDescription: projectDescription,
    );
    if (clearExisting) {
      await generator.clearGeneratedContent();
    }
    final generation = await generator.generate();

    final validation = await _projectValidator.validate(
      projectPath,
      appTargets: config.appTargets,
      localizationEnabled: config.localization.enabled,
    );
    if (!validation.passed) {
      throw ProjectValidationFailedException(validation);
    }

    await generator.generateDocumentation();

    return ProjectInitResult(generation: generation, validation: validation);
  }
}
