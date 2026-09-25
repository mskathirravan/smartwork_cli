/// The Splash Screen added with `smartwork splash`.
class SplashConfig {
  /// The background color as 6 hex digits, without `#` (e.g. `2E7D32`).
  final String backgroundColor;

  /// The image centered on the background.
  final String iconPath;

  /// A Splash Screen; a leading `#` in [backgroundColor] is removed.
  SplashConfig({required String backgroundColor, required this.iconPath})
      : backgroundColor = backgroundColor.replaceFirst('#', '');

  /// Reads the Splash Screen from `.smartwork/project.yaml`.
  factory SplashConfig.fromYaml(Map<String, dynamic> yaml) {
    return SplashConfig(
      backgroundColor: yaml['backgroundColor'] as String,
      iconPath: yaml['iconPath'] as String,
    );
  }

  /// The Splash Screen as written to `.smartwork/project.yaml`.
  Map<String, dynamic> toYaml() => {
        'backgroundColor': backgroundColor,
        'iconPath': iconPath,
      };
}
