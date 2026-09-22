import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_core/smartwork_core.dart';

import 'confirmation_reader.dart';

class TestCommand extends Command {
  TestCommand({
    String projectPath = '.',
    ConfirmationReader? confirm,
    CoverageCollectionLifecycle? coverageLifecycle,
    TestMaintenanceLifecycle? maintenanceLifecycle,
  }) {
    addSubcommand(TestAnalyzeCommand(projectPath: projectPath));
    addSubcommand(TestGenerateCommand(
      projectPath: projectPath,
      confirm: confirm,
    ));
    addSubcommand(TestCheckCommand(
      projectPath: projectPath,
      maintenance: maintenanceLifecycle,
    ));
    addSubcommand(TestCoverageCommand(
      projectPath: projectPath,
      lifecycle: coverageLifecycle,
    ));
    addSubcommand(TestUpdateCommand(
      projectPath: projectPath,
      confirm: confirm,
      lifecycle: maintenanceLifecycle,
    ));
  }

  @override
  final name = 'test';

  @override
  final description = 'Analyze, generate, and maintain tests for an '
      'existing feature';
}

class TestAnalyzeCommand extends Command {
  final String projectPath;

  TestAnalyzeCommand({this.projectPath = '.'}) {
    argParser.addOption(
      'format',
      help: 'Output format.',
      allowed: ['text', 'json'],
      defaultsTo: 'text',
    );
    argParser.addFlag(
      'verbose',
      help: 'Include every scenario\'s own reason, not just a summary.',
      negatable: false,
    );
  }

  @override
  final name = 'analyze';

  @override
  final description = 'Report a feature\'s existing test coverage: which '
      'production subjects are covered, missing, or outdated';

  @override
  String get invocation =>
      'smartwork test analyze <feature> [--format text|json] [--verbose]';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      print('❌ Feature name is required. Usage: $invocation');
      exitCode = 1;
      return;
    }
    final feature = rest.first;
    final format = argResults!['format'] as String;
    final verbose = argResults!['verbose'] as bool;

    try {
      final analysis =
          await TestAnalysisLifecycle().analyze(projectPath, feature);

      if (format == 'json') {
        print(const JsonEncoder.withIndent('  ').convert(analysis.toJson()));
        return;
      }

      _printSummary(analysis, verbose: verbose);
    } on FeatureNotFoundForTestingException catch (e) {
      print('❌ $e');
      exitCode = 1;
    }
  }

  void _printSummary(TestAnalysis analysis, {required bool verbose}) {
    print('Feature: ${analysis.feature}');
    print('Existing test files: ${analysis.existingTestFiles.length}');
    print('');
    print('Scenarios: ${analysis.scenarios.length} total '
        '(${analysis.covered.length} covered, '
        '${analysis.missing.length} missing, '
        '${analysis.outdated.length} outdated, '
        '${analysis.broken.length} broken)');

    if (analysis.scenarios.isEmpty) {
      print('  No production subjects found for this feature.');
      return;
    }

    print('');
    for (final scenario in analysis.scenarios) {
      final icon = switch (scenario.status) {
        TestScenarioStatus.covered => '✔',
        TestScenarioStatus.missing => '✗',
        TestScenarioStatus.outdated => '⚠',
        TestScenarioStatus.broken => '✗',
        TestScenarioStatus.partial => '⚠',
      };
      print('  $icon ${scenario.subject} — ${scenario.status.name}');
      if (verbose) {
        print('      ${scenario.reason}');
      }
    }
  }
}

class TestGenerateCommand extends Command {
  final String projectPath;
  final ConfirmationReader _confirm;

  TestGenerateCommand({
    this.projectPath = '.',
    ConfirmationReader? confirm,
  }) : _confirm = confirm ?? readConfirmationFromStdin {
    argParser.addFlag(
      'dry-run',
      help: 'Show the plan without writing any file.',
      negatable: false,
    );
    argParser.addFlag(
      'non-interactive',
      help: 'Write the plan without asking for confirmation.',
      negatable: false,
    );
    argParser.addOption(
      'format',
      help: 'Output format.',
      allowed: ['text', 'json'],
      defaultsTo: 'text',
    );
  }

  @override
  final name = 'generate';

  @override
  final description = 'Generate real test files for a feature\'s missing '
      'test scenarios';

