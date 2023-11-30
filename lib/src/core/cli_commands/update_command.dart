import 'dart:io';
import 'package:yaml/yaml.dart';

import '../utils/log_utils.dart';
import 'update_checker/update_checker.dart';
import 'smartwork_command.dart';

class UpdateCommand extends SmartworkCommand {
  UpdateCommand() {
    argParser
      ..addOption('feature', help: 'Specify the feature to update')
      ..addOption('iconPath', help: 'Specify the path to the new app icon')
      ..addOption('yaml',
          help: 'Specify the path to the YAML file for updates');
  }

  @override
  String get name => 'update';
  @override
  String get description => 'Check for updates or update specific features';

  @override
  Future<void> execute() async {
    final feature = argResults!['feature'] as String?;
    final yamlPath = argResults!['yaml'] as String?;

    if (feature != null) {
      if (feature == 'appicon') {
        await updateAppIcon(yamlPath);
      } else if (feature == 'native_splash') {
        await updateNativeSplash(yamlPath);
      } else if (feature == 'app_details') {
        await updateAppDetails(yamlPath);
      } else {
        print('Invalid feature: $feature');
      }
    } else {
      UpdateChecker.checkForUpdates();
    }
  }

  Future<void> updateAppIcon(String? yamlPath) async {
    if (yamlPath != null) {
      await updateFromYaml(yamlPath, 'app icon');
    } else {
      LogService.info('Please provide a YAML file path using --yaml');
    }
  }

  Future<void> updateNativeSplash(String? yamlPath) async {
    if (yamlPath != null) {
      await updateFromYaml(yamlPath, 'native splash');
    } else {
      LogService.info('Please provide a YAML file path using --yaml');
    }
  }

  Future<void> updateAppDetails(String? yamlPath) async {
    if (yamlPath != null) {
      await updateFromYaml(yamlPath, 'app details');
    } else {
      LogService.info('Please provide a YAML file path using --yaml');
    }
  }

  Future<void> updateFromYaml(String yamlPath, String featureName) async {
    final yamlFile = File(yamlPath);

    if (!yamlFile.existsSync()) {
      LogService.info('YAML file not found: $yamlPath');
      return;
    }

    try {
      final yamlContent = await yamlFile.readAsString();
      print('YAML Content:');
      print(yamlContent);

      final yamlMap = loadYaml(yamlContent);
      print('\nParsed YAML Map:');
      print(yamlMap);
      // Access specific values from the YAML map
      print('\nAccessing Values:');
      print('Android Icon: ${yamlMap['flutter_launcher_icons']['android']}');
      print('iOS Icon: ${yamlMap['flutter_launcher_icons']['ios']}');
      print(
          'Web Background Color: ${yamlMap['flutter_launcher_icons']['web']['background_color']}');

      // Use the yamlMap to update native splash or app details configuration
      // Add your implementation based on the featureName

      switch (featureName) {
        case 'native splash':
          final process = await Process.start(
            'flutter',
            ['pub', 'get'],
            mode: ProcessStartMode.inheritStdio,
          );
          processExecution(process);
          break;
        case 'app details':
          final process = await Process.start(
            'flutter',
            ['pub', 'get'],
            mode: ProcessStartMode.inheritStdio,
          );
          processExecution(process);
          break;
        case 'app icon':
          final process = await Process.start(
            'flutter',
            ['pub', 'get'],
            mode: ProcessStartMode.inheritStdio,
          );
          processExecution(process);
          break;
        default:
          break;
      }

      LogService.info('$featureName updated successfully.');
    } catch (e) {
      LogService.info('Failed to read or parse YAML file. Error: $e');
    }
  }

  void processExecution(Process processCli) async {
    final exitCode = await processCli.exitCode;
    if (exitCode == 0) {
      LogService.success('cmd executed successfully');
    } else {
      LogService.error('cmd executed failed');
    }
  }
}
