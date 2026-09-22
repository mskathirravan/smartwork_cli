import '../../models/project_knowledge.dart';
import 'project_scan_result.dart';

const _knownTestingPackages = {
  'flutter_test',
  'test',
  'mocktail',
  'mockito',
  'bloc_test',
};

final _testCall = RegExp(r'\btest\s*\(');
final _testWidgetsCall = RegExp(r'\btestWidgets\s*\(');
final _groupCall = RegExp(r'\bgroup\s*\(');

class TestAnalyzer {
  DiscoveredValue<TestKnowledge> analyze(ProjectScanResult scan) {
    final hasTestDirectory =
        scan.dartFiles.keys.any((p) => p.startsWith('test/'));

    final declaredTestingPackages = _declaredTestingPackages(scan.pubspecYaml);

    final hasDetectedTestCalls = scan.dartFiles.entries
        .where((e) => e.key.startsWith('test/'))
        .any((e) =>
            _testCall.hasMatch(e.value) ||
            _testWidgetsCall.hasMatch(e.value) ||
            _groupCall.hasMatch(e.value));

    final features = scan.featureFolderNames;
    final mirrorsFeatureStructure = features.isNotEmpty &&
        features.every((name) => scan.hasTestsForFeature(name));

    final knowledge = TestKnowledge(
      hasTestDirectory: hasTestDirectory,
      mirrorsFeatureStructure: mirrorsFeatureStructure,
      declaredTestingPackages: declaredTestingPackages,
      hasDetectedTestCalls: hasDetectedTestCalls,
    );

    if (!hasTestDirectory && declaredTestingPackages.isEmpty) {
      return DiscoveredValue(
        knowledge,
        confidence: DiscoveryConfidence.unknown,
        evidence: const ['No test/ directory and no testing dependency found'],
      );
    }

    final evidence = <String>[
      for (final package in declaredTestingPackages)
        'pubspec.yaml: $package declared',
      if (hasDetectedTestCalls)
        'test/: real test()/testWidgets()/group() calls found',
      if (mirrorsFeatureStructure)
        'test/features/ mirrors lib/features/ for every feature',
    ];

    return DiscoveredValue(
      knowledge,
      confidence: hasDetectedTestCalls
          ? DiscoveryConfidence.detected
          : DiscoveryConfidence.declared,
      evidence: evidence,
    );
  }

  List<String> _declaredTestingPackages(Map<String, dynamic>? yaml) {
    if (yaml == null) return const [];
    final names = <String>{};
    for (final section in [yaml['dependencies'], yaml['dev_dependencies']]) {
      if (section is Map) {
        names.addAll(section.keys.map((k) => k.toString()));
      }
    }
    return _knownTestingPackages.where(names.contains).toList();
  }
}
