class LocalizationConfig {
  final bool enabled;
  final List<String> supportedLocales;

  final String? defaultLocale;

  LocalizationConfig._({
    required this.enabled,
    required this.supportedLocales,
    required this.defaultLocale,
  });

  LocalizationConfig.disabled()
      : this._(enabled: false, supportedLocales: const [], defaultLocale: null);

  LocalizationConfig.enabled({
    required List<String> supportedLocales,
    required String defaultLocale,
  }) : this._(
          enabled: true,
          supportedLocales: supportedLocales,
          defaultLocale: defaultLocale,
        );

  List<String> get orderedLocales {
    if (!enabled || defaultLocale == null) return supportedLocales;
    return [
      defaultLocale!,
      ...supportedLocales.where((l) => l != defaultLocale),
    ];
  }

  factory LocalizationConfig.fromYaml(Map<String, dynamic>? yaml) {
    if (yaml == null || yaml['enabled'] != true) {
      return LocalizationConfig.disabled();
    }
    return LocalizationConfig.enabled(
      supportedLocales: List<String>.from(yaml['supportedLocales'] as List),
      defaultLocale: yaml['defaultLocale'] as String,
    );
  }

  Map<String, dynamic> toYaml() => {
        'enabled': enabled,
        'supportedLocales': supportedLocales,
        if (defaultLocale != null) 'defaultLocale': defaultLocale,
      };
}
