import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/discover_command.dart';
import 'package:smartwork_cli/src/commands/doctor_command.dart';
import 'package:smartwork_cli/src/commands/feature_command.dart';
import 'package:smartwork_cli/src/commands/font_command.dart';
import 'package:smartwork_cli/src/commands/icon_command.dart';
import 'package:smartwork_cli/src/commands/init_command.dart';
import 'package:smartwork_cli/src/commands/localization_command.dart';
import 'package:smartwork_cli/src/commands/model_command.dart';
import 'package:smartwork_cli/src/commands/service_command.dart';
import 'package:smartwork_cli/src/commands/splash_command.dart';
import 'package:smartwork_cli/src/commands/target_command.dart';
import 'package:smartwork_cli/src/commands/test_command.dart';
import 'package:smartwork_cli/src/commands/update_command.dart';
import 'package:smartwork_cli/src/commands/version_command.dart';

void main(List<String> arguments) {
  final runner = CommandRunner(
    'smartwork',
    'Smartwork: Flutter project architecture generator',
  )
    ..addCommand(DiscoverCommand())
    ..addCommand(DoctorCommand())
    ..addCommand(FeatureCommand())
    ..addCommand(FontCommand())
    ..addCommand(IconCommand())
    ..addCommand(InitCommand())
    ..addCommand(LocalizationCommand())
    ..addCommand(ModelCommand())
    ..addCommand(ServiceCommand())
    ..addCommand(SplashCommand())
    ..addCommand(TargetCommand())
    ..addCommand(TestCommand())
    ..addCommand(UpdateCommand())
    ..addCommand(VersionCommand());

  runner.run(arguments).catchError((error) {
    if (error is! UsageException) throw error;
    print(error);
    exit(1);
  });
}
