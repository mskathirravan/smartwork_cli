import 'dart:io';

import 'package:path/path.dart' as path;

import '../flutter/flutter_bootstrap.dart' show ProcessRunner, runSystemProcess;
import '../models/project_config.dart';

enum ValidationPhase {
  platforms('Platforms'),
  dependencies('Dependencies'),
  format('Format'),
  analyze('Analyze'),
  tests('Tests');

  final String label;

  const ValidationPhase(this.label);
}

class ValidationPhaseResult {
  final ValidationPhase phase;
  final bool passed;
  final String output;

  /// What the developer should do about a failure, when SmartWork can tell
  /// (e.g. an out-of-date Flutter SDK); null otherwise.
  final String? hint;

  ValidationPhaseResult({
    required this.phase,
    required this.passed,
    required this.output,
    this.hint,
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

  /// [toString] followed by the failed phase's hint and captured output, for
  /// callers (e.g. MCP tools) that report the failure as a single message.
  String get details {
    final failed = result.phases.last;
    return [
      toString(),
      if (failed.hint != null) failed.hint!,
      if (failed.output.isNotEmpty) failed.output,
    ].join('\n\n');
  }
}

class ProjectValidator {
  final ProcessRunner _runProcess;

  ProjectValidator({ProcessRunner? runProcess})
      : _runProcess = runProcess ?? runSystemProcess;

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

    // Dependencies runs before Format: an out-of-date SDK fails here with
    // an actionable "update Flutter" hint, rather than surfacing first as
    // formatter style drift.
    final dependencies = await resolveDependencies(projectPath);
    if (dependencies.passed && localizationEnabled) {
      final genL10n = await _run('flutter', ['gen-l10n'], projectPath);
      phases.add(genL10n.exitCode == 0
          ? dependencies
          : _result(ValidationPhase.dependencies, genL10n));
    } else {
      phases.add(dependencies);
    }
    if (!phases.last.passed) {
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

  /// Runs `dart format` on [files] (SmartWork-generated Dart files). A
  /// failure is not reported here: the Format and Analyze phases surface
  /// anything still wrong.
  Future<void> formatDartFiles(
      String projectPath, Iterable<String> files) async {
    final existing = files.where((f) => File(f).existsSync()).toList()..sort();
    if (existing.isEmpty) return;
    await _run('dart', ['format', ...existing], projectPath);
  }

  /// Runs `flutter pub get` in [projectPath] as the Dependencies phase. A
  /// failure caused by an out-of-date Flutter SDK carries an "update
  /// Flutter" hint.
  Future<ValidationPhaseResult> resolveDependencies(String projectPath) async {
    final pubGet = await _run('flutter', ['pub', 'get'], projectPath);
    final result = _result(ValidationPhase.dependencies, pubGet);
    if (result.passed || !SdkUpdateHint.isSdkTooOld(result.output)) {
      return result;
    }
    return ValidationPhaseResult(
      phase: result.phase,
      passed: false,
      output: result.output,
      hint: SdkUpdateHint.message(result.output),
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

/// Recognizes `flutter pub get` failures caused by the developer's Flutter
/// SDK being older than the package versions SmartWork generates. SmartWork
/// only supports the latest stable Flutter, so the fix is always to update
/// the SDK — never to downgrade packages.
class SdkUpdateHint {
  static const _markers = [
    // "google_fonts >=6.3.1 which requires SDK version >=3.7.0 <4.0.0"
    'requires SDK version',
    // "... which requires Flutter SDK version >=3.38.0"
    'requires Flutter SDK version',
    // "meta is pinned to version 1.15.0 by flutter_test from the flutter SDK"
    'from the flutter SDK',
  ];

  static bool isSdkTooOld(String pubOutput) => _markers.any(pubOutput.contains);

  /// [output] of a failed `flutter` command, followed by the "update
  /// Flutter" message when an out-of-date SDK caused the failure.
  static String describeFailure(String output) {
    final trimmed = output.trim();
    if (!isSdkTooOld(trimmed)) return trimmed;
    return '$trimmed\n\n${message(trimmed)}';
  }

  static String message(String pubOutput) {
    final current = RegExp(
      r'The current (Dart|Flutter) SDK version is (\S+?)\.?$',
      multiLine: true,
    ).firstMatch(pubOutput);
    final version = current == null
        ? ''
        : ' (your ${current.group(1)} SDK is ${current.group(2)})';
    return 'Your Flutter SDK is too old for the package versions SmartWork '
        'uses$version.\n'
        'SmartWork supports only the latest stable Flutter. Update Flutter, '
        'then run the command again:\n'
        '  flutter upgrade\n'
        '  (FVM: fvm install stable && fvm use stable)';
  }
}
