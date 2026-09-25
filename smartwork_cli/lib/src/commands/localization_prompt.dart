import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';

import 'choice_reader.dart';

class LocalizationPrompt {
  LocalizationConfig prompt() {
    print('\nLocalization:');
    print('  1. No');
    print('  2. Yes');
    final enabled = readChoice(
      'Select (1 or 2): ',
      [false, true],
      aliases: {'n': false, 'no': false, 'y': true, 'yes': true},
    );
    if (!enabled) return LocalizationConfig.disabled();

    final supportedLocales = _promptSupportedLocales();
    final defaultLocale = _promptDefaultLocale(supportedLocales);
    return LocalizationConfig.enabled(
      supportedLocales: supportedLocales,
      defaultLocale: defaultLocale,
    );
  }

  List<String> _promptSupportedLocales() {
    stdout.write('Supported locales (comma-separated, e.g. en,fr,de): ');
    final input = readLineOrThrow();
    try {
      return LocalizationSelection.parseSupportedLocales(input);
    } on InvalidLocaleSelectionException catch (e) {
      print('❌ $e');
      return _promptSupportedLocales();
    }
  }

  String _promptDefaultLocale(List<String> supportedLocales) {
    stdout.write('Default locale (one of: ${supportedLocales.join(', ')}): ');
    final input = readLineOrThrow().trim();
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
