import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_core/smartwork_core.dart';

import 'confirmation_reader.dart';
import 'configuration_display.dart';
import 'configuration_prompt.dart';
import 'init_safety_check.dart';
import 'validation_report.dart';

class InitCommand extends Command {
  final String projectPath;

  final FlutterBootstrap _flutterBootstrap;
  final ProjectValidator _projectValidator;
  final InitSafetyCheck _initSafetyCheck;
  final ConfirmationReader _confirmationReader;

  InitCommand({
    this.projectPath = '.',
    FlutterBootstrap? flutterBootstrap,
    ProjectValidator? projectValidator,
    InitSafetyCheck? initSafetyCheck,
    ConfirmationReader confirmationReader = readConfirmationFromStdin,
  })  : _flutterBootstrap = flutterBootstrap ?? FlutterBootstrap(),
        _projectValidator = projectValidator ?? ProjectValidator(),
        _initSafetyCheck = initSafetyCheck ?? InitSafetyCheck(),
        _confirmationReader = confirmationReader;

  @override
  final name = 'init';

  @override
  final description = 'Initialize a new Smartwork project '
      '(requires the Flutter CLI on PATH)';

  @override
  Future<void> run() async {
    print('\n🚀 Smartwork Project Initialization\n');

    try {
      final safety = await _initSafetyCheck.check(projectPath);
      final collected = ConfigurationPrompt().collectAll();

      await checkSafetyAndGenerate(
        collected.config,
        includeFontSample: collected.includeFontSample,
        projectDescription: collected.projectDescription,
        safety: safety,
      );
    } on FlutterBootstrapException catch (e) {
      print('❌ $e\n');
      print('No SmartWork files were generated.');
      exit(1);
    } on FeatureAlreadyExistsException catch (e) {
      print('✖ Cannot initialize: feature "${e.featureName}" already '
          'exists in this directory.\n');
      print('No files were modified.\n');
      print('Remove or rename the existing lib/features/${e.featureName} '
          'directory, or run smartwork init in an empty directory.');
      exit(1);
    } on ProjectValidationFailedException {
      exit(1);
    } catch (e) {
      print('❌ Initialization cancelled: $e');
      exit(1);
    }
  }

  Future<void> checkSafetyAndGenerate(
    ProjectConfig config, {
    bool includeFontSample = false,
    String? projectDescription,
    InitSafetyCheckResult? safety,
  }) async {
    safety ??= await _initSafetyCheck.check(projectPath);

    ConfigurationDisplay().displaySummary(config);
    if (safety.existingConfig != null) {
      ConfigurationDisplay()
          .displayAppTargetsDiff(safety.existingConfig!, config);
      ConfigurationDisplay().displayServiceChanges(ServiceChanges.compute(
        current: safety.existingConfig!.services,
        desired: config.services,
      ));
    }

    final confirmed = _confirmationReader('Continue? [y/N]: ');
    if (!confirmed) {
      print('\nOperation cancelled.');
      print('No files were changed.');
      return;
    }

    await generateProject(
      config,
      clearExisting: safety.isRegeneration,
      includeFontSample: includeFontSample,
      projectDescription: projectDescription,
    );
  }

  Future<void> generateProject(
    ProjectConfig config, {
    bool clearExisting = false,
    bool includeFontSample = false,
    String? projectDescription,
  }) async {
    final stopwatch = Stopwatch()..start();
    print('\n🚀 Bootstrapping Flutter project...');

    final initializer = ProjectInitializer(
      flutterBootstrap: _flutterBootstrap,
      projectValidator: _projectValidator,
    );

    ProjectInitResult? result;
    ProjectValidationFailedException? failure;
    try {
      result = await initializer.initialize(
        projectPath: projectPath,
        config: config,
        clearExisting: clearExisting,
        includeFontSample: includeFontSample,
        projectDescription: projectDescription,
      );
    } on ProjectValidationFailedException catch (e) {
      failure = e;
    }

    print('✔ Flutter project created');
    print('\n📝 Generating project...');
    print('✔ Project configuration created');
    print('✔ pubspec.yaml updated with SmartWork dependencies');
    print('✔ Architecture: ${configLabel(config.architecture)}');
    print('✔ State management: ${configLabel(config.stateManagement)}');
    if (includeFontSample) {
      print('✔ Font sample: lib/shared/ui/font_sample.dart added to Home.');
    }
    if (result != null) {
      print('\nGenerated:');
      print('  • ${result.generation.fileCount} files');
      print('  • ${result.generation.directoryCount} directories');
      print('  • ${result.generation.featureCount} features');
    }

    print('\nSmartWork Project Validation\n');
    printValidationPhases(result?.validation.phases ?? failure!.result.phases);
    print('');

    if (failure != null) {
      print('Project documentation was not generated because validation '
          'failed.');
      throw failure;
    }

    print('Validation successful.');
    print('Generating project documentation...');
    print('✓ README.md');

    stopwatch.stop();
    print('\nDone in ${_formatElapsed(stopwatch.elapsed)}.');

    print('\nNext:');
    print('  smartwork feature <name>');
  }

  String _formatElapsed(Duration elapsed) {
    if (elapsed.inMinutes < 1) {
      return '${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s';
    }
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
}
