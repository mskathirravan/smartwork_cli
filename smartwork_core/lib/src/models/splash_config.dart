class SplashConfig {
  final String backgroundColor;

  final String iconPath;

  SplashConfig({required String backgroundColor, required this.iconPath})
      : backgroundColor = backgroundColor.replaceFirst('#', '');

  factory SplashConfig.fromYaml(Map<String, dynamic> yaml) {
    return SplashConfig(
      backgroundColor: yaml['backgroundColor'] as String,
      iconPath: yaml['iconPath'] as String,
    );
  }

  Map<String, dynamic> toYaml() => {
        'backgroundColor': backgroundColor,
        'iconPath': iconPath,
      };
}
