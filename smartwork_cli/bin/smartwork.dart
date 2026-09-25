import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/choice_reader.dart';
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
import 'package:smartwork_cli/src/update_notifier.dart';
import 'package:smartwork_cli/src/version.dart';
import 'package:smartwork_core/smartwork_core.dart';

Future<void> main(List<String> arguments) async {
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

  // Checked alongside the command (usually from a cached answer) so it
  // never slows it down; only shown to a person at a terminal.
  final command = arguments.where((a) => !a.startsWith('-')).firstOrNull;
  final showUpdateNotice = stderr.hasTerminal && command != 'update';
  final updateNotice = showUpdateNotice
      ? UpdateNotifier(
          currentVersion:
              readSmartworkCliVersion() ?? fallbackSmartworkCliVersion,
        ).check().timeout(const Duration(seconds: 3), onTimeout: () => null)
      : Future<String?>.value();

  // Every Dart file a command generates is run through `dart format`, so
  // generated code stays formatter-clean whatever the feature/model names.
  final written = await FileWriter.recordDartWrites(() async {
    try {
      await runner.run(arguments);
    } on UsageException catch (error) {
      print(error);
      exitCode = 1;
    } on InputClosedException catch (error) {
      print('\n❌ $error');
      exitCode = 1;
    }
  });
  await ProjectValidator().formatDartFiles(Directory.current.path, written);

  final notice = await updateNotice;
  if (notice != null) {
    stderr.writeln('\n⚠ $notice');
  }
}
