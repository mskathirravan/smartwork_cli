import 'dart:io';

import 'package:path/path.dart' as p;

import '../generator/discover/project_scanner.dart';
import '../models/coverage_report.dart';
import '../models/mock_mapping.dart';
import 'lcov_parser.dart';
import 'mock_server.dart';
import 'test_analysis_lifecycle.dart';
import 'test_execution_service.dart';

class CoverageNotProducedException implements Exception {
  final String projectPath;

  CoverageNotProducedException(this.projectPath);

  @override
  String toString() => 'flutter test --coverage did not produce '
      '$projectPath/coverage/lcov.info.';
}

class CoverageCollectionLifecycle {
  final ProjectScanner _scanner;
  final TestExecutionService _executionService;
  final LcovParser _lcovParser;

  CoverageCollectionLifecycle({
    ProjectScanner? scanner,
    TestExecutionService? executionService,
    LcovParser? lcovParser,
  })  : _scanner = scanner ?? ProjectScanner(),
        _executionService = executionService ?? TestExecutionService(),
        _lcovParser = lcovParser ?? LcovParser();

  Future<CoverageReport> collect(
    String projectPath,
    String feature, {
    String? testTarget,
    MockServer? mockServer,
    List<MockMapping>? mappings,
  }) async {
    final scan = await _scanner.scan(projectPath);
    if (!scan.featureFolderNames.contains(feature)) {
      throw FeatureNotFoundForTestingException(feature);
    }

    await _executionService.run(
      projectPath: projectPath,
      testTarget: testTarget,
      coverage: true,
      mockServer: mockServer,
      mappings: mappings,
    );

    final lcovFile = File(p.join(projectPath, 'coverage', 'lcov.info'));
    if (!await lcovFile.exists()) {
      throw CoverageNotProducedException(projectPath);
    }

    final report = _lcovParser.parse(await lcovFile.readAsString());
    return report.forFeature('lib/features/$feature/');
  }
}
