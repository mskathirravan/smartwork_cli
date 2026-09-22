import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_core/smartwork_core.dart';

class ModelCommand extends Command {
  ModelCommand({String projectPath = '.'}) {
    addSubcommand(FromJsonCommand(projectPath: projectPath));
  }

  @override
  final name = 'model';

  @override
  final description = 'Generate Dart models inside an existing feature';
}

class FromJsonCommand extends Command {
  final String projectPath;

  FromJsonCommand({this.projectPath = '.'}) {
    argParser.addOption(
      'feature',
      help: 'The existing feature to generate the model(s) into.',
      valueHelp: 'feature-name',
    );
  }

  @override
  final name = 'from-json';

  @override
  final description = 'Generates a Dart model (and any nested models) from '
      'a JSON sample document inside an existing feature';

  @override
  String get invocation =>
      'smartwork model from-json <json-file-path> --feature <feature-name>';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      print('❌ JSON file path is required. Usage: $invocation');
      exitCode = 1;
      return;
    }
    final jsonFilePath = rest.first;

    final featureName = argResults!['feature'] as String?;
    if (featureName == null) {
      print('❌ --feature is required. Usage: $invocation');
      exitCode = 1;
      return;
    }

    try {
      final result = await ModelLifecycle().generateFromJson(
        projectPath: projectPath,
        jsonFilePath: jsonFilePath,
        featureName: featureName,
      );
      _reportSuccess(result);
    } on FileSystemException {
      print('❌ No Smartwork project found in the current directory.');
      print('   Run "smartwork init" first.');
      exitCode = 1;
    } on FeatureNotFoundException catch (e) {
      print('❌ $e');
      print('   Run "smartwork feature add ${e.featureName}" first.');
      exitCode = 1;
    } on JsonFileNotFoundException catch (e) {
      print('❌ $e');
      exitCode = 1;
    } on InvalidJsonException catch (e) {
      print('❌ $e');
      exitCode = 1;
    } on UnsupportedJsonRootException catch (e) {
      print('❌ $e');
      exitCode = 1;
    } on DuplicateModelClassNameException catch (e) {
      print('❌ $e');
      exitCode = 1;
    } on ModelFileCollisionException catch (e) {
      print('❌ $e');
      exitCode = 1;
    }
  }

  void _reportSuccess(ModelGenerationResult result) {
    print('✔ Model generated\n');
    print('Generated:');
    for (final file in result.generatedFiles) {
      print('  • $file');
    }
    print('');
    print('Classes: ${result.classNames.join(', ')}');
  }
}
