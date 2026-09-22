import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Real `dart test --reporter=json` output, captured verbatim from a
/// three-test file (one passing, one failing, one skipped) during this
/// milestone's own development — `flutter test` reuses the identical
/// JSON reporter for VM-targeted tests, so this is real ground truth,
/// not a guessed/hand-written fixture.
const _realJsonReporterOutput = '''
{"protocolVersion":"0.1.1","runnerVersion":"1.32.0","pid":64584,"type":"start","time":0}
{"suite":{"id":0,"platform":"vm","path":"test/sample_test.dart"},"type":"suite","time":0}
{"test":{"id":1,"name":"loading test/sample_test.dart","suiteID":0,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":null,"column":null,"url":null},"type":"testStart","time":1}
{"count":1,"time":7,"type":"allSuites"}
{"testID":1,"result":"success","skipped":false,"hidden":true,"type":"testDone","time":614}
{"group":{"id":2,"suiteID":0,"parentID":null,"name":"","metadata":{"skip":false,"skipReason":null},"testCount":3,"line":null,"column":null,"url":null},"type":"group","time":616}
{"test":{"id":3,"name":"passes","suiteID":0,"groupIDs":[2],"metadata":{"skip":false,"skipReason":null},"line":4,"column":3,"url":"file:///probe/test/sample_test.dart"},"type":"testStart","time":616}
{"testID":3,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":625}
{"test":{"id":4,"name":"fails","suiteID":0,"groupIDs":[2],"metadata":{"skip":false,"skipReason":null},"line":8,"column":3,"url":"file:///probe/test/sample_test.dart"},"type":"testStart","time":625}
{"testID":4,"error":"Expected: <3>\\n  Actual: <2>\\n","stackTrace":"package:matcher            expect\\ntest/sample_test.dart 9:5  main.<fn>\\n","isFailure":true,"type":"error","time":633}
{"testID":4,"result":"failure","skipped":false,"hidden":false,"type":"testDone","time":633}
{"test":{"id":5,"name":"skips","suiteID":0,"groupIDs":[2],"metadata":{"skip":true,"skipReason":"demo skip"},"line":12,"column":3,"url":"file:///probe/test/sample_test.dart"},"type":"testStart","time":634}
{"testID":5,"messageType":"skip","message":"Skip: demo skip","type":"print","time":634}
{"testID":5,"result":"success","skipped":true,"hidden":false,"type":"testDone","time":634}
{"success":false,"type":"done","time":638}
''';

void main() {
  group('TestExecutionService', () {
    test(
        'parses real JSON reporter output into normalized TestResults, '
        'excluding the hidden bookkeeping test', () async {
      final service = TestExecutionService(
        runProcess: (executable, arguments, {workingDirectory}) async =>
            ProcessResult(0, 1, _realJsonReporterOutput, ''),
      );

      final result = await service.run(projectPath: '/fake/project');

      expect(result.exitCode, 1);
      expect(result.passed, isFalse);
      expect(result.tests, hasLength(3));

      final passing = result.tests.firstWhere((t) => t.test == 'passes');
      expect(passing.status, TestResultStatus.passed);
      expect(passing.suite, 'test/sample_test.dart');
      expect(passing.sourceLocation, 'test/sample_test.dart:4');
      expect(passing.duration, const Duration(milliseconds: 9));

      final failing = result.tests.firstWhere((t) => t.test == 'fails');
      expect(failing.status, TestResultStatus.failed);
      expect(failing.error, contains('Expected: <3>'));
      expect(failing.stackTrace, contains('main.<fn>'));

      final skipped = result.tests.firstWhere((t) => t.test == 'skips');
      expect(skipped.status, TestResultStatus.skipped);

      expect(result.failures, hasLength(1));
      expect(result.failures.single.test, 'fails');
    });

    test(
        'builds the exact flutter test command, including --coverage '
        'and a scoped target', () async {
      List<String>? capturedArgs;
      final service = TestExecutionService(
        runProcess: (executable, arguments, {workingDirectory}) async {
          capturedArgs = arguments;
          return ProcessResult(0, 0, '', '');
        },
      );

      await service.run(
        projectPath: '/fake/project',
        testTarget: 'test/features/auth/',
        coverage: true,
      );

      expect(
        capturedArgs,
        ['test', 'test/features/auth/', '--reporter=json', '--coverage'],
      );
    });

    test('ignores a non-JSON line mixed into stdout without crashing',
        () async {
      final service = TestExecutionService(
        runProcess: (executable, arguments, {workingDirectory}) async =>
            ProcessResult(
          0,
          0,
          'Waiting for another flutter command to release the startup lock...\n'
              '$_realJsonReporterOutput',
          '',
        ),
      );

      final result = await service.run(projectPath: '/fake/project');
      expect(result.tests, hasLength(3));
    });

    test(
        'starts and always stops a MockServer, even when the test run '
        'itself fails', () async {
      final events = <String>[];
      final mockServer = _RecordingMockServer(events);

      final service = TestExecutionService(
        runProcess: (executable, arguments, {workingDirectory}) async {
          events.add('flutter test');
          return ProcessResult(0, 1, '', '');
        },
      );

      final result = await service.run(
        projectPath: '/fake/project',
        mockServer: mockServer,
      );

      expect(result.exitCode, 1);
      expect(events, ['start', 'flutter test', 'reset', 'stop']);
    });

    test(
        'loads mappings after starting the MockServer, before running '
        'tests', () async {
      final events = <String>[];
      final mockServer = _RecordingMockServer(events);

      final service = TestExecutionService(
        runProcess: (executable, arguments, {workingDirectory}) async {
          events.add('flutter test');
          return ProcessResult(0, 0, '', '');
        },
      );

      await service.run(
        projectPath: '/fake/project',
        mockServer: mockServer,
        mappings: [
          MockMapping(
            name: 'login',
            method: 'POST',
            urlPath: '/login',
            responseStatus: 200,
          ),
        ],
      );

      expect(
          events, ['start', 'loadMappings', 'flutter test', 'reset', 'stop']);
    });

    test(
        'gracefully reports a missing flutter executable as a failing '
        'TestSuiteResult, rather than letting ProcessException escape — '
        'the same treatment ProjectValidator/FlutterBootstrap already '
        'give every other flutter/dart invocation', () async {
      final service = TestExecutionService(
        runProcess: (executable, arguments, {workingDirectory}) async {
          throw const ProcessException('flutter', ['test']);
        },
      );

      final result = await service.run(projectPath: '/fake/project');

      expect(result.passed, isFalse);
      expect(result.exitCode, -1);
      expect(result.stderr, contains('not found on PATH'));
    });

    test(
        'stops the MockServer even when the process itself throws an '
        'exception this service does not specially handle', () async {
      final events = <String>[];
      final mockServer = _RecordingMockServer(events);

      final service = TestExecutionService(
        runProcess: (executable, arguments, {workingDirectory}) async {
          throw StateError('something unrelated went wrong');
        },
      );

      await expectLater(
        service.run(projectPath: '/fake/project', mockServer: mockServer),
        throwsA(isA<StateError>()),
      );

      expect(events, ['start', 'reset', 'stop']);
    });
  });
}

class _RecordingMockServer implements MockServer {
  final List<String> events;

  _RecordingMockServer(this.events);

  @override
  Future<void> start() async => events.add('start');

  @override
  Future<void> stop() async => events.add('stop');

  @override
  Future<bool> isReady() async => true;

  @override
  Future<void> loadMappings(List<MockMapping> mappings) async =>
      events.add('loadMappings');

  @override
  Future<void> reset() async => events.add('reset');
}
