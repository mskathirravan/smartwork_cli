class ProjectScanResult {
  final String projectPath;

  final Map<String, dynamic>? pubspecYaml;

  final Map<String, String> dartFiles;

  ProjectScanResult({
    required this.projectPath,
    required this.pubspecYaml,
    required this.dartFiles,
  });

  Set<String> get featureFolderNames {
    const prefix = 'lib/features/';
    final names = <String>{};
    for (final path in dartFiles.keys) {
      if (!path.startsWith(prefix)) continue;
      final rest = path.substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash > 0) names.add(rest.substring(0, slash));
    }
    return names;
  }

  Iterable<String> filesUnderFeature(String featureName) =>
      dartFiles.keys.where((p) => p.startsWith('lib/features/$featureName/'));

  bool hasTestsForFeature(String featureName) =>
      dartFiles.keys.any((p) => p.startsWith('test/features/$featureName/'));
}
