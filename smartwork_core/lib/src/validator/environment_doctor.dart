import 'dart:io';

import '../flutter/flutter_bootstrap.dart';

class EnvironmentCheck {
  final String label;
  final bool passed;
  final String? detail;

  EnvironmentCheck({required this.label, required this.passed, this.detail});
}

class EnvironmentDoctor {
  final ProcessRunner _runProcess;

  EnvironmentDoctor({ProcessRunner? runProcess})
      : _runProcess = runProcess ?? Process.run;

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

    return results;
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

  String _firstLine(String output) =>
      output.trim().split('\n').firstOrNull?.trim() ?? '';
}
