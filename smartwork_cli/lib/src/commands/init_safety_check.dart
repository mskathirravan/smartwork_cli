import 'package:smartwork_core/smartwork_core.dart';

class InitSafetyCheckResult {
  final TargetProjectState state;
  final ProjectConfig? existingConfig;
  final Set<AppTarget> existingPlatforms;
  final bool isRegeneration;

  InitSafetyCheckResult({
    required this.state,
    required this.existingConfig,
    required this.existingPlatforms,
    required this.isRegeneration,
  });
}

class InitSafetyCheck {
  final TargetStateDetector _detector;

  InitSafetyCheck({TargetStateDetector? detector})
      : _detector = detector ?? TargetStateDetector();

  Future<InitSafetyCheckResult> check(String projectPath) async {
    final result = await _detector.detect(projectPath);

    switch (result.state) {
      case TargetProjectState.empty:
        break;

      case TargetProjectState.nonFlutterProject:
        print('Existing files were found in the target directory.\n');
        print('SmartWork will generate a new Flutter project and may '
            'overwrite existing files.\n');

      case TargetProjectState.flutterProject:
        print('Existing Flutter project detected.\n');
        if (result.existingPlatforms.isNotEmpty) {
          print('Existing platforms:');
          for (final target
              in AppTarget.values.where(result.existingPlatforms.contains)) {
            print('  ✓ ${target.displayName}');
          }
          print('');
        }
        print('SmartWork will apply its architecture on top of this '
            'project. Existing platform folders are preserved — only '
            'platforms you additionally select below are generated; '
            'lib/ and test/ content SmartWork owns will be '
            'regenerated.\n');

      case TargetProjectState.smartworkProject:
        print('SmartWork project detected.\n');
        print('Current configuration:\n');
        _printConfig(result.existingConfig!);
        print('');

      case TargetProjectState.malformedSmartworkProject:
        print('SmartWork project metadata was found but could not be '
            'read.\n');
        print('Error: ${result.detectionError}\n');
        print('This project will not be modified automatically.\n');
    }

    return InitSafetyCheckResult(
      state: result.state,
      existingConfig: result.existingConfig,
      existingPlatforms: result.existingPlatforms,
      isRegeneration: result.state != TargetProjectState.empty,
    );
  }

  void _printConfig(ProjectConfig config) {
    print('  Project:           ${config.projectName}');
    print('  App targets:       '
        '${config.orderedAppTargets.map((t) => t.displayName).join(', ')}');
    print('  Architecture:      ${_formatEnumName(config.architecture.name)}');
    print('  State management:  '
        '${_formatEnumName(config.stateManagement.name)}');
    print('  Network:           ${_formatEnumName(config.network.name)}');
    print('  Storage:           ${_formatEnumName(config.storage.name)}');
    print('  Home feature:      ${config.homeFeatureName}');
    print('');
    print('  Current Services:');
    if (config.orderedServices.isEmpty) {
      print('    None');
    } else {
      for (final service in config.orderedServices) {
        print('    ✓ ${service.displayName}');
      }
    }
  }

  String _formatEnumName(String name) {
    return name
        .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'), (m) => '${m.group(1)} ${m.group(2)}')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
