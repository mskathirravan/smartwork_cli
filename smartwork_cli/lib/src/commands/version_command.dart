import 'dart:io';

import 'package:args/command_runner.dart';

import '../version.dart';

class VersionCommand extends Command {
  final String? Function() _readVersion;

  VersionCommand({String? Function()? readVersion})
      : _readVersion = readVersion ?? readSmartworkCliVersion;

  @override
  final name = 'version';

  @override
  final description = 'Print the installed SmartWork CLI version';

  @override
  void run() {
    final version = _readVersion();
    if (version == null) {
      print(
        'smartwork: version unknown (could not locate smartwork_cli\'s '
        'own pubspec.yaml)',
      );
      exitCode = 1;
      return;
    }
    print('smartwork $version');
  }
}
