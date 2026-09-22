import 'package:smartwork_cli/src/commands/init_command.dart';
import 'package:test/test.dart';

void main() {
  group('InitCommand', () {
    late InitCommand command;

    setUp(() {
      command = InitCommand();
    });

    test('has correct name and description', () {
      expect(command.name, equals('init'));
      expect(command.description, contains('Initialize'));
    });

    test('is a valid command', () {
      expect(command.name, isNotEmpty);
      expect(command.description, isNotEmpty);
    });
  });
}
