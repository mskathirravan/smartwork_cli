import 'dart:io';

typedef TargetSelectionReader = String Function(String prompt);

String readTargetSelectionFromStdin(String prompt) {
  stdout.write(prompt);
  return stdin.readLineSync() ?? '';
}
