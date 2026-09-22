import 'package:smartwork_cli/src/commands/feature_command.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureCommand', () {
    late FeatureCommand command;

    setUp(() {
      command = FeatureCommand();
    });

    test('has correct name and description', () {
      expect(command.name, equals('feature'));
      expect(command.description, contains('feature'));
    });

    test('is a valid command', () {
      expect(command.name, isNotEmpty);
      expect(command.description, isNotEmpty);
    });
  });
}
