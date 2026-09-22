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
          ['Dart', 'Flutter executable', 'Flutter']);
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

    test('checks run in the fixed order: Dart, Flutter executable, Flutter',
        () async {
      final doctor = EnvironmentDoctor(
        runProcess: (executable, arguments, {workingDirectory}) async =>
            ProcessResult(0, 0, '', ''),
      );

      final results = await doctor.checkEnvironment();

      expect(
        results.map((c) => c.label).toList(),
        ['Dart', 'Flutter executable', 'Flutter'],
      );
    });
  });
}
