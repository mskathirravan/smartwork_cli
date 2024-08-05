import '../operations/operations.dart';

class DomainStructure {
  static bool createFeatureStructure(
      {required String directoryPath, required String featureName}) {
    final lowerFeatureName = featureName.toLowerCase();
    // operation array for creating domain structure only complete when all operations are true
    List<bool> operations = [
      Operations.createFolder(
          directoryPath: directoryPath, folderName: 'domain'),
      Operations.createFolder(
          directoryPath: directoryPath, folderName: 'domain/models'),
      Operations.createFolder(
          directoryPath: directoryPath, folderName: 'domain/use_case'),
      Operations.createFile(
          directoryPath: directoryPath,
          fileName: '/domain/models/${lowerFeatureName}_model.dart',
          content: _modelContent(featureName)),
      Operations.createFile(
          directoryPath: directoryPath,
          fileName: '/domain/use_case/${lowerFeatureName}_use_case.dart',
          content: _useCaseContent(featureName)),
    ];

    // check if all operations are true
    if (operations.every((element) => element == true)) {
      return true;
    } else {
      return false;
    }
  }

  static String _modelContent(String featureName) {
    featureName = Operations.capitalizeFirstLetter(featureName);
    return '''
      class ${featureName}Model {
        // Your model implementation goes here
      }
    ''';
  }

  static String _useCaseContent(String featureName) {
    String className = Operations.capitalizeFirstLetter(featureName);

    return '''
import 'package:flutter/foundation.dart';
import '../../$featureName.dart';

class ${className}UseCase {
  final ${className}RemoteDataSource remoteDataSource;
  final ${className}LocalDataSource localDataSource;

  ${className}UseCase({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  // Example use case method to fetch data
  Future<String> fetchData() async {
    // Check if data is available locally
    final localData = await localDataSource.getLocalData();

    if (localData != null) {
      debugPrint('Using local data in use case: localData');
      return localData;
    } else {
      // If data is not available locally, fetch it from the remote source
      final remoteData = await remoteDataSource.fetchDataFromApi();
      debugPrint('Using remote data in use case: \$remoteData');

      // Save the fetched data locally for future use
      await localDataSource.saveDataLocally(remoteData);

      return remoteData;
    }
  }
}

    ''';
  }
}
