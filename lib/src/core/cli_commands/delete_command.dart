import 'dart:io';

import '../utils/log_utils.dart';
import 'operations/operations.dart';
import 'smartwork_command.dart';

final featuresPath = 'lib/features';

class DeleteCommand extends SmartworkCommand {
  @override
  String get name => 'delete';
  @override
  String get description => 'Delete folder from features folder';

  DeleteCommand() {
    argParser
      ..addOption('type', abbr: 't', help: 'Type of deletion (feature)')
      ..addOption('name', abbr: 'n', help: 'Name of the feature to delete');
  }

  @override
  Future<void> execute() async {
    final type = argResults!['type'] as String?;
    final name = argResults!['name'] as String?;

    if (type == 'feature') {
      if (name != null) {
        await deleteFeature(name);
      } else {
        LogService.error('Please provide a name for the feature using --name');
      }
    } else {
      LogService.error('Invalid type. Use --type with "feature"');
    }
  }

  Future<void> deleteFeature(String featureName) async {
    if (Operations.folderExists(
        directoryPath: featuresPath, folderName: featureName)) {
      LogService.info('Are you sure you want to delete $name? (yes/no)');
      String userInput = stdin.readLineSync() ?? '';
      if (userInput.toLowerCase() == 'yes' || userInput.toLowerCase() == 'y') {
        if (await Operations.deleteFolder(
            directoryPath: featuresPath, folderName: featureName)) {
          LogService.success('Feature $featureName deleted successfully.');
        } else {
          LogService.error('Feature $featureName does not exist.');
        }
      } else {
        LogService.info('Deletion canceled by user.');
        return;
      }
    } else {
      LogService.error('Feature $featureName does not exist.');
    }
  }
}
