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
      await _deleteGeneratedLocalizations(paths);
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

  /// Deletes the Dart files `flutter gen-l10n` generated from the ARB files
  /// (`app_localizations.dart`, `app_localizations_<locale>.dart`). They
  /// import flutter_localizations and intl, which disabling localization
  /// removes, so leaving them would break the build; `flutter gen-l10n`
  /// recreates them if localization is enabled again. ARB files are kept.
  Future<void> _deleteGeneratedLocalizations(ProjectPaths paths) async {
    final l10nDir = File(paths.l10nArbFile('en')).parent;
    if (!await l10nDir.exists()) return;
    final generated = RegExp(r'^app_localizations(_[A-Za-z_]+)?\.dart$');
    await for (final entity in l10nDir.list()) {
      final name = entity.uri.pathSegments.last;
      if (entity is File && generated.hasMatch(name)) await entity.delete();
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
