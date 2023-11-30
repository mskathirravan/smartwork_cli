import 'package:cli_dialog/cli_dialog.dart';

import '../utils/log_utils.dart';
import '../utils/pubspec_utils.dart';
import 'app_layers/app_structure.dart';
import 'create_command.dart';
import 'operations/operations.dart';
import 'smartwork_command.dart';

import 'dart:io';

final folderName = 'lib';
String app_pattern = '';

class InitCommand extends SmartworkCommand {
  @override
  String get name => 'init';
  @override
  String get description =>
      'Generate folder structure on an existing project lib folder';

  @override
  Future<void> execute() async {
    print('Executing init command...');
    validateProjectStructure();
  }

  static void validateProjectStructure() async {
    final directoryPath = '${Directory.current.path}';
    if (Operations.folderExists(
        directoryPath: directoryPath, folderName: folderName)) {
      LogService.info(
          'Are you sure you want to overwrite the existing project lib folder? (yes/no)');
      String userInput = stdin.readLineSync() ?? '';
      if (userInput.toLowerCase() == 'yes' || userInput.toLowerCase() == 'y') {
        configAppStructure(directoryPath: directoryPath);
      } else {
        LogService.info('init canceled by user.');
        return;
      }
    } else {
      LogService.info('The project lib folder does not exist.');
      // configAppStructure(directoryPath: directoryPath);
    }
  }

  static void configAppStructure({required String directoryPath}) {
    // Check if the directory exists
    if (Operations.folderExists(
        directoryPath: directoryPath, folderName: folderName)) {
      Operations.deleteFolder(
          directoryPath: directoryPath, folderName: folderName);
    }
    String pattern = 'clean_architecture'; //chooseOptions();
    if (PubspecUtils.writePubspecFile(pattern)) {
      app_pattern = pattern;
      // Create the directory
      if (Operations.createFolder(
          directoryPath: directoryPath, folderName: folderName)) {
        if (AppStructure.createStructure(
            directoryPath: '$directoryPath/$folderName')) {
          final cc = CreateCommand();
          cc.createFeature('home');
          cc.createFeature('auth');
          cc.createFeature('debug');
          flutterCommand(directoryPath: directoryPath);
          LogService.success('Project structure created successfully.');
        } else {
          LogService.error('Failed to create project.');
        }
      } else {
        LogService.error('Failed to create directory $directoryPath.');
      }
    }
  }

  static void flutterCommand({required String directoryPath}) async {
    final commands = [
      'flutter pub add dio shared_preferences',
      'flutter pub add -d flutter_launcher_icons flutter_native_splash',
      'flutter pub get',
    ];

    for (final command in commands) {
      await runShellCommand(command);
    }
  }

  static Future<void> runShellCommand(String command) async {
    final process = await Process.start(
      'bash',
      ['-c', command],
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await process.exitCode;

    if (exitCode == 0) {
      print('$command completed successfully.');
    } else {
      print('Error: $command failed with exit code $exitCode');
      exit(1); // Stop further execution if any process fails
    }
  }

  static String chooseOptions() {
    const listQuestions = [
      [
        {
          'question': 'Choose your app pattern:',
          'options': [
            'clean_framework',
            'GetX',
            'clean_architecture',
          ]
        },
        'pattern'
      ]
    ];

    final dialog = CLI_Dialog(listQuestions: listQuestions);
    final answer = dialog.ask();
    return answer['pattern'];
  }
}
