import '../../models/project_knowledge.dart';
import 'project_scan_result.dart';

class DependencyAnalyzer {
  DiscoveredValue<List<DependencyInfo>> analyze(ProjectScanResult scan) {
    final yaml = scan.pubspecYaml;
    if (yaml == null) {
      return const DiscoveredValue(
        [],
        confidence: DiscoveryConfidence.unknown,
        evidence: ['pubspec.yaml not found or could not be parsed'],
      );
    }

    final dependencies = <DependencyInfo>[
      ..._entriesFrom(yaml['dependencies'], isDev: false),
      ..._entriesFrom(yaml['dev_dependencies'], isDev: true),
    ];

    return DiscoveredValue(
      dependencies,
      confidence: DiscoveryConfidence.declared,
      evidence: [
        for (final dep in dependencies)
          'pubspec.yaml: ${dep.name} ${dep.versionConstraint}',
      ],
    );
  }

  List<DependencyInfo> _entriesFrom(dynamic section, {required bool isDev}) {
    if (section is! Map) return const [];
    return [
      for (final entry in section.entries)
        DependencyInfo(
          name: entry.key.toString(),
          versionConstraint: _constraintString(entry.value),
          isDev: isDev,
        ),
    ];
  }

  String _constraintString(dynamic value) {
    if (value == null) return 'any';
    if (value is String) return value;
    return value.toString();
  }
}
