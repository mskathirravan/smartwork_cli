import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';

import 'font_prompt.dart';
import 'localization_prompt.dart';

class CollectedConfiguration {
  final ProjectConfig config;
  final bool includeFontSample;

  CollectedConfiguration({
    required this.config,
    required this.includeFontSample,
  });
}

class ConfigurationPrompt {
  CollectedConfiguration collectAll() {
    final projectName = _promptProjectName();
    final appTargets = _promptAppTargets();
    final architecture = _promptArchitecture();
    final stateManagement = _promptStateManagement();
    final network = _promptNetwork();
    final storage = _promptStorage();
    final fontSelection = FontPrompt().prompt();
    final localization = LocalizationPrompt().prompt();
    final services = _promptServices().map((s) => s.id).toSet();
    final initialFeatures = _promptInitialFeatures();

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
    );
  }

  String _promptProjectName() {
    while (true) {
      stdout.write('Project name (e.g., my_app): ');
      final input = stdin.readLineSync()?.trim() ?? '';

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

  Set<AppTarget> _promptAppTargets() {
    print('\nApp Targets:\n');
    for (final target in AppTarget.values) {
      print('  ${target.index + 1}. ${target.displayName}');
    }
    while (true) {
      stdout.write('\nSelect one or more targets (e.g. 1,3,5): ');
      final input = stdin.readLineSync() ?? '';
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
    stdout.write('Select (1, 2, or 3): ');
    final input = stdin.readLineSync()?.trim() ?? '';

    switch (input) {
      case '1':
        return Architecture.cleanArchitecture;
      case '2':
        return Architecture.mvvm;
      case '3':
        return Architecture.mvp;
      default:
        print('❌ Invalid selection. Using Clean Architecture by default.');
        return Architecture.cleanArchitecture;
    }
  }

  StateManagement _promptStateManagement() {
    print('\nState Management:');
    print('  1. BLoC');
    print('  2. Cubit');
    print('  3. GetX');
    print('  4. Riverpod');
    stdout.write('Select (1, 2, 3, or 4): ');
    final input = stdin.readLineSync()?.trim() ?? '';

    switch (input) {
      case '1':
        return StateManagement.bloc;
      case '2':
        return StateManagement.cubit;
      case '3':
        return StateManagement.getx;
      case '4':
        return StateManagement.riverpod;
      default:
        print('❌ Invalid selection. Using BLoC by default.');
        return StateManagement.bloc;
    }
  }

  Network _promptNetwork() {
    print('\nNetwork:');
    print('  1. HTTP');
    print('  2. Dio');
    print('  3. Other (bring your own — SmartWork adds no dependency '
        'and generates no networking code)');
    stdout.write('Select (1, 2, or 3): ');
    final input = stdin.readLineSync()?.trim() ?? '';

    switch (input) {
      case '1':
        return Network.http;
      case '2':
        return Network.dio;
      case '3':
        return Network.other;
      default:
        print('❌ Invalid selection. Using HTTP by default.');
        return Network.http;
    }
  }

  Storage _promptStorage() {
    print('\nStorage:');
    print('  1. SharedPreferences');
    print('  2. Hive');
    print('  3. Other (bring your own — SmartWork adds no dependency '
        'and generates no persistence code)');
    stdout.write('Select (1, 2, or 3): ');
    final input = stdin.readLineSync()?.trim() ?? '';

    switch (input) {
      case '1':
        return Storage.sharedPreferences;
      case '2':
        return Storage.hive;
      case '3':
        return Storage.other;
      default:
        print('❌ Invalid selection. Using SharedPreferences by default.');
        return Storage.sharedPreferences;
    }
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

  List<String> _promptInitialFeatures() {
    print('\nInitial Features (comma-separated):');
    stdout.write('Feature names (e.g., home, profile, settings): ');
    final input = stdin.readLineSync()?.trim() ?? '';

    if (input.isEmpty) {
      print('❌ At least one feature is required');
      return _promptInitialFeatures();
    }

    final features = <String>[];
    for (final feature in input.split(',')) {
      final trimmed = feature.trim();
      if (trimmed.isNotEmpty) {
        if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(trimmed)) {
          print(
              '❌ Invalid feature name: $trimmed. Must start with a letter and contain only lowercase letters, numbers, and underscores');
          return _promptInitialFeatures();
        }
        features.add(trimmed);
      }
    }

    if (features.isEmpty) {
      print('❌ At least one feature is required');
      return _promptInitialFeatures();
    }

    return features;
  }
}
