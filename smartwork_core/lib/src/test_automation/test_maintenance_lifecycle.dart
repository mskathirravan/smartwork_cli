import 'dart:io';

import 'package:path/path.dart' as p;

import '../filesystem/file_writer.dart';
import '../flutter/flutter_bootstrap.dart' show ProcessRunner, runSystemProcess;
import '../generator/discover/project_scanner.dart';
import '../models/test_maintenance.dart';
import '../models/test_result.dart';
import 'test_analysis_lifecycle.dart';
import 'test_discovery_service.dart';
import 'test_execution_service.dart';
import 'test_maintenance_analyzer.dart';

class StaleTestUpdateException implements Exception {
  final String testFile;
  final String subject;

  StaleTestUpdateException(this.testFile, this.subject);

  @override
  String toString() =>
      '$testFile changed since this update for $subject was planned; '
      're-run smartwork test check/update to get a fresh plan.';
}

class TestMaintenanceApplyResult {
  final List<TestUpdate> appliedUpdates;
  final List<TestUpdate> skippedUpdates;

  final Map<String, String> originalContents;

  TestMaintenanceApplyResult({
    required this.appliedUpdates,
    required this.skippedUpdates,
    required this.originalContents,
  });

  List<String> get updatedFiles => originalContents.keys.toList();
}

class TestMaintenanceVerificationResult {
  final bool formatChanged;
  final bool analyzePassed;
  final String analyzeOutput;
  final List<TestSuiteResult> testResults;

  TestMaintenanceVerificationResult({
    required this.formatChanged,
    required this.analyzePassed,
    required this.analyzeOutput,
    required this.testResults,
  });

  bool get testsPassed => testResults.every((r) => r.passed);

  bool get passed => analyzePassed && testsPassed;
}

class TestMaintenanceLifecycle {
  final ProjectScanner _scanner;
  final TestDiscoveryService _discovery;
  final TestMaintenanceAnalyzer _analyzer;
  final FileWriter _fileWriter;
  final TestExecutionService _executionService;
  final ProcessRunner _runProcess;

  TestMaintenanceLifecycle({
    ProjectScanner? scanner,
    TestDiscoveryService? discovery,
    TestMaintenanceAnalyzer? analyzer,
    FileWriter? fileWriter,
    TestExecutionService? executionService,
    ProcessRunner? runProcess,
  })  : _scanner = scanner ?? ProjectScanner(),
        _discovery = discovery ?? TestDiscoveryService(),
        _analyzer = analyzer ?? TestMaintenanceAnalyzer(),
        _fileWriter = fileWriter ?? FileWriter(),
        _executionService = executionService ?? TestExecutionService(),
        _runProcess = runProcess ?? runSystemProcess;

  Future<TestMaintenancePlan> plan(String projectPath, String feature) async {
    final scan = await _scanner.scan(projectPath);

    if (!scan.featureFolderNames.contains(feature)) {
      throw FeatureNotFoundForTestingException(feature);
    }

    final discovery = _discovery.discover(scan, feature);
    final updates = _analyzer.analyze(scan, discovery);
    return TestMaintenancePlan(feature: feature, updates: updates);
  }

  Future<TestMaintenanceApplyResult> apply(
    String projectPath,
    TestMaintenancePlan plan,
  ) async {
    final applicable = plan.highConfidence
        .where((u) =>
            u.newSnippet != null &&
            u.startOffset != null &&
            u.endOffset != null)
        .toList();
    final skipped = plan.updates.where((u) => !applicable.contains(u)).toList();

    if (applicable.isEmpty) {
      return TestMaintenanceApplyResult(
        appliedUpdates: const [],
        skippedUpdates: skipped,
        originalContents: const {},
      );
    }

    final byFile = <String, List<TestUpdate>>{};
    for (final update in applicable) {
      (byFile[update.testFile] ??= []).add(update);
    }

    final originalContents = <String, String>{};
    final newContents = <String, String>{};

    for (final entry in byFile.entries) {
      final filePath = entry.key;
      final absolutePath = p.join(projectPath, filePath);
      final original = await File(absolutePath).readAsString();
      originalContents[filePath] = original;

      final sorted = [...entry.value]
        ..sort((a, b) => b.startOffset!.compareTo(a.startOffset!));

      var content = original;
      for (final update in sorted) {
        final actual =
            content.substring(update.startOffset!, update.endOffset!);
        if (actual != update.oldSnippet) {
          throw StaleTestUpdateException(filePath, update.subject);
        }
        content = content.replaceRange(
          update.startOffset!,
          update.endOffset!,
          update.newSnippet!,
        );
      }
      newContents[filePath] = content;
    }

    for (final entry in newContents.entries) {
      await _fileWriter.write(p.join(projectPath, entry.key), entry.value);
    }

    return TestMaintenanceApplyResult(
      appliedUpdates: applicable,
      skippedUpdates: skipped,
      originalContents: originalContents,
    );
  }

  Future<void> rollback(
    String projectPath,
    Map<String, String> originalContents,
  ) async {
    for (final entry in originalContents.entries) {
      await _fileWriter.write(p.join(projectPath, entry.key), entry.value);
    }
  }

  Future<TestMaintenanceVerificationResult> verify(
    String projectPath,
    List<String> changedFiles,
  ) async {
    final formatResult = await _runProcess(
      'dart',
      ['format', ...changedFiles],
      workingDirectory: projectPath,
    );
    final formatOutput = formatResult.stdout.toString();
    final formatChanged = formatOutput.contains('Formatted') &&
        !formatOutput.contains('(0 changed)');

    final analyzeResult = await _runProcess(
      'flutter',
      ['analyze', ...changedFiles],
      workingDirectory: projectPath,
    );
    final analyzeOutput =
        '${analyzeResult.stdout}\n${analyzeResult.stderr}'.trim();
    final analyzePassed = analyzeResult.exitCode == 0;

    if (!analyzePassed) {
      return TestMaintenanceVerificationResult(
        formatChanged: formatChanged,
        analyzePassed: false,
        analyzeOutput: analyzeOutput,
        testResults: const [],
      );
    }

    final testResults = <TestSuiteResult>[];
    for (final file in changedFiles) {
      testResults.add(await _executionService.run(
        projectPath: projectPath,
        testTarget: file,
      ));
    }

    return TestMaintenanceVerificationResult(
      formatChanged: formatChanged,
      analyzePassed: true,
      analyzeOutput: analyzeOutput,
      testResults: testResults,
    );
  }
}
