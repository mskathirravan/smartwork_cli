import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Tests for [FlutterBootstrap] — the sole responsibility of invoking
/// `flutter create`. A fake [ProcessRunner] stands in for the real
/// `flutter` executable throughout: these tests must never depend on a
/// real Flutter invocation (see the Flutter Project Foundation V1
/// milestone). Real end-to-end proof that a real `flutter create`
/// produces a real, buildable Flutter project happens separately,
/// against real generated projects in `tmp/`.
void main() {
  group('FlutterBootstrap', () {
    test(
        'command construction: passes the correct executable, '
        'subcommand, project name, and target path', () async {
      String? capturedExecutable;
      List<String>? capturedArguments;

      final bootstrap = FlutterBootstrap(
        runProcess: (executable, arguments, {workingDirectory}) async {
          capturedExecutable = executable;
          capturedArguments = arguments;
          return ProcessResult(0, 0, '', '');
        },
      );

      await bootstrap.create(
        projectName: 'my_app',
        targetPath: '/tmp/my_app',
      );

      expect(capturedExecutable, 'flutter');
      expect(capturedArguments,
          ['create', '--project-name', 'my_app', '/tmp/my_app']);
    });

    test(
        'failure: a non-zero exit code throws, surfacing the process '
        'output, without SmartWork continuing as if it succeeded', () async {
      final bootstrap = FlutterBootstrap(
        runProcess: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(
            0,
            1,
            '',
            'Invalid project name: "my app" is not a valid Dart package '
                'name.',
          );
        },
      );

      expect(
        () => bootstrap.create(projectName: 'my app', targetPath: '/tmp/x'),
        throwsA(isA<FlutterBootstrapException>().having(
          (e) => e.message,
          'message',
          contains('Invalid project name'),
        )),
      );
    });

    test('failure: exit code is reported even with no output', () async {
      final bootstrap = FlutterBootstrap(
        runProcess: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(0, 127, '', '');
        },
      );

      expect(
        () => bootstrap.create(projectName: 'my_app', targetPath: '/tmp/x'),
        throwsA(isA<FlutterBootstrapException>().having(
          (e) => e.message,
          'message',
          contains('127'),
        )),
      );
    });

    test(
        'Flutter unavailable: a ProcessException (executable not found) '
        'is surfaced as a clear FlutterBootstrapException, not a raw '
        'process error', () async {
      final bootstrap = FlutterBootstrap(
        runProcess: (executable, arguments, {workingDirectory}) async {
          throw const ProcessException(
              'flutter', [], 'No such file or directory');
        },
      );

      expect(
        () => bootstrap.create(projectName: 'my_app', targetPath: '/tmp/x'),
        throwsA(isA<FlutterBootstrapException>().having(
          (e) => e.message,
          'message',
          allOf(contains('not found'), contains('PATH')),
        )),
      );
    });

    test(
        'command construction: omitting platforms preserves the exact '
        'original argument list, requesting every Flutter-supported '
        'platform', () async {
      List<String>? capturedArguments;

      final bootstrap = FlutterBootstrap(
        runProcess: (executable, arguments, {workingDirectory}) async {
          capturedArguments = arguments;
          return ProcessResult(0, 0, '', '');
        },
      );

      await bootstrap.create(projectName: 'my_app', targetPath: '/tmp/my_app');

      expect(capturedArguments,
          ['create', '--project-name', 'my_app', '/tmp/my_app']);
    });

    test(
        'command construction: an empty platforms set is treated the '
        'same as omitting it — no --platforms flag is added', () async {
      List<String>? capturedArguments;

      final bootstrap = FlutterBootstrap(
        runProcess: (executable, arguments, {workingDirectory}) async {
          capturedArguments = arguments;
          return ProcessResult(0, 0, '', '');
        },
      );

      await bootstrap.create(
        projectName: 'my_app',
        targetPath: '/tmp/my_app',
        platforms: {},
      );

      expect(capturedArguments,
          ['create', '--project-name', 'my_app', '/tmp/my_app']);
    });

    test(
        'command construction: a non-empty platforms set is passed as a '
        'single comma-separated --platforms flag', () async {
      List<String>? capturedArguments;

      final bootstrap = FlutterBootstrap(
        runProcess: (executable, arguments, {workingDirectory}) async {
          capturedArguments = arguments;
          return ProcessResult(0, 0, '', '');
        },
      );

      await bootstrap.create(
        projectName: 'my_app',
        targetPath: '/tmp/my_app',
        platforms: {'android', 'ios', 'web'},
      );

      expect(capturedArguments, hasLength(5));
      expect(capturedArguments![0], 'create');
      expect(capturedArguments![1], '--project-name');
      expect(capturedArguments![2], 'my_app');
      expect(capturedArguments![3], startsWith('--platforms='));
      expect(capturedArguments![4], '/tmp/my_app');
      final requested =
          capturedArguments![3].substring('--platforms='.length).split(',');
      expect(requested.toSet(), {'android', 'ios', 'web'});
    });

    test(
        'success: completes normally and never throws when the process '
        'exits 0', () async {
      final bootstrap = FlutterBootstrap(
        runProcess: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(0, 0, 'Creating project...', '');
        },
      );

      await expectLater(
        bootstrap.create(projectName: 'my_app', targetPath: '/tmp/my_app'),
        completes,
      );
    });
  });
}