  @override
  String get invocation => 'smartwork test generate <feature> '
      '[--dry-run] [--non-interactive] [--format text|json]';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      print('❌ Feature name is required. Usage: $invocation');
      exitCode = 1;
      return;
    }
    final feature = rest.first;
    final dryRun = argResults!['dry-run'] as bool;
    final nonInteractive = argResults!['non-interactive'] as bool;
    final format = argResults!['format'] as String;

    final lifecycle = TestGenerationLifecycle();

    try {
      final plan = await lifecycle.plan(projectPath, feature);

      if (format == 'json') {
        print(const JsonEncoder.withIndent('  ').convert(plan.toJson()));
        if (dryRun) return;
      } else {
        _printPlan(plan);
      }

      if (plan.changes.isEmpty) {
        print('Nothing to generate.');
        return;
      }

      if (dryRun) {
        print('(dry run — no file was written)');
        return;
      }

      if (!nonInteractive) {
        final confirmed =
            _confirm('Write ${plan.changes.length} test file(s)? [y/N]: ');
        if (!confirmed) {
          print('Operation cancelled. No files were changed.');
          return;
        }
      }

      await lifecycle.apply(projectPath, plan);
      print('✔ Wrote ${plan.changes.length} test file(s).');
    } on FeatureNotFoundForTestingException catch (e) {
      print('❌ $e');
      exitCode = 1;
    } on UnknownPackageNameException catch (e) {
      print('❌ $e');
      exitCode = 1;
    }
  }

  void _printPlan(TestGenerationPlan plan) {
    print('Feature: ${plan.feature}');
    print('');
    if (plan.changes.isEmpty) {
      print('No new test file would be generated.');
    } else {
      print('Would create:');
      for (final change in plan.changes) {
        print('  • ${change.filePath}'
            '${change.content.contains('skip:') ? ' (scaffold, marked skip)' : ''}');
      }
    }
    if (plan.skipped.isNotEmpty) {
      print('');
      print('Skipped (${plan.skipped.length}):');
      for (final scenario in plan.skipped) {
        print('  • ${scenario.subject} — ${scenario.status.name}');
      }
    }
  }
}

class TestCheckCommand extends Command {
  final String projectPath;
  final TestMaintenanceLifecycle _maintenance;

  TestCheckCommand({
    this.projectPath = '.',
    TestMaintenanceLifecycle? maintenance,
  }) : _maintenance = maintenance ?? TestMaintenanceLifecycle() {
    argParser.addOption(
      'format',
      help: 'Output format.',
      allowed: ['text', 'json'],
      defaultsTo: 'text',
    );
  }

  @override
  final name = 'check';

  @override
  final description = 'Test Guard: fail if any scenario is missing, '
      'outdated, broken, or (with real coverage data) partial — or a '
      'real method/constructor call mismatch is found';

  @override
  String get invocation =>
      'smartwork test check <feature> [--format text|json]';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      print('❌ Feature name is required. Usage: $invocation');
      exitCode = 1;
      return;
    }
    final feature = rest.first;
    final format = argResults!['format'] as String;

    try {
      final analysis =
          await TestAnalysisLifecycle().analyze(projectPath, feature);
      final failing = [
        ...analysis.missing,
        ...analysis.outdated,
        ...analysis.broken,
        ...analysis.partial,
      ];

      final maintenancePlan = await _maintenance.plan(projectPath, feature);
      final reportedSubjects = failing.map((s) => s.subject).toSet();
      final unreportedUpdates = maintenancePlan.updates
          .where((u) => !reportedSubjects.contains(u.subject))
          .toList();
      final guardPassed = failing.isEmpty && unreportedUpdates.isEmpty;

      if (format == 'json') {
        print(const JsonEncoder.withIndent('  ').convert({
          ...analysis.toJson(),
          'guardPassed': guardPassed,
          'maintenance': maintenancePlan.toJson(),
        }));
      } else if (guardPassed) {
        print('✔ Test Guard passed for "${analysis.feature}" — '
            '${analysis.covered.length} scenario(s) covered.');
      } else {
        print('✗ Test Guard failed for "${analysis.feature}":');
        for (final scenario in failing) {
          print('  • ${scenario.subject} — ${scenario.status.name}: '
              '${scenario.reason}');
          _printMaintenanceDetails(maintenancePlan, scenario.subject);
        }
        final unreportedSubjects = <String>{
          for (final u in unreportedUpdates) u.subject,
        };
        for (final subject in unreportedSubjects) {
          final firstReason =
              unreportedUpdates.firstWhere((u) => u.subject == subject).reason;
          print('  • $subject — outdated: $firstReason');
          _printMaintenanceDetails(maintenancePlan, subject);
        }
        if (maintenancePlan.highConfidence.isNotEmpty) {
          print('');
          print('Run "smartwork test update $feature" to review and '
              'apply ${maintenancePlan.highConfidence.length} '
              'high-confidence fix(es).');
        }
      }

      if (!guardPassed) exitCode = 1;
    } on FeatureNotFoundForTestingException catch (e) {
      print('❌ $e');
      exitCode = 1;
    }
  }

  void _printMaintenanceDetails(TestMaintenancePlan plan, String subject) {
    final updates = plan.updates.where((u) => u.subject == subject);
    for (final update in updates) {
      print('      Confidence: ${update.confidence.name.toUpperCase()}');
      if (update.newSnippet != null) {
        print('      Suggested update:');
        print('        ${update.oldSnippet}');
        print('          →');
        print('        ${update.newSnippet}');
      } else {
        print('      Action: Manual review required.');
      }
    }
  }
}

