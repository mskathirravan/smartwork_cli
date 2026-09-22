class AppIconConfig {
  final String sourcePath;

  AppIconConfig({required this.sourcePath});

  factory AppIconConfig.fromYaml(Map<String, dynamic> yaml) {
    return AppIconConfig(sourcePath: yaml['sourcePath'] as String);
  }

  Map<String, dynamic> toYaml() => {'sourcePath': sourcePath};
}
