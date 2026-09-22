import 'package:path/path.dart' as path;

import '../../models/project_config.dart';
import '../../models/project_knowledge.dart';
import 'project_scan_result.dart';

final _relativeImportPattern =
    RegExp('''import\\s+['"](\\.\\./[^'"]*|\\./[^'"]*)['"]''');

class ArchitectureAnalyzer {
  DiscoveredValue<Architecture?> analyze(ProjectScanResult scan) {
    final features = scan.featureFolderNames;
    if (features.isEmpty) {
      return const DiscoveredValue(
        null,
        confidence: DiscoveryConfidence.unknown,
        evidence: ['No lib/features/<name>/ folders found'],
      );
    }

    final perFeature = <String, _FeatureArchitecture>{
      for (final feature in features) feature: _classifyFeature(scan, feature),
    };

    final withArchitecture =
        perFeature.entries.where((e) => e.value.architecture != null).toList();

    if (withArchitecture.isEmpty) {
      return DiscoveredValue(
        null,
        confidence: DiscoveryConfidence.unknown,
        evidence: [
          for (final entry in perFeature.entries) ...entry.value.evidence,
        ],
      );
    }

    final distinctArchitectures =
        withArchitecture.map((e) => e.value.architecture).toSet();

    if (distinctArchitectures.length > 1) {
      return DiscoveredValue(
        null,
        confidence: DiscoveryConfidence.unknown,
        evidence: [
          'Mixed architecture evidence across features:',
          for (final entry in perFeature.entries)
            '  ${entry.key}: ${entry.value.architecture?.name ?? 'unknown'} (${entry.value.confidence.name})',
        ],
      );
    }

    final overallConfidence = withArchitecture
            .any((e) => e.value.confidence == DiscoveryConfidence.detected)
        ? DiscoveryConfidence.detected
        : DiscoveryConfidence.inferred;

    return DiscoveredValue(
      distinctArchitectures.single,
      confidence: overallConfidence,
      evidence: [
        for (final entry in withArchitecture) ...entry.value.evidence,
      ],
    );
  }

  _FeatureArchitecture _classifyFeature(
    ProjectScanResult scan,
    String feature,
  ) {
    final prefix = 'lib/features/$feature/';
    final files = scan.filesUnderFeature(feature).toSet();

    final hasDomain = files.any((p) => p.startsWith('${prefix}domain/'));
    final hasData = files.any((p) => p.startsWith('${prefix}data/'));
    final hasViewModels =
        files.any((p) => p.startsWith('${prefix}viewmodels/'));
    final hasPresenters =
        files.any((p) => p.startsWith('${prefix}presenters/'));
    final hasViews = files.any((p) => p.startsWith('${prefix}views/'));

    if (hasDomain && hasData) {
      final domainFiles = files.where((p) => p.startsWith('${prefix}domain/'));
      final dataFiles = files.where((p) => p.startsWith('${prefix}data/'));

      final dataImportsDomain = dataFiles.any((f) => _importsMatching(
            scan.dartFiles[f]!,
            f,
            (resolved) => resolved.contains('/domain/'),
          ));
      final domainImportsDataOrPresentation =
          domainFiles.any((f) => _importsMatching(
                scan.dartFiles[f]!,
                f,
                (resolved) =>
                    resolved.contains('/data/') ||
                    resolved.contains('/presentation/'),
              ));

      if (dataImportsDomain && !domainImportsDataOrPresentation) {
        return _FeatureArchitecture(
          Architecture.cleanArchitecture,
          DiscoveryConfidence.detected,
          [
            '$feature: data/ imports domain/, and domain/ imports neither data/ nor presentation/ (Clean Architecture import-direction evidence)',
          ],
        );
      }

      return _FeatureArchitecture(
        Architecture.cleanArchitecture,
        DiscoveryConfidence.inferred,
        [
          '$feature: has both data/ and domain/ folders, but import direction is inconclusive or contradicts Clean Architecture',
        ],
      );
    }

    if (hasViewModels && hasViews && !hasDomain) {
      return _FeatureArchitecture(
        Architecture.mvvm,
        DiscoveryConfidence.detected,
        ['$feature: has viewmodels/ and views/, no domain/ layer'],
      );
    }

    if (hasPresenters && hasViews && !hasDomain) {
      return _FeatureArchitecture(
        Architecture.mvp,
        DiscoveryConfidence.detected,
        ['$feature: has presenters/ and views/, no domain/ layer'],
      );
    }

    return _FeatureArchitecture(
      null,
      DiscoveryConfidence.unknown,
      ['$feature: no recognized architecture folder shape'],
    );
  }

  bool _importsMatching(
    String content,
    String fromPath,
    bool Function(String resolvedImportPath) predicate,
  ) {
    for (final match in _relativeImportPattern.allMatches(content)) {
      final importPath = match.group(1)!;
      final resolved = path
          .normalize(path.join(path.dirname(fromPath), importPath))
          .replaceAll(path.separator, '/');
      if (predicate(resolved)) return true;
    }
    return false;
  }
}

class _FeatureArchitecture {
  final Architecture? architecture;
  final DiscoveryConfidence confidence;
  final List<String> evidence;

  _FeatureArchitecture(this.architecture, this.confidence, this.evidence);
}
