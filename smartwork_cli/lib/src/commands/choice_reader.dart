import 'dart:io';

/// Thrown when stdin ends (Ctrl-D, or piped input running out) while a
/// prompt still needs an answer. Prompts run before anything is written,
/// so nothing has been changed.
class InputClosedException implements Exception {
  @override
  String toString() =>
      'Input ended before every question was answered. Nothing was changed.';
}

/// The next stdin line, or [InputClosedException] once stdin has ended — so
/// a prompt that asks again on an invalid answer can't loop forever.
String readLineOrThrow() =>
    stdin.readLineSync() ?? (throw InputClosedException());

/// Reads a line for a numbered menu: returns the option for a number from
/// 1 to `options.length`, or for one of [aliases] (case-insensitive, e.g.
/// 'y'/'n'). Anything else asks again, so a typo is never silently
/// replaced by a default. Throws [InputClosedException] if stdin ends.
T readChoice<T>(
  String prompt,
  List<T> options, {
  Map<String, T> aliases = const {},
  String? Function() readLine = _readStdinLine,
}) {
  while (true) {
    stdout.write(prompt);
    final line = readLine();
    if (line == null) throw InputClosedException();

    final input = line.trim().toLowerCase();
    final alias = aliases[input];
    if (alias != null) return alias;

    final index = int.tryParse(input);
    if (index != null && index >= 1 && index <= options.length) {
      return options[index - 1];
    }
    print('❌ Invalid selection. Enter a number from 1 to ${options.length}.');
  }
}

String? _readStdinLine() => stdin.readLineSync();
