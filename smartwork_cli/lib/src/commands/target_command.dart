import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_core/smartwork_core.dart';

import 'confirmation_reader.dart';
import 'target_selection_reader.dart';
import 'validation_report.dart';

class TargetCommand extends Command {
  final String projectPath;

  final TargetStateDetector _detector;
  final ConfirmationReader _confirmationReader;
  final TargetSelectionReader _selectionReader;
  final FlutterBootstrap _flutterBootstrap;
  final ProjectValidator _projectValidator;

  TargetCommand({
    this.projectPath = '.',
    TargetStateDetector? detector,
    ConfirmationReader confirmationReader = readConfirmationFromStdin,
    TargetSelectionReader selectionReader = readTargetSelectionFromStdin,
    FlutterBootstrap? flutterBootstrap,
    ProjectValidator? projectValidator,
  })  : _detector = detector ?? TargetStateDetector(),
        _confirmationReader = confirmationReader,
        _selectionReader = selectionReader,
        _flutterBootstrap = flutterBootstrap ?? FlutterBootstrap(),
        _projectValidator = projectValidator ?? ProjectValidator();

  @override
  final name = 'target';

  @override
  final description = "Change an existing SmartWork project's App "
      'Targets (platforms)';

  @override
  Future<void> run() async {
    final detection = await _detector.detect(projectPath);

    if (detection.state != TargetProjectState.smartworkProject) {
      _printNotASmartworkProject();
      exitCode = 1;
      return;
    }

    final config = detection.existingConfig!;
    _printCurrentTargets(config.orderedAppTargets);
    _printAvailableTargets();
    final requested = _promptNewTargets();

    try {
      await applyTargetChange(config: config, requestedTargets: requested);
    } on FlutterBootstrapException catch (e) {
      print('❌ $e\n');
      print('App Targets were not fully applied.');
      exitCode = 1;
    } on ProjectValidationFailedException {
      exitCode = 1;
    }
  }

  void _printNotASmartworkProject() {
    print('✗ This is not a SmartWork-generated project.\n');
    print('smartwork target can only modify App Targets');
    print('for an existing SmartWork project.');
  }

  void _printCurrentTargets(List<AppTarget> current) {
    print('\nCurrent App Targets:\n');
    for (final target in current) {
      print('  ✓ ${target.displayName}');
    }
  }

  void _printAvailableTargets() {
    print('\nAvailable App Targets:\n');
    for (final target in AppTarget.values) {
      print('  ${target.index + 1}. ${target.displayName}');
    }
  }

  Set<AppTarget> _promptNewTargets() {
    while (true) {
      final input =
          _selectionReader('\nSelect one or more targets (e.g. 1,3,5): ');
      try {
        return AppTargetSelection.parse(input);
      } on InvalidAppTargetSelectionException catch (e) {
        print('❌ $e');
      }
    }
  }

  Future<void> applyTargetChange({
    required ProjectConfig config,
    required Set<AppTarget> requestedTargets,
  }) async {
    final plan = TargetChangePlan.compute(
      current: config.appTargets,
      requested: requestedTargets,
    );

    _printPlan(plan);

    final confirmed = _confirmationReader('Continue? [y/N]: ');
    if (!confirmed) {
      print('\nOperation cancelled.');
      print('No changes were made.');
      return;
    }

    final updater = ProjectTargetUpdater(
      detector: _detector,
      flutterBootstrap: _flutterBootstrap,
      projectValidator: _projectValidator,
    );

    TargetChangeResult? result;
    ProjectValidationFailedException? failure;
    try {
      result = await updater.apply(
        projectPath: projectPath,
        config: config,
        requestedTargets: requestedTargets,
      );
    } on ProjectValidationFailedException catch (e) {
      failure = e;
    }

    final platformsCreated = result?.platformsCreated ?? const {};
    if (platformsCreated.isNotEmpty) {
      final orderedMissing =
          AppTarget.values.where(platformsCreated.contains).toList();
      print('\n✔ Platform(s) created: '
          '${orderedMissing.map((t) => t.displayName).join(', ')}');
    }

    final alreadyPresent = plan.added.difference(platformsCreated);
    if (alreadyPresent.isNotEmpty) {
      final orderedPresent =
          AppTarget.values.where(alreadyPresent.contains).toList();
      print('\nℹ Platform(s) already present, not recreated: '
          '${orderedPresent.map((t) => t.displayName).join(', ')}');
    }

    print('✔ Configuration updated');

    print('\nSmartWork Project Validation\n');
    final phases = (result?.validation.phases ?? failure!.result.phases);
    printValidationPhases(phases);
    print('');

    if (failure != null) {
      print('Project documentation was not updated because validation '
          'failed.');
      throw failure;
    }

    print('Validation successful.');
    print('Updating project documentation...');
    print('✓ README.md');
  }

  void _printPlan(TargetChangePlan plan) {
    print('\nPlanned changes:\n');
    print('  Add:');
    if (plan.added.isEmpty) {
      print('    None');
    } else {
      for (final target in plan.orderedAdded) {
        print('    ✓ ${target.displayName}');
      }
    }
    print('');
    print('  Remove from SmartWork configuration:');
    if (plan.removedFromConfig.isEmpty) {
      print('    None');
    } else {
      for (final target in plan.orderedRemovedFromConfig) {
        print('    ${target.displayName}');
      }
    }
    print('');
    print('  Existing platform directories will be preserved.');
  }
}
