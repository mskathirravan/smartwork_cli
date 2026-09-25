/// The App Icon set with `smartwork icon`.
class AppIconConfig {
  /// The square source image every platform's icons are generated from.
  final String sourcePath;

  /// An App Icon generated from [sourcePath].
  AppIconConfig({required this.sourcePath});

  /// Reads the App Icon from `.smartwork/project.yaml`.
  factory AppIconConfig.fromYaml(Map<String, dynamic> yaml) {
    return AppIconConfig(sourcePath: yaml['sourcePath'] as String);
  }

  /// The App Icon as written to `.smartwork/project.yaml`.
  Map<String, dynamic> toYaml() => {'sourcePath': sourcePath};
}
