import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';

import 'choice_reader.dart';
import 'feature_recommendations.dart';
import 'font_prompt.dart';
import 'localization_prompt.dart';
import 'project_type.dart';

class CollectedConfiguration {
  final ProjectConfig config;
  final bool includeFontSample;

  /// Free-text project description, used only to seed the generated
  /// project's pubspec.yaml `description:` line.
  ///
  /// Not persisted to [ProjectConfig] or `.smartwork/project.yaml` — it
  /// never reaches SmartWork's own generation logic or templates.
  final String projectDescription;

  CollectedConfiguration({
    required this.config,
    required this.includeFontSample,
    required this.projectDescription,
  });
}

class ConfigurationPrompt {
  CollectedConfiguration collectAll() {
    final projectName = _promptProjectName();
    final projectDescription = _promptProjectDescription();
    final projectType = _promptProjectType();
    final appTargets = _promptAppTargets();
    final architecture = _promptArchitecture();
    final stateManagement = _promptStateManagement();
    final network = _promptNetwork();
    final storage = _promptStorage();
    final fontSelection = FontPrompt().prompt();
    final localization = LocalizationPrompt().prompt();
    final services = _promptServices().map((s) => s.id).toSet();
    final initialFeatures = _promptInitialFeatures(projectType);

    return CollectedConfiguration(
      config: ProjectConfig(
        projectName: projectName,
        appTargets: appTargets,
        architecture: architecture,
        stateManagement: stateManagement,
        network: network,
        storage: storage,
        fonts: fontSelection.fonts,
        localization: localization,
        services: services,
        initialFeatures: initialFeatures,
      ),
      includeFontSample: fontSelection.includeHomeSample,
      projectDescription: projectDescription,
    );
  }

  String _promptProjectName() {
    while (true) {
      stdout.write('Project name (e.g., my_app): ');
      final input = readLineOrThrow().trim();

      if (input.isEmpty) {
        print('❌ Project name cannot be empty');
        continue;
      }

      if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(input)) {
        print(
            '❌ Project name must start with a letter and contain only lowercase letters, numbers, and underscores');
        continue;
      }

      return input;
    }
  }

  String _promptProjectDescription() {
    stdout.write('Project description (optional, press Enter to skip): ');
    return stdin.readLineSync()?.trim() ?? '';
  }

  ProjectType _promptProjectType() {
    print('\nWhat type of project?\n');
    for (final type in ProjectType.values) {
      print('  ${type.index + 1}. ${type.displayName}');
    }
    return readChoice(
      '\nSelect (1-${ProjectType.values.length}): ',
      ProjectType.values,
    );
  }

  Set<AppTarget> _promptAppTargets() {
    print('\nApp Targets:\n');
    for (final target in AppTarget.values) {
      print('  ${target.index + 1}. ${target.displayName}');
    }
    while (true) {
      stdout.write('\nSelect one or more targets (e.g. 1,3,5): ');
      final input = readLineOrThrow();
      try {
        return AppTargetSelection.parse(input);
      } on InvalidAppTargetSelectionException catch (e) {
        print('❌ $e');
      }
    }
  }

  Architecture _promptArchitecture() {
    print('\nArchitecture:');
    print('  1. Clean Architecture');
    print('  2. MVVM');
    print('  3. MVP');
    return readChoice(
      'Select (1, 2, or 3): ',
      [Architecture.cleanArchitecture, Architecture.mvvm, Architecture.mvp],
    );
  }

  StateManagement _promptStateManagement() {
    print('\nState Management:');
    print('  1. BLoC');
    print('  2. Cubit');
    print('  3. GetX');
    print('  4. Riverpod');
    return readChoice(
      'Select (1, 2, 3, or 4): ',
      [
        StateManagement.bloc,
        StateManagement.cubit,
        StateManagement.getx,
        StateManagement.riverpod,
      ],
    );
  }

  Network _promptNetwork() {
    print('\nNetwork:');
    print('  1. HTTP');
    print('  2. Dio');
    print('  3. Other (bring your own — SmartWork adds no dependency '
        'and generates no networking code)');
    return readChoice(
      'Select (1, 2, or 3): ',
      [Network.http, Network.dio, Network.other],
    );
  }

  Storage _promptStorage() {
    print('\nStorage:');
    print('  1. SharedPreferences');
    print('  2. Hive');
    print('  3. Other (bring your own — SmartWork adds no dependency '
        'and generates no persistence code)');
    return readChoice(
      'Select (1, 2, or 3): ',
      [Storage.sharedPreferences, Storage.hive, Storage.other],
    );
  }

  Set<Service> _promptServices() {
    print('\nProduction Services:\n');
    for (final service in Service.values) {
      print('  ${service.index + 1}. ${service.displayName}');
    }
    print('');

    while (true) {
      stdout.write("Select services (comma-separated eg:1,2,3, 'all' for every "
          'service, Enter for none): ');
      final input = stdin.readLineSync() ?? '';
      try {
        return ServiceSelection.parse(input);
      } on InvalidServiceSelectionException catch (e) {
        print('❌ $e');
      }
    }
  }

  List<String> _promptInitialFeatures(ProjectType projectType) {
    final recommended = FeatureRecommendations.forType(projectType);

    if (recommended.isEmpty) {
      return _promptInitialFeaturesFreeText();
    }

    print('\nInitial Features:');
    print('\nRecommended for ${projectType.displayName}:\n');
    for (final feature in recommended) {
      print('  ✓ ${feature.label}');
    }
    stdout.write('\nUse these recommended features? (Y/n): ');
    final input = stdin.readLineSync()?.trim().toLowerCase() ?? '';

    if (input.isEmpty || input == 'y' || input == 'yes') {
      return recommended.map((feature) => feature.id).toList();
    }

    return _promptInitialFeaturesFreeText();
  }

  List<String> _promptInitialFeaturesFreeText() {
    print('\nInitial Features (comma-separated):');
    stdout.write('Feature names (e.g., home, profile, settings): ');
    final input = readLineOrThrow().trim();

    if (input.isEmpty) {
      print('❌ At least one feature is required');
      return _promptInitialFeaturesFreeText();
    }

    final features = <String>[];
    for (final feature in input.split(',')) {
      final trimmed = feature.trim();
      if (trimmed.isNotEmpty) {
        if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(trimmed)) {
          print(
              '❌ Invalid feature name: $trimmed. Must start with a letter and contain only lowercase letters, numbers, and underscores');
          return _promptInitialFeaturesFreeText();
        }
        features.add(trimmed);
      }
    }

    if (features.isEmpty) {
      print('❌ At least one feature is required');
      return _promptInitialFeaturesFreeText();
    }

    return features;
  }
}
