import 'coverage_report.dart';
import 'test_scenario.dart';

enum TestChangeKind { create, update }

class TestChange {
  final TestChangeKind kind;

  final String filePath;

  final String content;

  final String? summary;

  final List<TestScenario> scenarios;

  TestChange({
    required this.kind,
    required this.filePath,
    required this.content,
    this.summary,
    required this.scenarios,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'filePath': filePath,
        'summary': summary,
        'scenarios': scenarios.map((s) => s.toJson()).toList(),
      };
}

class TestGenerationPlan {
  final String feature;
  final List<TestChange> changes;

  final List<TestScenario> skipped;

  TestGenerationPlan({
    required this.feature,
    required this.changes,
    this.skipped = const [],
  });

  Map<String, dynamic> toJson() => {
        'feature': feature,
        'changes': changes.map((c) => c.toJson()).toList(),
        'skipped': skipped.map((s) => s.toJson()).toList(),
      };
}

class TestAnalysis {
  final String feature;

  final List<String> existingTestFiles;

  final List<TestScenario> scenarios;

  final List<String> dependencies;

  final List<String> apiDependencies;

  final CoverageReport? coverage;

  TestAnalysis({
    required this.feature,
    required this.existingTestFiles,
    required this.scenarios,
    this.dependencies = const [],
    this.apiDependencies = const [],
    this.coverage,
  });

  List<TestScenario> get covered =>
      scenarios.where((s) => s.status == TestScenarioStatus.covered).toList();

  List<TestScenario> get missing =>
      scenarios.where((s) => s.status == TestScenarioStatus.missing).toList();

  List<TestScenario> get outdated =>
      scenarios.where((s) => s.status == TestScenarioStatus.outdated).toList();

  List<TestScenario> get broken =>
      scenarios.where((s) => s.status == TestScenarioStatus.broken).toList();

  List<TestScenario> get partial =>
      scenarios.where((s) => s.status == TestScenarioStatus.partial).toList();

  Map<String, dynamic> toJson() => {
        'feature': feature,
        'existingTestFiles': existingTestFiles,
        'scenarios': scenarios.map((s) => s.toJson()).toList(),
        'dependencies': dependencies,
        'apiDependencies': apiDependencies,
        'coverage': coverage?.toJson(),
        'summary': {
          'coveredCount': covered.length,
          'missingCount': missing.length,
          'outdatedCount': outdated.length,
          'brokenCount': broken.length,
          'partialCount': partial.length,
        },
      };
}
