import '../generator/discover/project_scan_result.dart';
import '../models/coverage_report.dart';
import '../models/test_scenario.dart';
import 'test_discovery_service.dart';

final _constructorNamedParam = RegExp(r'\bthis\.(\w+)\s*[,}]');

class TestGapAnalyzer {
  List<TestScenario> analyze(
    ProjectScanResult scan,
    FeatureTestDiscovery discovery,
  ) {
    return [
      for (final subject in discovery.subjects)
        _scenarioFor(scan, discovery, subject),
    ];
  }

  TestScenario _scenarioFor(
    ProjectScanResult scan,
    FeatureTestDiscovery discovery,
    ProductionSubject subject,
  ) {
    final testFiles = discovery.testFilesForSubject[subject.name];

    if (testFiles == null || testFiles.isEmpty) {
      return TestScenario(
        feature: discovery.feature,
        subject: subject.name,
        type: TestType.unit,
        preconditions: '${subject.name} has no existing test',
        action: 'construct and exercise ${subject.name}',
        expectedResult: 'a real test file exists for ${subject.name}',
        coverageTargets: [subject.filePath],
        status: TestScenarioStatus.missing,
        reason: 'No file under test/features/${discovery.feature}/ references '
            '${subject.name} at all',
      );
    }

    final staleParams = _staleConstructorParams(scan, subject, testFiles);
    if (staleParams.isNotEmpty) {
      return TestScenario(
        feature: discovery.feature,
        subject: subject.name,
        type: TestType.unit,
        preconditions: '${subject.name} declares ${staleParams.join(', ')}',
        action: 'construct ${subject.name} with every declared parameter',
        expectedResult: 'the existing test exercises every declared parameter',
        existingTest: testFiles.first,
        coverageTargets: [subject.filePath],
        status: TestScenarioStatus.outdated,
        reason: '${subject.name} declares constructor parameter(s) '
            '${staleParams.join(', ')} that never appear in any test '
            'referencing it (${testFiles.join(', ')})',
      );
    }

    return TestScenario(
      feature: discovery.feature,
      subject: subject.name,
      type: TestType.unit,
      preconditions: '${subject.name} exists',
      action: 'exercise ${subject.name}',
      expectedResult: 'covered by an existing test',
      existingTest: testFiles.first,
      coverageTargets: [subject.filePath],
      status: TestScenarioStatus.covered,
      reason: '${subject.name} is referenced in ${testFiles.join(', ')}',
    );
  }

  List<String> _staleConstructorParams(
    ProjectScanResult scan,
    ProductionSubject subject,
    List<String> testFiles,
  ) {
    final source = scan.dartFiles[subject.filePath];
    if (source == null) return const [];

    final declaredParams = _constructorNamedParam
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toSet();
    if (declaredParams.isEmpty) return const [];

    final combinedTestText =
        testFiles.map((f) => scan.dartFiles[f] ?? '').join('\n');

    return declaredParams
        .where((p) => !RegExp(r'\b' + p + r'\b').hasMatch(combinedTestText))
        .toList()
      ..sort();
  }

  List<TestScenario> withCoverage(
    List<TestScenario> scenarios,
    CoverageReport coverage,
  ) {
    return [
      for (final scenario in scenarios) _foldCoverage(scenario, coverage),
    ];
  }

  TestScenario _foldCoverage(TestScenario scenario, CoverageReport coverage) {
    if (scenario.status != TestScenarioStatus.covered) return scenario;

    final gaps = coverage.allGaps
        .where((g) => scenario.coverageTargets.contains(g.file))
        .toList()
      ..sort((a, b) => a.line.compareTo(b.line));
    if (gaps.isEmpty) return scenario;

    final lines = gaps.map((g) => g.line).join(', ');
    return TestScenario(
      feature: scenario.feature,
      subject: scenario.subject,
      type: scenario.type,
      preconditions: scenario.preconditions,
      action: scenario.action,
      expectedResult: scenario.expectedResult,
      dependencies: scenario.dependencies,
      mockRequirements: scenario.mockRequirements,
      coverageTargets: scenario.coverageTargets,
      existingTest: scenario.existingTest,
      status: TestScenarioStatus.partial,
      reason: '${scenario.reason} — but real coverage data shows '
          '${gaps.length} uncovered line(s) in ${scenario.coverageTargets.first}: '
          'line(s) $lines',
    );
  }
}
