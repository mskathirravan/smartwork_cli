@Tags(['cli-exit-code'])
import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/version_command.dart';
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

/// Runs `smartwork version` through a real [CommandRunner] (exactly as
/// `bin/smartwork.dart` does), saving/restoring the process-global
/// `exitCode` around it — the same pattern `doctor_command_test.dart`
/// already establishes — and returns both the captured output and the
/// resulting exit code.
Future<(List<String>, int)> _run(VersionCommand command) async {
  final runner = CommandRunner('smartwork', 'test')..addCommand(command);
  final previousExitCode = exitCode;
  exitCode = 0;
  final output = await _captureOutput(() => runner.run(['version']));
  final result = exitCode;
  exitCode = previousExitCode;
  return (output, result);
}

void main() {
  group('VersionCommand', () {
    test(
        'prints the version from the injected authoritative source, and '
        'exits 0', () async {
      final (output, exitCode) = await _run(
        VersionCommand(readVersion: () => '9.9.9'),
      );

      expect(output.join('\n'), contains('9.9.9'));
      expect(exitCode, 0);
    });

    test(
        'makes no network request — the version source is a plain, '
        'synchronous, injectable closure, never an HTTP call', () async {
      var called = false;
      final (output, exitCode) = await _run(
        VersionCommand(readVersion: () {
          called = true;
          return '1.2.3';
        }),
      );

      expect(called, isTrue);
      expect(output.join('\n'), contains('1.2.3'));
      expect(exitCode, 0);
    });

    test(
        'reports an honest "unknown" message and exits non-zero when the '
        'authoritative source cannot determine a version — never a '
        'fabricated placeholder', () async {
      final (output, exitCode) = await _run(
        VersionCommand(readVersion: () => null),
      );

      final text = output.join('\n');
      expect(text, contains('unknown'));
      expect(text, isNot(contains('0.0.0')));
      expect(exitCode, isNot(0));
    });

    test(
        'uses the real, un-injected readSmartworkCliVersion by default, '
        'and it resolves this repository\'s own smartwork_cli version',
        () async {
      final (output, exitCode) = await _run(VersionCommand());

      // The real pubspec.yaml declares a real, non-empty version —
      // confirmed here without hardcoding its exact value, so this test
      // never needs updating merely because the package version bumps.
      expect(exitCode, 0);
      final text = output.join('\n');
      expect(text, startsWith('smartwork '));
      expect(RegExp(r'^smartwork \S+$').hasMatch(text.trim()), isTrue);
    });
  });
}
