// library smartwork_cli;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'src/core/cli_commands/create_command.dart';
import 'src/core/cli_commands/delete_command.dart';
import 'src/core/cli_commands/generate_command.dart';
import 'src/core/cli_commands/init_command.dart';
import 'src/core/cli_commands/update_command.dart';
import 'src/core/utils/log_utils.dart';

abstract class SmartworkCli {
  static void execute(List<String> arguments) async {
    if (arguments.isEmpty) {
      helpInfo();
      return;
    }
    //  LogService.info('arguments: $arguments');
    var time = Stopwatch();
    final runner =
        CommandRunner('smartwork_cli', 'Description of smartwork_cli')
          ..addCommand(CreateCommand())
          ..addCommand(DeleteCommand())
          ..addCommand(GenerateCommand())
          ..addCommand(InitCommand())
          ..addCommand(UpdateCommand());

    if (arguments.contains('-v') || arguments.contains('--version')) {
      versionInfo();
      return;
    }
    if (arguments.contains('-h') ||
        arguments.contains('--help') ||
        arguments.contains('help')) {
      helpInfo();
      return;
    }
    time.start();
    runner.run(arguments);
    time.stop();
    LogService.info('Time: ${time.elapsed.inMilliseconds} Milliseconds');
  }

  static void helpInfo() {
    print('Smartwork CLI Help:');
    print('-------------------');
    print('Usage:');
    print('  dart run smartwork_cli <command> [options]');
    print('');
    print('Commands:');
    print(
        '  create --type project --name <name>                            Create a new Flutter project\n');
    print(
        '  init                                                           Generate folder structure in an existing project\n');
    print(
        '  create --type feature --name <name>                            Create a new feature in the project\n');
    print(
        '  delete --type feature --name <name>                            Delete a feature from the project\n');
    print(
        '  generate model --on <feature> --with <path>                    Generate a model class from JSON file\n');
    print(
        '  -v                                                             Print the current version\n');
    print(
        '  help                                                           Display this help message\n');
    print(
        '  update                                                         Check for updates and perform update\n');
    print(
        '''  update --feature <feature> --yaml <path/to/config.yaml>        Update a specific feature\n
                                                                 supported features: appicon, native_splash, app_details\n
                                                                 update configuration using YAML file \n''');
  }

  static void versionInfo() {
    final pubspecContent = File('pubspec.yaml').readAsStringSync();
    final versionMatch = RegExp(r'version: (.+)').firstMatch(pubspecContent);
    final version = versionMatch?.group(1) ?? 'Unknown';

    LogService.info('smartwork_cli version $version');
  }
}
