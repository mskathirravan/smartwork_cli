import 'dart:convert';
import 'dart:io';

import '../flutter/flutter_bootstrap.dart' show ProcessRunner;
import '../models/mock_mapping.dart';
import '../models/test_result.dart';
import 'mock_server.dart';

class TestExecutionService {
  final ProcessRunner _runProcess;

  TestExecutionService({ProcessRunner? runProcess})
      : _runProcess = runProcess ?? Process.run;

  Future<TestSuiteResult> run({
    required String projectPath,
    String? testTarget,
    bool coverage = false,
    MockServer? mockServer,
    List<MockMapping>? mappings,
  }) async {
    if (mockServer != null) {
      await mockServer.start();
      if (mappings != null && mappings.isNotEmpty) {
        await mockServer.loadMappings(mappings);
      }
    }

    try {
      final arguments = [
        'test',
        if (testTarget != null) testTarget,
        '--reporter=json',
        if (coverage) '--coverage',
      ];

      final stopwatch = Stopwatch()..start();
      final result = await _runFlutter(arguments, projectPath);
      stopwatch.stop();

      final stdout = result.stdout.toString();
      return TestSuiteResult(
        command: 'flutter ${arguments.join(' ')}',
        exitCode: result.exitCode,
        stdout: stdout,
        stderr: result.stderr.toString(),
        duration: stopwatch.elapsed,
        tests: _parseJsonReporter(stdout),
      );
    } finally {
      if (mockServer != null) {
        await mockServer.reset();
        await mockServer.stop();
      }
    }
  }

  Future<ProcessResult> _runFlutter(
    List<String> arguments,
    String projectPath,
  ) async {
    try {
      return await _runProcess(
        'flutter',
        arguments,
        workingDirectory: projectPath,
      );
    } on ProcessException catch (e) {
      return ProcessResult(
        0,
        -1,
        '',
        'the "flutter" executable was not found on PATH. (${e.message})',
      );
    }
  }

  List<TestResult> _parseJsonReporter(String stdout) {
    final suitePaths = <int, String>{};
    final testNames = <int, String>{};
    final testSuiteIds = <int, int>{};
    final testStartTimes = <int, int>{};
    final testLines = <int, int?>{};
    final testErrors = <int, List<String>>{};
    final testStackTraces = <int, List<String>>{};
    final results = <TestResult>[];

    for (final line in const LineSplitter().convert(stdout)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed[0] != '{') continue;

      final Map<String, dynamic> event;
      try {
        event = jsonDecode(trimmed) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      switch (event['type']) {
        case 'suite':
          final suite = event['suite'] as Map<String, dynamic>;
          suitePaths[suite['id'] as int] = suite['path'] as String? ?? '';

        case 'testStart':
          final test = event['test'] as Map<String, dynamic>;
          final id = test['id'] as int;
          testNames[id] = test['name'] as String? ?? '';
          testSuiteIds[id] = test['suiteID'] as int? ?? -1;
          testStartTimes[id] = event['time'] as int? ?? 0;
          testLines[id] = test['line'] as int?;

        case 'error':
          final id = event['testID'] as int?;
          if (id != null) {
            (testErrors[id] ??= []).add(event['error']?.toString() ?? '');
            (testStackTraces[id] ??= [])
                .add(event['stackTrace']?.toString() ?? '');
          }

        case 'testDone':
          if (event['hidden'] == true) continue;

          final id = event['testID'] as int;
          final suiteId = testSuiteIds[id];
          final suitePath = suiteId != null ? (suitePaths[suiteId] ?? '') : '';
          final skipped = event['skipped'] as bool? ?? false;
          final endTime = event['time'] as int? ?? 0;
          final startTime = testStartTimes[id] ?? endTime;
          final durationMs = endTime - startTime;
          final line = testLines[id];

          final status = skipped
              ? TestResultStatus.skipped
              : switch (event['result']) {
                  'success' => TestResultStatus.passed,
                  'failure' => TestResultStatus.failed,
                  'error' => TestResultStatus.error,
                  _ => TestResultStatus.error,
                };

          results.add(TestResult(
            suite: suitePath,
            test: testNames[id] ?? 'unknown',
            status: status,
            duration: Duration(
              milliseconds: durationMs < 0 ? 0 : durationMs,
            ),
            error: testErrors[id]?.join('\n'),
            stackTrace: testStackTraces[id]?.join('\n'),
            sourceLocation: line != null && suitePath.isNotEmpty
                ? '$suitePath:$line'
                : null,
          ));
      }
    }

    return results;
  }
}
