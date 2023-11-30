import 'model/model_generator.dart';
import 'smartwork_command.dart';

class GenerateCommand extends SmartworkCommand {
  GenerateCommand() {
    argParser
      ..addOption('model', abbr: 'm', help: 'Specify the model name')
      ..addOption('on',
          help: 'Specify where to generate the model (e.g., home)')
      ..addOption('with',
          help: 'Specify the path to the JSON file for model generation');
  }

  @override
  String get name => 'generate';
  @override
  String get description => 'Generate model class from the given path';

  @override
  Future<void> execute() async {
    final modelName = argResults!['model'] as String?;
    final on = argResults!['on'] as String?;
    final withPath = argResults!['with'] as String?;

    if (modelName != null && on != null && withPath != null) {
      print('Generating model $modelName on $on with $withPath...');
      ModelGenerator.generateModel(on, withPath);
    } else {
      print('Please provide --model, --on, and --with options');
    }
  }
}
