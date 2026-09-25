import 'dart:io';

import 'package:path/path.dart' as path;

import '../flutter/flutter_bootstrap.dart';
import '../generator/pubspec_generator.dart';
import 'project_validator.dart' show SdkUpdateHint;

/// One check of [EnvironmentDoctor.checkEnvironment].
class EnvironmentCheck {
  /// What was checked, e.g. `Flutter`.
  final String label;

  /// Whether the check passed.
  final bool passed;

  /// Extra information: a version, or what's wrong and how to fix it.
  final String? detail;

  /// The check could not reach a verdict (e.g. pub.dev unreachable), so it
  /// is informational rather than a pass or a failure.
  final bool inconclusive;

  /// A check result.
  EnvironmentCheck({
    required this.label,
    required this.passed,
    this.detail,
    this.inconclusive = false,
  });
}

/// Checks the local environment is ready for SmartWork, like
/// `smartwork doctor`.
class EnvironmentDoctor {
  final ProcessRunner _runProcess;
  final Future<String> Function() _dependencyProbe;

  /// A doctor; [runProcess] and [dependencyProbe] can be replaced (e.g.
  /// in tests).
  EnvironmentDoctor({
    ProcessRunner? runProcess,
    Future<String> Function()? dependencyProbe,
  })  : _runProcess = runProcess ?? runSystemProcess,
        _dependencyProbe =
            dependencyProbe ?? PubspecGenerator().generateDependencyProbe;

  /// Checks Dart, the Flutter executable, Flutter itself and — when
  /// Flutter works — that it can resolve SmartWork's package versions.
  Future<List<EnvironmentCheck>> checkEnvironment() async {
    final results = <EnvironmentCheck>[await _checkVersionCommand('dart')];

    bool flutterExecutableFound;
    ProcessResult? flutterResult;
    String? flutterError;
    try {
      flutterResult = await _runProcess('flutter', ['--version']);
      flutterExecutableFound = true;
    } on ProcessException catch (e) {
      flutterExecutableFound = false;
      flutterError = e.message;
    }

    results.add(EnvironmentCheck(
      label: 'Flutter executable',
      passed: flutterExecutableFound,
      detail: flutterExecutableFound
          ? null
          : 'Flutter executable was not found. ${flutterError ?? ''}'.trim(),
    ));
    results.add(EnvironmentCheck(
      label: 'Flutter',
      passed: flutterExecutableFound && flutterResult!.exitCode == 0,
      detail: !flutterExecutableFound
          ? 'Flutter executable was not found.'
          : flutterResult!.exitCode == 0
              ? _firstLine(flutterResult.stdout.toString())
              : 'flutter --version exited with code '
                  '${flutterResult.exitCode}.',
    ));

    if (results.last.passed) {
      results.add(await _checkPackageCompatibility());
    }

    return results;
  }

  /// Resolves every package SmartWork can generate, at the versions it
  /// would write, against the local Flutter SDK — the same `flutter pub get`
  /// that `smartwork init` runs, without generating a project.
  Future<EnvironmentCheck> _checkPackageCompatibility() async {
    const label = 'Package compatibility';
    final probeDir =
        await Directory.systemTemp.createTemp('smartwork_doctor_probe_');
    try {
      await File(path.join(probeDir.path, 'pubspec.yaml'))
          .writeAsString(await _dependencyProbe());
      final result = await _runProcess(
        'flutter',
        ['pub', 'get'],
        workingDirectory: probeDir.path,
      );
      if (result.exitCode == 0) {
        return EnvironmentCheck(
          label: label,
          passed: true,
          detail: 'Flutter SDK supports the package versions SmartWork uses',
        );
      }
      final output = '${result.stdout}\n${result.stderr}'.trim();
      if (SdkUpdateHint.isSdkTooOld(output)) {
        return EnvironmentCheck(
          label: label,
          passed: false,
          detail: SdkUpdateHint.message(output),
        );
      }
      return EnvironmentCheck(
        label: label,
        passed: false,
        inconclusive: true,
        detail: 'Could not check (flutter pub get failed): '
            '${_lastLine(output)}',
      );
    } on ProcessException catch (e) {
      return EnvironmentCheck(
        label: label,
        passed: false,
        inconclusive: true,
        detail: 'Could not check: ${e.message}',
      );
    } finally {
      await probeDir.delete(recursive: true);
    }
  }

  Future<EnvironmentCheck> _checkVersionCommand(String executable) async {
    try {
      final result = await _runProcess(executable, ['--version']);
      if (result.exitCode == 0) {
        final output = '${result.stdout}${result.stderr}';
        return EnvironmentCheck(
          label: _formatExecutableName(executable),
          passed: true,
          detail: _firstLine(output),
        );
      }
      return EnvironmentCheck(
        label: _formatExecutableName(executable),
        passed: false,
        detail: '$executable --version exited with code ${result.exitCode}.',
      );
    } on ProcessException catch (e) {
      return EnvironmentCheck(
        label: _formatExecutableName(executable),
        passed: false,
        detail: '$executable executable was not found. ${e.message}'.trim(),
      );
    }
  }

  String _formatExecutableName(String executable) =>
      executable[0].toUpperCase() + executable.substring(1);

  String _lastLine(String output) =>
      output.trim().split('\n').lastOrNull?.trim() ?? '';

  String _firstLine(String output) =>
      output.trim().split('\n').firstOrNull?.trim() ?? '';
}
