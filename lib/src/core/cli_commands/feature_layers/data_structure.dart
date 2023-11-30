import '../operations/operations.dart';

class DataStructure {
  static bool createFeatureStructure(
      {required String directoryPath, required String featureName}) {
    final lowerFeatureName = featureName.toLowerCase();
    // operation array for creating data structure only complete when all operations are true
    List<bool> operations = [
      Operations.createFolder(directoryPath: directoryPath, folderName: 'data'),
      Operations.createFolder(
          directoryPath: directoryPath, folderName: 'data/local'),
      Operations.createFolder(
          directoryPath: directoryPath, folderName: 'data/remote'),
      Operations.createFile(
          directoryPath: directoryPath,
          fileName: '/data/local/${lowerFeatureName}_local_data_source.dart',
          content: _localDataSourceContent(featureName)),
      Operations.createFile(
          directoryPath: directoryPath,
          fileName: '/data/remote/${lowerFeatureName}_remote_data_source.dart',
          content: _remoteDataSourceContent(featureName)),
      Operations.createFile(
          directoryPath: directoryPath,
          fileName: '/data/${lowerFeatureName}_repository.dart',
          content: _repositoryContent(featureName)),
    ];

    // check if all operations are true
    if (operations.every((element) => element == true)) {
      return true;
    } else {
      return false;
    }
  }

  static String _remoteDataSourceContent(String featureName) {
    String className = Operations.capitalizeFirstLetter(featureName);
    return '''


class ${className}RemoteDataSource {
  // Implement methods for interacting with remote data here

  // Example method to fetch data from a remote API
  Future<String> fetchDataFromApi() async {
    // Assume that this method fetches data from a remote API
    // You can replace this with your actual implementation
    await Future.delayed(
        const Duration(seconds: 2)); // Simulating a network delay
    return 'Remote data for FeatureName';
  }
}
    ''';
  }

  static String _localDataSourceContent(String featureName) {
    String className = Operations.capitalizeFirstLetter(featureName);

    return '''
// ignore_for_file: avoid_print

  class ${className}LocalDataSource {
  // Implement methods for interacting with local data here

  // Example method to save data to a local database or file
  Future<void> saveDataLocally(String data) async {
    // Assume that this method saves data to a local database or file
    // You can replace this with your actual implementation
    await Future.delayed(
        const Duration(seconds: 1)); // Simulating a local storage delay
    print('Data saved locally: data');
  }

  // Example method to retrieve data from a local database or file
  Future<String?> getLocalData() async {
    // Assume that this method retrieves data from a local database or file
    // You can replace this with your actual implementation
    await Future.delayed(
        const Duration(seconds: 1)); // Simulating a local storage delay
    return 'Local data for FeatureName';
  }
}
    ''';
  }

  static String _repositoryContent(String featureName) {
    String className = Operations.capitalizeFirstLetter(featureName);

    return '''
// ignore_for_file: avoid_print
import '../$featureName.dart';
class ${className}Repository {
  final ${className}RemoteDataSource remoteDataSource;
  final ${className}LocalDataSource localDataSource;

  ${className}Repository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  // Example method to fetch data from either remote or local based on some condition
  Future<String> fetchData() async {
    // Check if data is available locally
    final localData = await localDataSource.getLocalData();

    if (localData != null) {
      print('Using local data: localData');
      return localData;
    } else {
      // If data is not available locally, fetch it from the remote source
      final remoteData = await remoteDataSource.fetchDataFromApi();
      print('Using remote data: \$remoteData');

      // Save the fetched data locally for future use
      await localDataSource.saveDataLocally(remoteData);

      return remoteData;
    }
  }
}
    ''';
  }
}
