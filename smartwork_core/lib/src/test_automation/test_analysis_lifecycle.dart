import 'dart:io';

import 'package:path/path.dart' as p;

import '../generator/discover/project_scanner.dart';
import '../models/coverage_report.dart';
import '../models/test_analysis.dart';
import 'lcov_parser.dart';
import 'test_discovery_service.dart';
import 'test_gap_analyzer.dart';

class FeatureNotFoundForTestingException implements Exception {
  final String feature;

  FeatureNotFoundForTestingException(this.feature);

  @override
  String toString() => 'No feature named "$feature" found under lib/features/.';
}

class TestAnalysisLifecycle {
  final ProjectScanner _scanner;
  final TestDiscoveryService _discovery;
  final TestGapAnalyzer _gapAnalyzer;
  final LcovParser _lcovParser;

  TestAnalysisLifecycle({
    ProjectScanner? scanner,
    TestDiscoveryService? discovery,
    TestGapAnalyzer? gapAnalyzer,
    LcovParser? lcovParser,
  })  : _scanner = scanner ?? ProjectScanner(),
        _discovery = discovery ?? TestDiscoveryService(),
        _gapAnalyzer = gapAnalyzer ?? TestGapAnalyzer(),
        _lcovParser = lcovParser ?? LcovParser();

  Future<TestAnalysis> analyze(String projectPath, String feature) async {
    final scan = await _scanner.scan(projectPath);

    if (!scan.featureFolderNames.contains(feature)) {
      throw FeatureNotFoundForTestingException(feature);
    }

    final discovery = _discovery.discover(scan, feature);
    var scenarios = _gapAnalyzer.analyze(scan, discovery);

    CoverageReport? coverage;
    final lcovFile = File(p.join(projectPath, 'coverage', 'lcov.info'));
    if (await lcovFile.exists()) {
      coverage = _lcovParser
          .parse(await lcovFile.readAsString())
          .forFeature('lib/features/$feature/');
      scenarios = _gapAnalyzer.withCoverage(scenarios, coverage);
    }

    return TestAnalysis(
      feature: feature,
      existingTestFiles: discovery.testFiles,
      scenarios: scenarios,
      coverage: coverage,
    );
  }
}