class TestCoverageCommand extends Command {
  final String projectPath;
  final CoverageCollectionLifecycle _lifecycle;

  TestCoverageCommand({
    this.projectPath = '.',
    CoverageCollectionLifecycle? lifecycle,
  }) : _lifecycle = lifecycle ?? CoverageCollectionLifecycle() {
    argParser.addOption(
      'format',
      help: 'Output format.',
      allowed: ['text', 'json'],
      defaultsTo: 'text',
    );
    argParser.addFlag(
      'verbose',
      help: 'List every uncovered line, not just a per-file summary.',
      negatable: false,
    );
  }

  @override
  final name = 'coverage';

  @override
  final description = 'Run the project\'s tests with coverage and report '
      'a feature\'s own real coverage';

  @override
  String get invocation =>
      'smartwork test coverage <feature> [--format text|json] [--verbose]';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      print('❌ Feature name is required. Usage: $invocation');
      exitCode = 1;
      return;
    }
    final feature = rest.first;
    final format = argResults!['format'] as String;
    final verbose = argResults!['verbose'] as bool;

    try {
      final report = await _lifecycle.collect(projectPath, feature);

      if (format == 'json') {
        print(const JsonEncoder.withIndent('  ').convert(report.toJson()));
        return;
      }

      _printSummary(feature, report, verbose: verbose);
    } on FeatureNotFoundForTestingException catch (e) {
      print('❌ $e');
      exitCode = 1;
    } on CoverageNotProducedException catch (e) {
      print('❌ $e');
      exitCode = 1;
    }
  }

  void _printSummary(
    String feature,
    CoverageReport report, {
    required bool verbose,
  }) {
    print('Feature: $feature');
    if (report.files.isEmpty) {
      print('No coverage data for this feature\'s own files.');
      return;
    }

    print('Line coverage: '
        '${(report.lineCoverage * 100).toStringAsFixed(1)}% '
        '(${report.totalLinesHit}/${report.totalLinesFound} lines)');
    if (report.functionCoverage != null) {
      print('Function coverage: '
          '${(report.functionCoverage! * 100).toStringAsFixed(1)}%');
    }
    if (report.branchCoverage != null) {
      print('Branch coverage: '
          '${(report.branchCoverage! * 100).toStringAsFixed(1)}%');
    }

    print('');
    for (final file in report.files) {
      print('  ${file.file}: '
          '${(file.lineCoverage * 100).toStringAsFixed(1)}% '
          '(${file.linesHit}/${file.linesFound})');
      if (verbose) {
        for (final gap in file.gaps) {
          final detail = [
            if (gap.function != null) gap.function,
            if (gap.description != null) gap.description,
          ].join(' — ');
          print('      line ${gap.line}${detail.isEmpty ? '' : ': $detail'}');
        }
      }
    }
  }
}

class TestUpdateCommand extends Command {
  final String projectPath;
  final ConfirmationReader _confirm;
  final TestMaintenanceLifecycle _lifecycle;

