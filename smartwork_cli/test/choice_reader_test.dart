import 'dart:async';

import 'package:smartwork_cli/src/commands/choice_reader.dart';
import 'package:test/test.dart';

/// Feeds [lines] to [readChoice] one per read (null once exhausted, like a
/// closed stdin) and captures what it prints.
({T choice, List<String> output}) _read<T>(
  List<String?> lines,
  List<T> options, {
  Map<String, T> aliases = const {},
}) {
  final remaining = [...lines];
  final output = <String>[];
  final choice = runZoned(
    () => readChoice(
      'Select: ',
      options,
      aliases: aliases,
      readLine: () => remaining.isEmpty ? null : remaining.removeAt(0),
    ),
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => output.add(line),
    ),
  );
  return (choice: choice, output: output);
}

void main() {
  group('readChoice', () {
    test('returns the option for a valid 1-based number', () {
      final result = _read(['2'], ['a', 'b', 'c']);
      expect(result.choice, 'b');
      expect(result.output, isEmpty);
    });

    test(
        'asks again on a typo instead of silently using a default '
        '(the "y" at Localization bug)', () {
      final result = _read(['y', '7', '', '3'], ['a', 'b', 'c']);
      expect(result.choice, 'c');
      expect(
        result.output,
        List.filled(3, '❌ Invalid selection. Enter a number from 1 to 3.'),
      );
    });

    test('accepts case-insensitive aliases such as y/n', () {
      final result = _read(
        [' YES '],
        [false, true],
        aliases: {'y': true, 'yes': true, 'n': false, 'no': false},
      );
      expect(result.choice, isTrue);
    });

    test(
        'throws InputClosedException when stdin ends, never looping or '
        'picking a default', () {
      expect(
        () => _read(['oops'], ['a', 'b']),
        throwsA(isA<InputClosedException>().having(
          (e) => e.toString(),
          'toString',
          contains('Nothing was changed'),
        )),
      );
    });
  });
}
