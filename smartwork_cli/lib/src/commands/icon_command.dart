import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_core/smartwork_core.dart';

class IconCommand extends Command {
  final String projectPath;

  IconCommand({this.projectPath = '.'}) {
    argParser.addOption(
      'source',
      help: 'Path to a square .png/.jpg/.jpeg image to use as the App '
          'Icon across Android, iOS, macOS, and Web.',
      valueHelp: 'path/to/icon.png',
    );
  }

  @override
  final name = 'icon';

  @override
  final description = 'Generate the App Icon (Android, iOS, macOS, Web) '
      'from a single square source image';

  @override
  String get invocation => 'smartwork icon --source <path>';

  @override
  Future<void> run() async {
    final sourcePath = argResults!['source'] as String?;

    if (sourcePath == null) {
      print('❌ Usage: $invocation');
      exitCode = 1;
      return;
    }

    try {
      final result = await AppIconLifecycle().setAppIcon(
        projectPath: projectPath,
        sourcePath: sourcePath,
      );
      _reportSuccess(result);
    } on FileSystemException {
      print('❌ No Smartwork project found in the current directory.');
      print('   Run "smartwork init" first.');
      exitCode = 1;
    } on InvalidAppIconConfigException catch (e) {
      print('❌ $e');
      exitCode = 1;
    } on AppIconTransparencyException catch (e) {
      print('❌ $e');
      exitCode = 1;
    } on NoSupportedPlatformFoundException catch (e) {
      print('❌ $e');
      exitCode = 1;
    }
  }

  void _reportSuccess(AppIconResult result) {
    print('✔ App Icon generated\n');
    print('Generated:');
    for (final file in result.generatedFiles) {
      print('  • $file');
    }
  }
}
