import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_core/smartwork_core.dart';

class SplashCommand extends Command {
  final String projectPath;

  SplashCommand({this.projectPath = '.'}) {
    argParser
      ..addOption(
        'background',
        help: 'A 6-digit hex background color, e.g. "#2E7D32" or '
            '"2E7D32".',
        valueHelp: 'RRGGBB',
      )
      ..addOption(
        'icon',
        help: 'Path to a .png/.jpg/.jpeg image to center on the Splash '
            'background.',
        valueHelp: 'path/to/icon.png',
      );
  }

  @override
  final name = 'splash';

  @override
  final description =
      'Add or reconfigure the Splash Screen in the current project';

  @override
  String get invocation => 'smartwork splash --background <hex> --icon <path>';

  @override
  Future<void> run() async {
    final backgroundColor = argResults!['background'] as String?;
    final iconPath = argResults!['icon'] as String?;

    if (backgroundColor == null || iconPath == null) {
      print('❌ Usage: smartwork splash --background <hex> --icon <path>');
      exitCode = 1;
      return;
    }

    try {
      final result = await SplashLifecycle().addSplash(
        projectPath: projectPath,
        backgroundColor: backgroundColor,
        iconPath: iconPath,
      );
      _reportSuccess(result);
    } on FileSystemException {
      print('❌ No Smartwork project found in the current directory.');
      print('   Run "smartwork init" first.');
      exitCode = 1;
    } on InvalidSplashConfigException catch (e) {
      print('❌ $e');
      exitCode = 1;
    }
  }

  void _reportSuccess(SplashAddResult result) {
    print('✔ Splash Screen updated\n');
    print('Generated:');
    print('  • lib/shared/ui/splash_screen.dart');
    print('  • test/shared/ui/splash_screen_test.dart');
    print('  • ${result.iconAssetPath}\n');
    print('SplashScreen is exported from lib/shared/ui/shared_ui.dart — '
        'place it wherever your app needs an initial visual (it does '
        'not navigate anywhere on its own).');
  }
}
