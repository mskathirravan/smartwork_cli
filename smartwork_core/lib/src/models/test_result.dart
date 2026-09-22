enum TestResultStatus { passed, failed, skipped, error }

class TestResult {
  final String suite;
  final String test;
  final TestResultStatus status;
  final Duration duration;
  final String? error;
  final String? stackTrace;

  final String? sourceLocation;

  TestResult({
    required this.suite,
    required this.test,
    required this.status,
    required this.duration,
    this.error,
    this.stackTrace,
    this.sourceLocation,
  });

  Map<String, dynamic> toJson() => {
        'suite': suite,
        'test': test,
        'status': status.name,
        'durationMs': duration.inMilliseconds,
        'error': error,
        'stackTrace': stackTrace,
        'sourceLocation': sourceLocation,
      };
}

class TestSuiteResult {
  final String command;
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  final List<TestResult> tests;

  TestSuiteResult({
    required this.command,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
    required this.tests,
  });

  bool get passed => exitCode == 0;

  List<TestResult> get failures => tests
      .where((t) =>
          t.status == TestResultStatus.failed ||
          t.status == TestResultStatus.error)
      .toList();

  Map<String, dynamic> toJson() => {
        'command': command,
        'exitCode': exitCode,
        'durationMs': duration.inMilliseconds,
        'passed': passed,
        'tests': tests.map((t) => t.toJson()).toList(),
        'failureCount': failures.length,
      };
}
