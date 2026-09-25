import '../filesystem/file_writer.dart';
import '../flutter/flutter_bootstrap.dart';
import '../models/project_config.dart';
import '../validator/project_validator.dart';
import 'project_generator.dart';

/// The outcome of a successful [ProjectInitializer.initialize].
class ProjectInitResult {
  /// What was generated (file, directory and feature counts).
  final ProjectGenerationResult generation;

  /// The validation run on the generated project; it passed.
  final ProjectValidationResult validation;

  /// A result of [generation] and [validation].
  ProjectInitResult({required this.generation, required this.validation});
}

/// Creates a new SmartWork project, exactly like `smartwork init`:
/// `flutter create`, SmartWork's generation, formatting, validation, then
/// the project documentation.
class ProjectInitializer {
  final FlutterBootstrap _flutterBootstrap;
  final ProjectValidator _projectValidator;

  /// An initializer; [flutterBootstrap] and [projectValidator] can be
  /// replaced (e.g. with fakes in tests).
  ProjectInitializer({
    FlutterBootstrap? flutterBootstrap,
    ProjectValidator? projectValidator,
  })  : _flutterBootstrap = flutterBootstrap ?? FlutterBootstrap(),
        _projectValidator = projectValidator ?? ProjectValidator();

  /// Creates the project described by [config] in [projectPath].
  ///
  /// Throws [FlutterBootstrapException] if `flutter create` fails, and
  /// [ProjectValidationFailedException] if validation fails (then no
  /// documentation is generated). [clearExisting] regenerates an existing
  /// SmartWork project; [includeFontSample] adds the font sample to Home;
  /// [projectDescription] sets the pubspec description.
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
    late final ProjectGenerationResult generation;
    final written = await FileWriter.recordDartWrites(() async {
      generation = await generator.generate();
    });
    await _projectValidator.formatDartFiles(projectPath, written);

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
