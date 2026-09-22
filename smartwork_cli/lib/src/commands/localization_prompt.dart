import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';

class LocalizationPrompt {
  LocalizationConfig prompt() {
    print('\nLocalization:');
    print('  1. No');
    print('  2. Yes');
    stdout.write('Select (1 or 2): ');
    final input = stdin.readLineSync()?.trim() ?? '';

    if (input != '2') {
      if (input != '1') {
        print('❌ Invalid selection. Using no localization by default.');
      }
      return LocalizationConfig.disabled();
    }

    final supportedLocales = _promptSupportedLocales();
    final defaultLocale = _promptDefaultLocale(supportedLocales);
    return LocalizationConfig.enabled(
      supportedLocales: supportedLocales,
      defaultLocale: defaultLocale,
    );
  }

  List<String> _promptSupportedLocales() {
    stdout.write('Supported locales (comma-separated, e.g. en,fr,de): ');
    final input = stdin.readLineSync() ?? '';
    try {
      return LocalizationSelection.parseSupportedLocales(input);
    } on InvalidLocaleSelectionException catch (e) {
      print('❌ $e');
      return _promptSupportedLocales();
    }
  }

  String _promptDefaultLocale(List<String> supportedLocales) {
    stdout.write('Default locale (one of: ${supportedLocales.join(', ')}): ');
    final input = stdin.readLineSync()?.trim() ?? '';
    try {
      return LocalizationSelection.validateDefaultLocale(
        input,
        supportedLocales,
      );
    } on InvalidLocaleSelectionException catch (e) {
      print('❌ $e');
      return _promptDefaultLocale(supportedLocales);
    }
  }
}
