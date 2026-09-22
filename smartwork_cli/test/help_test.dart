import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:smartwork_cli/src/commands/discover_command.dart';
import 'package:smartwork_cli/src/commands/doctor_command.dart';
import 'package:smartwork_cli/src/commands/feature_command.dart';
import 'package:smartwork_cli/src/commands/icon_command.dart';
import 'package:smartwork_cli/src/commands/init_command.dart';
import 'package:smartwork_cli/src/commands/model_command.dart';
import 'package:smartwork_cli/src/commands/splash_command.dart';
import 'package:smartwork_cli/src/commands/target_command.dart';
import 'package:smartwork_cli/src/commands/test_command.dart';
import 'package:smartwork_cli/src/commands/update_command.dart';
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

CommandRunner _newRunner() {
  return CommandRunner(
    'smartwork',
    'Smartwork: Flutter project architecture generator',
  )
    ..addCommand(DiscoverCommand())
    ..addCommand(DoctorCommand())
    ..addCommand(FeatureCommand())
    ..addCommand(IconCommand())
    ..addCommand(InitCommand())
    ..addCommand(ModelCommand())
    ..addCommand(SplashCommand())
    ..addCommand(TargetCommand())
    ..addCommand(TestCommand())
    ..addCommand(UpdateCommand())
    ..addCommand(VersionCommand());
}

/// `smartwork --help` / `smartwork help` are both backed entirely by
/// `package:args`' `CommandRunner` — one centralized help source, never
/// a second hand-written help string to keep in sync (see
/// `bin/smartwork.dart`: no `HelpCommand`/custom usage renderer is
/// registered; `CommandRunner` provides both automatically from each
/// registered `Command`'s own `name`/`description`).
void main() {
  group('smartwork --help / smartwork help', () {
    test('--help and the bare help command produce identical output', () async {
      final helpFlagOutput = await _captureOutput(
        () => _newRunner().run(['--help']),
      );
      final helpCommandOutput = await _captureOutput(
        () => _newRunner().run(['help']),
      );

      expect(helpFlagOutput, helpCommandOutput);
    });

    test('lists every actually-registered command with a description',
        () async {
      final output = await _captureOutput(
        () => _newRunner().run(['--help']),
      );
      final text = output.join('\n');

      expect(text, contains('init'));
      expect(text, contains('feature'));
      expect(text, contains('target'));
      expect(text, contains('splash'));
      expect(text, contains('model'));
      expect(text, contains('icon'));
      expect(text, contains('discover'));
      expect(text, contains('doctor'));
      expect(text, contains('test'));
      expect(text, contains('update'));
      expect(text, contains('version'));

      // Every registered command's own description text appears too —
      // not just the bare command name.
      expect(text, contains('Initialize a new Smartwork project'));
      expect(text, contains('Generate a new feature'));
      expect(
          text,
          contains("Change an existing SmartWork project's App "
              'Targets'));
      expect(
          text,
          contains('Add or reconfigure the Splash Screen in the current '
              'project'));
      expect(text, contains('Generate Dart models inside an existing feature'));
      expect(
          text,
          contains('Generate the App Icon (Android, iOS, macOS, Web) '
              'from a single square source image'));
      expect(
          text,
          contains('Build a machine-readable understanding of an '
              'existing project'));
      expect(
          text,
          contains('Check whether the SmartWork and Flutter '
              'environment is ready'));
      expect(text, contains('Update the installed SmartWork CLI itself'));
      expect(text, contains('Print the installed SmartWork CLI version'));
      expect(
          text,
          contains('Analyze, generate, and maintain tests for an '
              'existing feature'));
    });

    test(
        'lists commands in alphabetical order, matching '
        "package:args' own CommandRunner behavior", () async {
      final output = await _captureOutput(
        () => _newRunner().run(['--help']),
      );
      final text = output.join('\n');

      final commandNames = [
        'doctor',
        'feature',
        'icon',
        'init',
        'model',
        'splash',
        'target',
        'test',
        'update',
        'version',
      ];
      final positions = commandNames.map((name) {
        final index = text.indexOf(RegExp('^  $name\\b', multiLine: true));
        expect(index, isNonNegative,
            reason: '"$name" must appear as a listed command');
        return index;
      }).toList();

      expect(positions, orderedEquals([...positions]..sort()),
          reason: 'commands must be listed alphabetically: $commandNames');

      // Every command appears exactly once — package:args itself would
      // reject a duplicate registration, but this also guards against
      // one being listed twice in the rendered help text.
      for (final name in commandNames) {
        final matches =
            RegExp('^  $name\\b', multiLine: true).allMatches(text).length;
        expect(matches, 1, reason: '"$name" must be listed exactly once');
      }
    });

    test(
        'smartwork model --help lists from-json as a real subcommand, and '
        'smartwork model from-json --help shows its own distinct '
        'description and --feature option', () async {
      final modelHelp = await _captureOutput(
        () => _newRunner().run(['model', '--help']),
      );
      final modelText = modelHelp.join('\n');
      expect(modelText, contains('from-json'));
      expect(modelText,
          contains('Generate Dart models inside an existing feature'));

      final fromJsonHelp = await _captureOutput(
        () => _newRunner().run(['model', 'from-json', '--help']),
      );
      final fromJsonText = fromJsonHelp.join('\n');
      expect(
          fromJsonText,
          contains('Generates a Dart model (and any nested models) from '
              'a JSON sample document'));
      expect(fromJsonText, contains('--feature'));
      expect(
          fromJsonText,
          contains('smartwork model from-json <json-file-path> --feature '
              '<feature-name>'));
    });

    test(
        'smartwork target --help and smartwork help target are also '
        'equivalent, for a subcommand', () async {
      final flagOutput = await _captureOutput(
        () => _newRunner().run(['target', '--help']),
      );
      final helpOutput = await _captureOutput(
        () => _newRunner().run(['help', 'target']),
      );

      expect(flagOutput, helpOutput);
      expect(flagOutput.join('\n'), contains('target'));
    });

    test(
        'never documents a command that was not actually implemented '
        'in this milestone', () async {
      final output = await _captureOutput(
        () => _newRunner().run(['--help']),
      );
      final text = output.join('\n');

      for (final unimplemented in ['adopt', 'migrate', 'build']) {
        expect(text, isNot(contains(unimplemented)),
            reason: '"$unimplemented" is not implemented and must not '
                'appear in help output');
      }
    });

    test('shows the SmartWork name/description and a usage line', () async {
      final output = await _captureOutput(
        () => _newRunner().run(['--help']),
      );
      final text = output.join('\n');

      expect(text, contains('Smartwork'));
      expect(text, contains('Usage:'));
      expect(text, contains('smartwork <command>'));
    });

    test('points to per-command help as the usage example', () async {
      final output = await _captureOutput(
        () => _newRunner().run(['--help']),
      );
      final text = output.join('\n');

      expect(text, contains('smartwork help <command>'));
    });

    test(
        'smartwork feature --help and smartwork help feature are also '
        'equivalent, for a subcommand', () async {
      final flagOutput = await _captureOutput(
        () => _newRunner().run(['feature', '--help']),
      );
      final helpOutput = await _captureOutput(
        () => _newRunner().run(['help', 'feature']),
      );

      expect(flagOutput, helpOutput);
      expect(flagOutput.join('\n'), contains('feature'));
    });
  });
}
