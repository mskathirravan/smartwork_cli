/// A project's localization: disabled, or enabled with its locales.
class LocalizationConfig {
  /// Whether the app is localized (ARB files and `flutter gen-l10n`).
  final bool enabled;

  /// The locales the app supports, e.g. `['en', 'fr']`.
  final List<String> supportedLocales;

  /// The locale used when the device's locale isn't supported; null when
  /// disabled.
  final String? defaultLocale;

  LocalizationConfig._({
    required this.enabled,
    required this.supportedLocales,
    required this.defaultLocale,
  });

  /// No localization.
  LocalizationConfig.disabled()
      : this._(enabled: false, supportedLocales: const [], defaultLocale: null);

  /// Localization for [supportedLocales], falling back to [defaultLocale].
  LocalizationConfig.enabled({
    required List<String> supportedLocales,
    required String defaultLocale,
  }) : this._(
          enabled: true,
          supportedLocales: supportedLocales,
          defaultLocale: defaultLocale,
        );

  /// [supportedLocales] with [defaultLocale] first.
  List<String> get orderedLocales {
    if (!enabled || defaultLocale == null) return supportedLocales;
    return [
      defaultLocale!,
      ...supportedLocales.where((l) => l != defaultLocale),
    ];
  }

  /// Reads localization from `.smartwork/project.yaml`; null means
  /// disabled.
  factory LocalizationConfig.fromYaml(Map<String, dynamic>? yaml) {
    if (yaml == null || yaml['enabled'] != true) {
      return LocalizationConfig.disabled();
    }
    return LocalizationConfig.enabled(
      supportedLocales: List<String>.from(yaml['supportedLocales'] as List),
      defaultLocale: yaml['defaultLocale'] as String,
    );
  }

  /// Localization as written to `.smartwork/project.yaml`.
  Map<String, dynamic> toYaml() => {
        'enabled': enabled,
        'supportedLocales': supportedLocales,
        if (defaultLocale != null) 'defaultLocale': defaultLocale,
      };
}
