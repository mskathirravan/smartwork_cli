import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';

/// Prints one ✓/✗ line per validation phase. A failed phase is followed by
/// its captured output and, when SmartWork recognizes the cause, a hint.
void printValidationPhases(List<ValidationPhaseResult> phases) {
  for (final phase in phases) {
    print('${phase.passed ? '✓' : '✗'} ${phase.phase.label}');
    if (!phase.passed && phase.output.isNotEmpty) {
      print('');
      for (final line in phase.output.split('\n')) {
        print('    $line');
      }
    }
    if (phase.hint != null) {
      print('');
      print('⚠ ${phase.hint}');
    }
  }
}

/// Reads the project's pubspec.yaml, or null when there is none.
String? readPubspec(String projectPath) {
  final file = File(ProjectPaths(projectRoot: projectPath).pubspecFile);
  return file.existsSync() ? file.readAsStringSync() : null;
}

/// Runs `flutter pub get` when a command changed pubspec.yaml (compared
/// with [pubspecBefore]), so a package the local Flutter SDK can't resolve
/// is reported now — with an "update Flutter" hint — instead of at the
/// developer's next build. Sets a non-zero exit code on failure.
Future<void> resolveChangedDependencies(
  String projectPath,
  String? pubspecBefore,
  ProjectValidator validator,
) async {
  final pubspecAfter = readPubspec(projectPath);
  if (pubspecAfter == null || pubspecAfter == pubspecBefore) return;

  final result = await validator.resolveDependencies(projectPath);
  print('');
  if (result.passed) {
    print('✔ Dependencies resolved (flutter pub get).');
    return;
  }
  printValidationPhases([result]);
  exitCode = 1;
}
