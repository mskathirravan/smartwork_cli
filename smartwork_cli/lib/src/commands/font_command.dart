import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_core/smartwork_core.dart';

import 'font_prompt.dart';
import 'validation_report.dart';

typedef FontPromptReader = FontSelection Function();

class FontCommand extends Command {
  final String projectPath;
  final FontPromptReader _promptFont;
  final ProjectValidator _projectValidator;

  FontCommand({
    this.projectPath = '.',
    FontPromptReader? promptFont,
    ProjectValidator? projectValidator,
  })  : _promptFont = promptFont ?? FontPrompt().prompt,
        _projectValidator = projectValidator ?? ProjectValidator();

  @override
  final name = 'font';

  @override
  final description =
      'Add or update the custom/Google Font in the current project';

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

    final selection = _promptFont();
    final pubspecBefore = readPubspec(projectPath);
    try {
      await FontLifecycle().updateFont(
        projectPath: projectPath,
        fonts: selection.fonts,
      );
      final sampleWritten = await FontLifecycle().updateFontSample(
        projectPath: projectPath,
        includeSample: selection.includeHomeSample,
      );
      _reportSuccess(selection, sampleWritten);
      await resolveChangedDependencies(
          projectPath, pubspecBefore, _projectValidator);
    } on FontSourceFileNotFoundException catch (e) {
      print('❌ $e');
      exitCode = 1;
    }
  }

  void _reportSuccess(FontSelection selection, bool sampleWritten) {
    final fonts = selection.fonts;
    switch (fonts.type) {
      case FontType.none:
        print('✔ Font updated: none\n');
      case FontType.custom:
        print('✔ Font updated: ${fonts.custom!.family} (Custom Font)\n');
      case FontType.google:
        print('✔ Font updated: ${fonts.google!.family} (Google Font)\n');
    }
    print('lib/services/theme/app_theme.dart regenerated to use it.');
    if (sampleWritten && !selection.includeHomeSample) {
      print('\nℹ lib/shared/ui/font_sample.dart kept (updated for this font): '
          'your code still uses FontSample. Remove const FontSample() from '
          'it, then run "smartwork font" again to delete the sample.');
    } else if (sampleWritten) {
      print('\n✔ lib/shared/ui/font_sample.dart generated.');
      print('Add const FontSample() to your Home page to preview it — '
          "SmartWork never edits an existing project's Home page for you.");
    }
  }
}
