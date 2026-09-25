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
      expect(output.join('\n'), contains('could not tell how this CLI'));
      expect(output.join('\n'),
          contains('dart pub global activate smartwork_cli'));
    });

    group('installed from pub.dev', () {
      late Directory globalPackage;

      setUp(() {
        // The layout `dart pub global activate smartwork_cli` leaves in
        // ~/.pub-cache/global_packages/smartwork_cli/: a snapshot and a
        // pubspec.lock recording smartwork_cli as hosted — no pubspec.yaml.
        globalPackage =
            Directory.systemTemp.createTempSync('smartwork_update_hosted_');
        File('${globalPackage.path}/pubspec.lock').writeAsStringSync('''
packages:
  smartwork_cli:
    dependency: "direct main"
    description:
      name: smartwork_cli
      sha256: "2a249e6e"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.2"
  smartwork_core:
    dependency: transitive
    description:
      name: smartwork_core
      url: "https://pub.dev"
    source: hosted
    version: "1.0.2"
''');
      });

      tearDown(() => globalPackage.deleteSync(recursive: true));

      test(
          're-activates the latest smartwork_cli from pub.dev — never runs '
          'git', () async {
        final calls = <String>[];

        final (output, exitCode) = await _run(
          UpdateCommand(
            sourceDirectory: globalPackage,
            runProcess: (executable, arguments, {workingDirectory}) async {
              calls.add('$executable ${arguments.join(' ')}');
              return ProcessResult(0, 0, 'Activated smartwork_cli 1.0.3.', '');
            },
          ),
        );

        expect(calls, ['dart pub global activate smartwork_cli']);
        expect(exitCode, 0);
        expect(output, contains('Activated smartwork_cli 1.0.3.'));
        expect(output.join('\n'), contains('updated successfully'));
      });

      test('says "already up to date" when pub.dev has nothing newer',
          () async {
        final (output, exitCode) = await _run(
          UpdateCommand(
            sourceDirectory: globalPackage,
            runProcess: (executable, arguments, {workingDirectory}) async =>
                ProcessResult(
              0,
              0,
              'The package smartwork_cli is already activated at newest '
                  'available version.\nActivated smartwork_cli 1.0.2.',
              '',
            ),
          ),
        );

        expect(exitCode, 0);
        expect(output, contains('SmartWork CLI is already up to date.'));
      });

      test('reports a failed activation (e.g. offline) with a non-zero exit',
          () async {
        final (output, exitCode) = await _run(
          UpdateCommand(
            sourceDirectory: globalPackage,
            runProcess: (executable, arguments, {workingDirectory}) async =>
                ProcessResult(0, 69, '', 'Got socket error.'),
          ),
        );

        expect(exitCode, 69);
        expect(output, contains('Got socket error.'));
        expect(output.join('\n'), contains('update failed'));
      });

      test(
          'a path-activated install\'s pubspec.lock (source: path) is not '
          'mistaken for a pub.dev install', () async {
        File('${globalPackage.path}/pubspec.lock').writeAsStringSync('''
packages:
  smartwork_cli:
    dependency: "direct main"
    description:
      path: "/src/smartwork/smartwork_cli"
      relative: false
    source: path
    version: "1.0.2"
''');
        var ran = false;

        final (_, exitCode) = await _run(
          UpdateCommand(
            sourceDirectory: globalPackage,
            runProcess: (executable, arguments, {workingDirectory}) async {
              ran = true;
              return ProcessResult(0, 0, '', '');
            },
          ),
        );

        expect(ran, isFalse);
        expect(exitCode, isNot(0));
      });
    });
  });
}
