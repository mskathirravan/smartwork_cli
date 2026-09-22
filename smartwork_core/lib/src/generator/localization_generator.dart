import 'dart:io';

import '../filesystem/file_writer.dart';
import '../models/localization_config.dart';
import '../paths/project_paths.dart';

class LocalizationGenerator {
  Future<void> generate({
    required String outputPath,
    required LocalizationConfig localization,
    required String projectName,
  }) async {
    final paths = ProjectPaths(projectRoot: outputPath);

    if (!localization.enabled) {
      final l10nConfig = File(paths.l10nConfigFile);
      if (await l10nConfig.exists()) await l10nConfig.delete();
      return;
    }

    await FileWriter().write(paths.l10nConfigFile, '''arb-dir: lib/l10n
template-arb-file: app_${localization.defaultLocale}.arb
output-localization-file: app_localizations.dart
''');

    for (final locale in localization.supportedLocales) {
      final arbFile = File(paths.l10nArbFile(locale));
      if (await arbFile.exists()) continue;
      await FileWriter().write(
        paths.l10nArbFile(locale),
        _arbBaseline(locale, projectName),
      );
    }
  }

  String _arbBaseline(String locale, String projectName) {
    return '''{
  "@@locale": "$locale",
  "appTitle": "$projectName",
  "@appTitle": {
    "description": "The application title"
  }
}
''';
  }
}
