import 'dart:io';

import 'choice_reader.dart';

typedef TargetSelectionReader = String Function(String prompt);

String readTargetSelectionFromStdin(String prompt) {
  stdout.write(prompt);
  return readLineOrThrow();
}