  TestUpdateCommand({
    this.projectPath = '.',
    ConfirmationReader? confirm,
    TestMaintenanceLifecycle? lifecycle,
  })  : _confirm = confirm ?? readConfirmationFromStdin,
        _lifecycle = lifecycle ?? TestMaintenanceLifecycle() {
    argParser.addFlag(
      'dry-run',
      help: 'Show the plan without writing any file.',
      negatable: false,
    );
    argParser.addFlag(
      'non-interactive',
      help: 'Apply high-confidence updates without asking for '
          'confirmation.',
      negatable: false,
    );
    argParser.addOption(
      'format',
      help: 'Output format.',
      allowed: ['text', 'json'],
      defaultsTo: 'text',
    );
  }

  @override
  final name = 'update';

  @override
  final description = 'Safely update outdated tests for a feature — '
      'high-confidence changes only, always reviewed and verified';

  @override
  String get invocation => 'smartwork test update <feature> '
      '[--dry-run] [--non-interactive] [--format text|json]';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      print('❌ Feature name is required. Usage: $invocation');
      exitCode = 1;
      return;
    }
    final feature = rest.first;
    final dryRun = argResults!['dry-run'] as bool;
    final nonInteractive = argResults!['non-interactive'] as bool;
    final format = argResults!['format'] as String;

    try {
      final plan = await _lifecycle.plan(projectPath, feature);

      if (format == 'json') {
        print(const JsonEncoder.withIndent('  ').convert(plan.toJson()));
        if (dryRun) return;
      } else {
        _printPlan(plan);
      }

      if (plan.highConfidence.isEmpty) {
        print('No high-confidence updates to apply.');
        if (plan.mediumConfidence.isNotEmpty || plan.lowConfidence.isNotEmpty) {
          print('${plan.mediumConfidence.length} medium- and '
              '${plan.lowConfidence.length} low-confidence item(s) need '
              'manual review — see above.');
        }
        return;
      }

      if (dryRun) {
        print('(dry run — no file was written)');
        return;
      }

      if (!nonInteractive) {
        final confirmed = _confirm(
          'Apply ${plan.highConfidence.length} high-confidence test '
          'update(s)? [y/N]: ',
        );
        if (!confirmed) {
          print('Operation cancelled. No files were changed.');
          return;
        }
      }

      final applyResult = await _lifecycle.apply(projectPath, plan);
      print('✔ Applied ${applyResult.appliedUpdates.length} update(s) to '
          '${applyResult.updatedFiles.length} file(s).');

      print('Verifying (dart format, flutter analyze, flutter test)...');
      final verification =
          await _lifecycle.verify(projectPath, applyResult.updatedFiles);

      if (!verification.passed) {
        print('✗ Verification failed — rolling back.');
        if (!verification.analyzePassed) {
          print(verification.analyzeOutput);
        } else {
          for (final result
              in verification.testResults.where((r) => !r.passed)) {
            print('  ${result.command}: exit code ${result.exitCode}');
            for (final failure in result.failures) {
              print('    ✗ ${failure.test}: ${failure.error ?? ''}');
            }
          }
        }
        await _lifecycle.rollback(projectPath, applyResult.originalContents);
        print('Rolled back — no changes were kept. Review the diff above '
            'and update manually if needed.');
        exitCode = 1;
        return;
      }

      print('✔ Verification passed (dart format, flutter analyze, '
          'flutter test).');
    } on FeatureNotFoundForTestingException catch (e) {
      print('❌ $e');
      exitCode = 1;
    } on StaleTestUpdateException catch (e) {
      print('❌ $e');
      exitCode = 1;
    }
  }

  void _printPlan(TestMaintenancePlan plan) {
    print('Feature: ${plan.feature}');
    print('Outdated tests: ${plan.updates.length}');
    print('');
    for (final update in plan.updates) {
      print(update.testFile);
      print('  Subject: ${update.subject}');
      print('  Reason: ${update.reason}');
      print('  Confidence: ${update.confidence.name.toUpperCase()}');
      if (update.newSnippet != null) {
        print('  Diff:');
        for (final line in update.diff!.split('\n')) {
          print('    $line');
        }
      } else {
        print('  Action: Manual review required.');
      }
      print('');
    }
  }
}
