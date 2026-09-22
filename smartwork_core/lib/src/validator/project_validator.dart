import 'dart:io';

import 'package:path/path.dart' as path;

import '../flutter/flutter_bootstrap.dart' show ProcessRunner;
import '../models/project_config.dart';

enum ValidationPhase {
  platforms('Platforms'),
  format('Format'),
  dependencies('Dependencies'),
  analyze('Analyze'),
  tests('Tests');

  final String label;

  const ValidationPhase(this.label);
}

class ValidationPhaseResult {
  final ValidationPhase phase;
  final bool passed;
  final String output;

  ValidationPhaseResult({
    required this.phase,
    required this.passed,
    required this.output,
  });
}

class ProjectValidationResult {
  final List<ValidationPhaseResult> phases;
  final bool passed;

  ProjectValidationResult({required this.phases, required this.passed});
}

class ProjectValidationFailedException implements Exception {
  final ProjectValidationResult result;

  ProjectValidationFailedException(this.result);

  @override
  String toString() =>
      'Project validation failed at the "${result.phases.last.phase.label}" '
      'phase.';
}

class ProjectValidator {
  final ProcessRunner _runProcess;

  ProjectValidator({ProcessRunner? runProcess})
      : _runProcess = runProcess ?? Process.run;

  Future<ProjectValidationResult> validate(
    String projectPath, {
    required Set<AppTarget> appTargets,
    bool localizationEnabled = false,
  }) async {
    final phases = <ValidationPhaseResult>[];

    final platforms = _checkPlatforms(projectPath, appTargets);
    phases.add(platforms);
    if (!platforms.passed) {
      return ProjectValidationResult(phases: phases, passed: false);
    }

    final format = await _run(
      'dart',
      ['format', '--output=none', '--set-exit-if-changed', '.'],
      projectPath,
    );
    phases.add(_result(ValidationPhase.format, format));
    if (format.exitCode != 0) {
      return ProjectValidationResult(phases: phases, passed: false);
    }

    final pubGet = await _run('flutter', ['pub', 'get'], projectPath);
    if (pubGet.exitCode == 0 && localizationEnabled) {
      final genL10n = await _run('flutter', ['gen-l10n'], projectPath);
      phases.add(_result(
        ValidationPhase.dependencies,
        genL10n.exitCode == 0 ? pubGet : genL10n,
      ));
    } else {
      phases.add(_result(ValidationPhase.dependencies, pubGet));
    }
    if (!phases.last.passed) {
      return ProjectValidationResult(phases: phases, passed: false);
    }

    final analyze = await _run('flutter', ['analyze'], projectPath);
    phases.add(_result(ValidationPhase.analyze, analyze));
    if (analyze.exitCode != 0) {
      return ProjectValidationResult(phases: phases, passed: false);
    }

    final test = await _run('flutter', ['test'], projectPath);
    phases.add(_result(ValidationPhase.tests, test));
    return ProjectValidationResult(phases: phases, passed: test.exitCode == 0);
  }

  ValidationPhaseResult _checkPlatforms(
    String projectPath,
    Set<AppTarget> appTargets,
  ) {
    final missing = appTargets
        .where((target) =>
            !Directory(path.join(projectPath, target.platformFolder))
                .existsSync())
        .toList();

    if (missing.isEmpty) {
      return ValidationPhaseResult(
        phase: ValidationPhase.platforms,
        passed: true,
        output: '',
      );
    }

    final names = missing.map((t) => t.platformFolder).join(', ');
    return ValidationPhaseResult(
      phase: ValidationPhase.platforms,
      passed: false,
      output: 'Missing platform folder(s) for selected App Target(s): '
          '$names',
    );
  }

  ValidationPhaseResult _result(ValidationPhase phase, ProcessResult result) {
    return ValidationPhaseResult(
      phase: phase,
      passed: result.exitCode == 0,
      output: '${result.stdout}\n${result.stderr}'.trim(),
    );
  }

  Future<ProcessResult> _run(
    String executable,
    List<String> arguments,
    String workingDirectory,
  ) async {
    try {
      return await _runProcess(
        executable,
        arguments,
        workingDirectory: workingDirectory,
      );
    } on ProcessException catch (e) {
      return ProcessResult(
        0,
        -1,
        '',
        'the "$executable" executable was not found on PATH. (${e.message})',
      );
    }
  }
}
