import '../operations/operations.dart';

class ProviderStructure {
  static bool createFeatureStructure(
      {required String directoryPath, required String featureName}) {
    final lowerFeatureName = featureName.toLowerCase();
    // operation array for creating provider structure only complete when all operations are true

    List<bool> operations = [
      Operations.createFolder(
          directoryPath: directoryPath, folderName: 'provider'),
      Operations.createFile(
          directoryPath: directoryPath,
          fileName: '/provider/${lowerFeatureName}_provider.dart',
          content: _providerContent(featureName)),
    ];

    // check if all operations are true
    if (operations.every((element) => element == true)) {
      return true;
    } else {
      return false;
    }
  }

  static String _providerContent(String featureName) {
    featureName = Operations.capitalizeFirstLetter(featureName);
    return '''
      class $featureName {
        // Your provider implementation goes here
      }
    ''';
  }
}
