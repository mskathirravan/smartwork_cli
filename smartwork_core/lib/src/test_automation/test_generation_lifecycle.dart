import 'package:path/path.dart' as p;

import '../filesystem/file_writer.dart';
import '../generator/discover/project_scanner.dart';
import '../models/test_analysis.dart';
import 'test_analysis_lifecycle.dart';
import 'test_discovery_service.dart';
import 'test_gap_analyzer.dart';
import 'test_generation_service.dart';

class TestGenerationLifecycle {
  final ProjectScanner _scanner;
  final TestDiscoveryService _discovery;
  final TestGapAnalyzer _gapAnalyzer;
  final TestGenerationService _generator;
  final FileWriter _fileWriter;

  TestGenerationLifecycle({
    ProjectScanner? scanner,
    TestDiscoveryService? discovery,
    TestGapAnalyzer? gapAnalyzer,
    TestGenerationService? generator,
    FileWriter? fileWriter,
  })  : _scanner = scanner ?? ProjectScanner(),
        _discovery = discovery ?? TestDiscoveryService(),
        _gapAnalyzer = gapAnalyzer ?? TestGapAnalyzer(),
        _generator = generator ?? TestGenerationService(),
        _fileWriter = fileWriter ?? FileWriter();

  Future<TestGenerationPlan> plan(String projectPath, String feature) async {
    final scan = await _scanner.scan(projectPath);

    if (!scan.featureFolderNames.contains(feature)) {
      throw FeatureNotFoundForTestingException(feature);
    }

    final discovery = _discovery.discover(scan, feature);
    final scenarios = _gapAnalyzer.analyze(scan, discovery);
    return _generator.generate(scan, discovery, scenarios);
  }

  Future<void> apply(String projectPath, TestGenerationPlan plan) async {
    for (final change in plan.changes) {
      await _fileWriter.write(
        p.join(projectPath, change.filePath),
        change.content,
      );
    }
  }
}
