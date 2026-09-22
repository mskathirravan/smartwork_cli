import 'dart:io';

typedef ConfirmationReader = bool Function(String prompt);

bool readConfirmationFromStdin(String prompt) {
  stdout.write(prompt);
  final input = stdin.readLineSync()?.trim().toLowerCase() ?? '';
  return input == 'y' || input == 'yes';
}
