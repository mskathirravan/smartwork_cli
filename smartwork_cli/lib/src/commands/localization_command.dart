import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_core/smartwork_core.dart';

import 'localization_prompt.dart';

typedef LocalizationPromptReader = LocalizationConfig Function();

class LocalizationCommand extends Command {
  final String projectPath;
  final LocalizationPromptReader _promptLocalization;

  LocalizationCommand({
    this.projectPath = '.',
    LocalizationPromptReader? promptLocalization,
  }) : _promptLocalization = promptLocalization ?? LocalizationPrompt().prompt;

  @override
  final name = 'localization';

  @override
  final description = 'Add or update localization in the current project';

  @override
  Future<void> run() async {
    try {
      await ProjectConfigFile(projectPath: projectPath).read();
    } on FileSystemException {
      print('❌ No Smartwork project found in the current directory.');
      print('   Run "smartwork init" first.');
      exitCode = 1;
      return;
    }

    final localization = _promptLocalization();
    await LocalizationLifecycle().updateLocalization(
      projectPath: projectPath,
      localization: localization,
    );
    _reportSuccess(localization);
  }

  void _reportSuccess(LocalizationConfig localization) {
    if (!localization.enabled) {
      print('✔ Localization updated: disabled\n');
      print('l10n.yaml removed; lib/l10n/ ARB files were preserved.');
      return;
    }

    print('✔ Localization updated: '
        '${localization.supportedLocales.join(', ')} '
        '(default: ${localization.defaultLocale})\n');
    print('l10n.yaml and lib/l10n/ ARB files generated; lib/main.dart '
        'rewired.');
  }
}
