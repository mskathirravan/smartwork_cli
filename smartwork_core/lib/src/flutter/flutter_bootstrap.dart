import 'dart:io';

class FlutterBootstrapException implements Exception {
  final String message;

  FlutterBootstrapException(this.message);

  @override
  String toString() => 'Flutter bootstrap failed: $message';
}

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

class FlutterBootstrap {
  final ProcessRunner _runProcess;

  FlutterBootstrap({ProcessRunner? runProcess})
      : _runProcess = runProcess ?? Process.run;

  Future<void> create({
    required String projectName,
    required String targetPath,
    Set<String>? platforms,
  }) async {
    final ProcessResult result;
    try {
      result = await _runProcess(
        'flutter',
        [
          'create',
          '--project-name',
          projectName,
          if (platforms != null && platforms.isNotEmpty)
            '--platforms=${platforms.join(',')}',
          targetPath,
        ],
      );
    } on ProcessException catch (e) {
      throw FlutterBootstrapException(
        'the "flutter" executable was not found on PATH. Install '
        'Flutter (https://flutter.dev) and ensure "flutter" is '
        'available before running smartwork init. (${e.message})',
      );
    }

    if (result.exitCode != 0) {
      final output = '${result.stdout}\n${result.stderr}'.trim();
      throw FlutterBootstrapException(
        'flutter create exited with code ${result.exitCode}.'
        '${output.isEmpty ? '' : '\n$output'}',
      );
    }
  }
}
