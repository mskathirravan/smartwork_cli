@Tags(['cli-exit-code'])
import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/update_command.dart';
import 'package:test/test.dart';

/// Runs [body], capturing everything printed via `print()` during it.
Future<List<String>> _captureOutput(Future<void> Function() body) async {
  final lines = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines;
}

/// Runs `smartwork update` through a real [CommandRunner] (exactly as
/// `bin/smartwork.dart` does), saving/restoring the process-global
/// `exitCode` around it — the same pattern `doctor_command_test.dart`
/// already establishes.
Future<(List<String>, int)> _run(UpdateCommand command) async {
  final runner = CommandRunner('smartwork', 'test')..addCommand(command);
  final previousExitCode = exitCode;
  exitCode = 0;
  final output = await _captureOutput(() => runner.run(['update']));
  final result = exitCode;
  exitCode = previousExitCode;
  return (output, result);
}

void main() {
  group('UpdateCommand', () {
    late Directory tempCheckout;

    setUp(() {
      tempCheckout =
          Directory.systemTemp.createTempSync('smartwork_update_test_');
      File('${tempCheckout.path}/pubspec.yaml')
          .writeAsStringSync('name: smartwork_cli\nversion: 0.1.0\n');
    });

    tearDown(() => tempCheckout.deleteSync(recursive: true));

    test(
        'constructs the correct update commands (git pull, then dart pub '
        'global activate --source path .) against its own source '
        'checkout, and never touches any Flutter project directory', () async {
      final calls = <(String, List<String>, String?)>[];

      final (output, exitCode) = await _run(
        UpdateCommand(
          sourceDirectory: tempCheckout,
          runProcess: (executable, arguments, {workingDirectory}) async {
            calls.add((executable, arguments, workingDirectory));
            return ProcessResult(0, 0, 'ok', '');
          },
        ),
      );

      expect(calls, hasLength(2));
      expect(calls[0].$1, 'git');
      expect(calls[0].$2, ['pull']);
      expect(calls[0].$3, tempCheckout.path);
      expect(calls[1].$1, 'dart');
      expect(
          calls[1].$2, ['pub', 'global', 'activate', '--source', 'path', '.']);
      expect(calls[1].$3, tempCheckout.path);

      expect(exitCode, 0);
      expect(output.join('\n'), contains('updated successfully'));

      // Never a Flutter-project-shaped mutation: no pubspec.yaml write,
      // no lib/ touch, no project directory referenced by either call.
      expect(
        calls.every((c) => c.$3 == tempCheckout.path),
        isTrue,
        reason: 'every process call must run inside the CLI\'s own '
            'source checkout, never a project directory',
      );
    });

    test(
        'propagates a real git pull failure: non-zero exit, no pub '
        'activate attempted, real output surfaced', () async {
      final calls = <String>[];

      final (output, exitCode) = await _run(
        UpdateCommand(
          sourceDirectory: tempCheckout,
          runProcess: (executable, arguments, {workingDirectory}) async {
            calls.add(executable);
            if (executable == 'git') {
              return ProcessResult(
                  0,
                  1,
                  '',
                  'fatal: could not read from '
                      'remote repository');
            }
            return ProcessResult(0, 0, '', '');
          },
        ),
      );

      expect(calls, ['git'],
          reason: 'pub activate must never run after a '
              'failed pull');
      expect(exitCode, 1);
      expect(
        output.join('\n'),
        contains('could not read from remote repository'),
      );
      expect(output.join('\n'), contains('failed'));
    });

    test(
        'propagates a real activate failure: non-zero exit, real output '
        'surfaced, after a successful pull', () async {
      final (output, exitCode) = await _run(
        UpdateCommand(
          sourceDirectory: tempCheckout,
          runProcess: (executable, arguments, {workingDirectory}) async {
            if (executable == 'git') return ProcessResult(0, 0, '', '');
            return ProcessResult(0, 2, '', 'version solving failed');
          },
        ),
      );

      expect(exitCode, 2);
      expect(output.join('\n'), contains('version solving failed'));
      expect(output.join('\n'), contains('failed'));
    });

    test(
        'never silently swallows a failure — a non-zero result always '
        'produces both a non-zero exit code and visible output', () async {
      final (output, exitCode) = await _run(
        UpdateCommand(
          sourceDirectory: tempCheckout,
          runProcess: (executable, arguments, {workingDirectory}) async {
            return ProcessResult(0, 17, '', 'boom');
          },
        ),
      );

      expect(exitCode, isNot(0));
      expect(output, isNotEmpty);
    });

    test(
        'reports a clear failure and never runs git/pub at all when the '
        'given directory is not genuinely smartwork_cli\'s own source '
        'checkout — never guesses or operates on an unrelated directory',
        () async {
      final unrelatedDir =
          Directory.systemTemp.createTempSync('smartwork_update_unrelated_');
      addTearDown(() => unrelatedDir.deleteSync(recursive: true));
      var ran = false;

      final (output, exitCode) = await _run(
        UpdateCommand(
          sourceDirectory: unrelatedDir,
          runProcess: (executable, arguments, {workingDirectory}) async {
            ran = true;
            return ProcessResult(0, 0, '', '');
          },
        ),
      );

      expect(ran, isFalse);
      expect(exitCode, isNot(0));
      expect(output.join('\n'), contains('could not locate'));
    });
  });
}
