/// Thrown for locale input that can't be parsed.
class InvalidLocaleSelectionException implements Exception {
  /// What was wrong with the input.
  final String message;

  /// An error described by [message].
  InvalidLocaleSelectionException(this.message);

  @override
  String toString() => message;
}

/// Parses the locale answers of the Localization prompts.
class LocalizationSelection {
  const LocalizationSelection._();

  static final _localePattern = RegExp(r'^[a-z]{2,3}(_[A-Z]{2})?$');

  /// Parses comma-separated locales such as `en,fr,pt_BR`, dropping
  /// duplicates. Throws [InvalidLocaleSelectionException] if none are given
  /// or one is malformed.
  static List<String> parseSupportedLocales(String input) {
    final locales = <String>[];
    for (final token in input.split(',')) {
      final trimmed = token.trim();
      if (trimmed.isEmpty) continue;
      if (!_localePattern.hasMatch(trimmed)) {
        throw InvalidLocaleSelectionException(
          'Invalid locale "$trimmed". Must look like "en", "en_US", or '
          '"pt_BR".',
        );
      }
      if (!locales.contains(trimmed)) locales.add(trimmed);
    }

    if (locales.isEmpty) {
      throw InvalidLocaleSelectionException(
        'At least one supported locale is required.',
      );
    }

    return locales;
  }

  /// Returns [candidate] if it is one of [supportedLocales]; otherwise
  /// throws [InvalidLocaleSelectionException].
  static String validateDefaultLocale(
    String candidate,
    List<String> supportedLocales,
  ) {
    if (supportedLocales.contains(candidate)) return candidate;
    throw InvalidLocaleSelectionException(
      'Default locale must be one of: ${supportedLocales.join(', ')}.',
    );
  }
}
