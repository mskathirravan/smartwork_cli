import 'dart:io';

/// Thrown when `flutter create` can't run or fails.
class FlutterBootstrapException implements Exception {
  /// What went wrong, including `flutter create`'s output.
  final String message;

  /// An error described by [message].
  FlutterBootstrapException(this.message);

  @override
  String toString() => 'Flutter bootstrap failed: $message';
}

/// Runs a command, like [Process.run]; replaceable in tests.
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

/// The default [ProcessRunner]. On Windows `flutter` is `flutter.bat`,
/// which [Process.run] can only launch through a shell.
Future<ProcessResult> runSystemProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: Platform.isWindows,
  );
}

/// Creates the Flutter project SmartWork generates into, with
/// `flutter create`.
class FlutterBootstrap {
  final ProcessRunner _runProcess;

  /// A bootstrap; [runProcess] replaces how commands run (e.g. in tests).
  FlutterBootstrap({ProcessRunner? runProcess})
      : _runProcess = runProcess ?? runSystemProcess;

  /// Runs `flutter create` for [projectName] in [targetPath], for the
  /// given [platforms] (all when omitted). Throws
  /// [FlutterBootstrapException] on failure.
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
