import '../../models/feature_config.dart';
import '../../models/project_knowledge.dart';
import 'project_scan_result.dart';

class FeatureAnalyzer {
  DiscoveredValue<List<FeatureKnowledge>> analyze(ProjectScanResult scan) {
    final featureNames = scan.featureFolderNames.toList()..sort();
    if (featureNames.isNotEmpty) {
      final features = [
        for (final name in featureNames) _classify(scan, name, 'features'),
      ];
      return DiscoveredValue(
        features,
        confidence: DiscoveryConfidence.detected,
        evidence: [
          'lib/features/<name>/ convention found (${featureNames.length} feature(s))',
        ],
      );
    }

    final moduleNames = _moduleFolderNames(scan).toList()..sort();
    if (moduleNames.isNotEmpty) {
      final features = [
        for (final name in moduleNames) _classify(scan, name, 'modules'),
      ];
      return DiscoveredValue(
        features,
        confidence: DiscoveryConfidence.inferred,
        evidence: [
          'lib/modules/<name>/ fallback convention found (${moduleNames.length} module(s)) — a less-established convention than lib/features/, reported at lower confidence',
        ],
      );
    }

    return const DiscoveredValue(
      [],
      confidence: DiscoveryConfidence.unknown,
      evidence: [
        'No lib/features/<name>/ or lib/modules/<name>/ folders found — possibly a type-first layout (lib/blocs/, lib/screens/, lib/models/, ...), which this milestone does not attempt to reconstruct into a synthetic feature list',
      ],
    );
  }

  Set<String> _moduleFolderNames(ProjectScanResult scan) {
    const prefix = 'lib/modules/';
    final names = <String>{};
    for (final path in scan.dartFiles.keys) {
      if (!path.startsWith(prefix)) continue;
      final rest = path.substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash > 0) names.add(rest.substring(0, slash));
    }
    return names;
  }

  FeatureKnowledge _classify(
    ProjectScanResult scan,
    String name,
    String topLevelFolder,
  ) {
    final prefix = 'lib/$topLevelFolder/$name/';
    final files =
        scan.dartFiles.keys.where((p) => p.startsWith(prefix)).toList()..sort();

    final components = <FeatureComponent>{};
    final evidence = <String>[];

    void add(FeatureComponent component, String matchedPath) {
      if (components.add(component)) {
        evidence.add('$matchedPath: ${component.name}');
      }
    }

    var hasState = false;

    for (final filePath in files) {
      if (filePath.contains('/entities/') || filePath.endsWith('_model.dart')) {
        add(FeatureComponent.entity, filePath);
      }
      if (filePath.contains('/repositories/')) {
        add(FeatureComponent.repository, filePath);
      }
      if (filePath.contains('/usecases/') ||
          filePath.endsWith('_usecase.dart')) {
        add(FeatureComponent.useCase, filePath);
      }
      if (filePath.contains('/datasources/') ||
          filePath.endsWith('_data_source.dart')) {
        add(FeatureComponent.dataSource, filePath);
      }
      if (filePath.contains('/pages/') ||
          filePath.contains('/views/') ||
          filePath.endsWith('_page.dart')) {
        add(FeatureComponent.page, filePath);
      }
      if (filePath.contains('/widgets/')) {
        add(FeatureComponent.widgets, filePath);
      }
      if (filePath.contains('/state/') ||
          filePath.contains('/providers/') ||
          filePath.contains('/viewmodels/') ||
          filePath.contains('/presenters/')) {
        hasState = true;
      }
    }

    final testPrefix = 'test/$topLevelFolder/$name/';
    if (scan.dartFiles.keys.any((p) => p.startsWith(testPrefix))) {
      components.add(FeatureComponent.tests);
      evidence.add('$testPrefix: ${FeatureComponent.tests.name}');
    }

    return FeatureKnowledge(
      name: name,
      path: 'lib/$topLevelFolder/$name',
      components: components,
      hasState: hasState,
      confidence: topLevelFolder == 'features'
          ? DiscoveryConfidence.detected
          : DiscoveryConfidence.inferred,
      evidence: evidence,
    );
  }
}
