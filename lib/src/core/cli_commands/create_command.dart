import 'dart:io';

import '../utils/log_utils.dart';
import 'feature_layers/data_structure.dart';
import 'feature_layers/domain_structure.dart';
import 'feature_layers/presentation_structure.dart';
import 'feature_layers/provider_structure.dart';
import 'operations/operations.dart';
import 'smartwork_command.dart';

var featuresPath = 'lib/features';

class CreateCommand extends SmartworkCommand {
  @override
  String get name => 'create';
  @override
  String get description =>
      'Create a flutter project or generate folder structure';

  CreateCommand() {
    argParser
      ..addOption('type',
          abbr: 't', help: 'Type of creation (project, feature)')
      ..addOption('name', abbr: 'n', help: 'Name of the project or feature');
  }

  @override
  Future<void> execute() async {
    final type = argResults!['type'] as String?;
    final name = argResults!['name'] as String?;

    if (type == 'project') {
      if (name != null) {
        // Check if the projectPath exists
        if (Directory(name).existsSync()) {
          LogService.error('The $name project already exists.');
          return;
        }
        await createFlutterProject(name);
      } else {
        LogService.info('Please provide a name for the project using --name');
      }
    } else if (type == 'feature') {
      if (name != null) {
        await createFeature(name);
      } else {
        LogService.info('Please provide a name for the feature using --name');
      }
    } else {
      LogService.info('Invalid type. Use --type with "project" or "feature"');
    }
  }

  Future<void> createFlutterProject(String projectName) async {
    final process = await Process.start(
      'flutter',
      ['create', projectName],
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await process.exitCode;
    if (exitCode == 0) {
      // final directoryPath = '${Directory.current.path}/$projectName';
      // featuresPath = '$directoryPath/lib/features';
      // InitCommand.configAppStructure(directoryPath: directoryPath);

      //     In order to run your application, type:

      // $ cd example_app
      // $ flutter run

      LogService.success(
          'Flutter project created successfully. Please run: \n cd $projectName \n flutter pub global run smartwork_cli init');
    } else {
      LogService.info('Failed to create Flutter project. Exit code: $exitCode');
    }
  }

  Future<void> createFeature(String featureName) async {
    if (Operations.folderExists(
        directoryPath: featuresPath, folderName: featureName)) {
      LogService.info(
          'The $featureName feature already exists. Do you want to overwrite it? (yes/no)');
      String userInput = stdin.readLineSync() ?? '';
      if (userInput.toLowerCase() == 'yes' || userInput.toLowerCase() == 'y') {
        generateFeature(directoryPath: featuresPath, folderName: featureName);
      } else {
        LogService.info('Creation canceled by user.');
        return;
      }
    } else {
      generateFeature(directoryPath: featuresPath, folderName: featureName);
    }
  }

  void generateFeature(
      {required String directoryPath, required String folderName}) {
    if (Operations.createFolder(
        directoryPath: directoryPath, folderName: folderName)) {
      DataStructure.createFeatureStructure(
          directoryPath: '$directoryPath/$folderName', featureName: folderName);
      DomainStructure.createFeatureStructure(
          directoryPath: '$directoryPath/$folderName', featureName: folderName);
      PresentationStructure.createFeatureStructure(
          directoryPath: '$directoryPath/$folderName', featureName: folderName);
      ProviderStructure.createFeatureStructure(
          directoryPath: '$directoryPath/$folderName', featureName: folderName);

      Operations.createFile(
          directoryPath: '$directoryPath/$folderName',
          fileName: '$folderName.dart',
          content: _exportFileContent(folderName));

      LogService.success('Feature $folderName created successfully.');
    } else {
      LogService.error('Error creating feature $folderName in $directoryPath');
    }
  }

  // export feature files
  static String _exportFileContent(String folderName) {
    return '''
    export 'data/remote/${folderName}_remote_data_source.dart';
    export 'data/local/${folderName}_local_data_source.dart';
    export 'data/${folderName}_repository.dart';

    export 'domain/models/${folderName}_model.dart';
    export 'domain/use_case/${folderName}_use_case.dart';

    export 'presentation/screen/${folderName}_screen.dart';

    export 'provider/${folderName}_provider.dart';
    ''';
  }
}
