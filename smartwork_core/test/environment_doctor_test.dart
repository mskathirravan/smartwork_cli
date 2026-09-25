import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// [EnvironmentDoctor] — the environment-readiness capability extracted
/// (V1 MCP-0) so `smartwork_cli`'s `doctor` command and `smartwork_mcp`'s
/// `smartwork_doctor` tool both check Dart/Flutter the same way, instead
/// of each reimplementing the same subprocess calls.
void main() {
  group('EnvironmentDoctor', () {
    test('reports Dart and Flutter passing when both are available', () async {
      final doctor = EnvironmentDoctor(
        runProcess: (executable, arguments, {workingDirectory}) async =>
            ProcessResult(0, 0, 'Dart SDK version: 3.13.0', ''),
      );

      final results = await doctor.checkEnvironment();

      expect(results.map((c) => c.label),
          ['Dart', 'Flutter executable', 'Flutter', 'Package compatibility']);
      expect(results.every((c) => c.passed), isTrue);
      expect(results.first.detail, 'Dart SDK version: 3.13.0');
    });

    test('fails the Dart check when the dart executable is not found',
        () async {
      final doctor = EnvironmentDoctor(
        runProcess: (executable, arguments, {workingDirectory}) async {
          if (executable == 'dart') {
            throw const ProcessException('dart', ['--version'], 'not found');
          }
          return ProcessResult(0, 0, 'Flutter 3.47.0', '');
        },
      );

      final results = await doctor.checkEnvironment();

      final dartCheck = results.firstWhere((c) => c.label == 'Dart');
      expect(dartCheck.passed, isFalse);
      expect(dartCheck.detail, contains('not found'));
    });

    test(
        'fails both "Flutter executable" and "Flutter" when the flutter '
        'executable is not found', () async {
      final doctor = EnvironmentDoctor(
        runProcess: (executable, arguments, {workingDirectory}) async {
          if (executable == 'flutter') {
            throw const ProcessException('flutter', ['--version'], 'not found');
          }
          return ProcessResult(0, 0, 'Dart SDK version: 3.13.0', '');
        },
      );

      final results = await doctor.checkEnvironment();

      final flutterExecutable =
          results.firstWhere((c) => c.label == 'Flutter executable');
      final flutter = results.firstWhere((c) => c.label == 'Flutter');
      expect(flutterExecutable.passed, isFalse);
      expect(flutter.passed, isFalse);
    });

    test(
        'passes "Flutter executable" but fails "Flutter" when flutter is '
        'found on PATH but exits non-zero', () async {
      final doctor = EnvironmentDoctor(
        runProcess: (executable, arguments, {workingDirectory}) async {
          if (executable == 'flutter') {
            return ProcessResult(0, 1, '', 'broken toolchain');
          }
          return ProcessResult(0, 0, 'Dart SDK version: 3.13.0', '');
        },
      );

      final results = await doctor.checkEnvironment();

      final flutterExecutable =
          results.firstWhere((c) => c.label == 'Flutter executable');
      final flutter = results.firstWhere((c) => c.label == 'Flutter');
      expect(flutterExecutable.passed, isTrue);
      expect(flutter.passed, isFalse);
      expect(flutter.detail, contains('exited with code 1'));
    });

    test(
        'checks run in the fixed order: Dart, Flutter executable, Flutter, '
        'Package compatibility', () async {
      final doctor = EnvironmentDoctor(
        runProcess: (executable, arguments, {workingDirectory}) async =>
            ProcessResult(0, 0, '', ''),
      );

      final results = await doctor.checkEnvironment();

      expect(
        results.map((c) => c.label).toList(),
        ['Dart', 'Flutter executable', 'Flutter', 'Package compatibility'],
      );
    });
  });

  group('EnvironmentDoctor — Package compatibility', () {
    Future<String> probe() async => 'name: smartwork_dependency_probe\n';

    EnvironmentDoctor doctorWithPubGet(ProcessResult pubGet,
        {void Function(String? cwd)? onPubGet}) {
      return EnvironmentDoctor(
        dependencyProbe: probe,
        runProcess: (executable, arguments, {workingDirectory}) async {
          if (arguments.join(' ') != 'pub get') {
            return ProcessResult(0, 0, '', '');
          }
          onPubGet?.call(workingDirectory);
          return pubGet;
        },
      );
    }

    test(
        'runs flutter pub get on the dependency probe inside a temporary '
        'directory, which is removed afterwards', () async {
      String? cwd;
      String? pubspec;
      final doctor = doctorWithPubGet(
        ProcessResult(0, 0, '', ''),
        onPubGet: (dir) {
          cwd = dir;
          pubspec = File('$dir/pubspec.yaml').readAsStringSync();
        },
      );

      final check = (await doctor.checkEnvironment()).last;

      expect(check.passed, isTrue);
      expect(pubspec, 'name: smartwork_dependency_probe\n');
      expect(Directory(cwd!).existsSync(), isFalse);
    });

    test('an out-of-date Flutter SDK fails with the "update Flutter" hint',
        () async {
      final doctor = doctorWithPubGet(ProcessResult(
        0,
        1,
        '',
        'The current Dart SDK version is 3.6.0.\n'
            'Because smartwork_dependency_probe depends on google_fonts '
            '>=6.3.1 which requires SDK version >=3.7.0 <4.0.0, version '
            'solving failed.',
      ));

      final check = (await doctor.checkEnvironment()).last;

      expect(check.label, 'Package compatibility');
      expect(check.passed, isFalse);
      expect(check.inconclusive, isFalse);
      expect(check.detail, contains('Flutter SDK is too old'));
      expect(check.detail, contains('your Dart SDK is 3.6.0'));
    });

    test(
        'an unrelated pub get failure (e.g. offline) is inconclusive, not '
        'a failure', () async {
      final doctor = doctorWithPubGet(ProcessResult(
        0,
        69,
        '',
        'Got socket error trying to find package dio at https://pub.dev.',
      ));

      final check = (await doctor.checkEnvironment()).last;

      expect(check.inconclusive, isTrue);
      expect(check.detail, contains('Could not check'));
    });

    test('is skipped when Flutter itself is unavailable', () async {
      final doctor = EnvironmentDoctor(
        dependencyProbe: probe,
        runProcess: (executable, arguments, {workingDirectory}) async {
          if (executable == 'flutter') {
            throw ProcessException(executable, arguments, 'not found');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      final results = await doctor.checkEnvironment();

      expect(results.map((c) => c.label),
          isNot(contains('Package compatibility')));
    });
  });
}
