import '../operations/operations.dart';

class PresentationStructure {
  static bool createFeatureStructure(
      {required String directoryPath, required String featureName}) {
    final lowerFeatureName = featureName.toLowerCase();
    // operation array for creating presentation structure only complete when all operations are true
    List<bool> operations = [
      Operations.createFolder(
          directoryPath: directoryPath, folderName: 'presentation'),
      Operations.createFolder(
          directoryPath: directoryPath, folderName: 'presentation/logic'),
      Operations.createFolder(
          directoryPath: directoryPath, folderName: 'presentation/screen'),
      Operations.createFolder(
          directoryPath: directoryPath, folderName: 'presentation/widgets'),
      Operations.createFile(
          directoryPath: directoryPath,
          fileName: '/presentation/screen/${lowerFeatureName}_screen.dart',
          content: _screenContent(featureName)),
    ];

    // check if all operations are true
    if (operations.every((element) => element == true)) {
      return true;
    } else {
      return false;
    }
  }

  static String _screenContent(String featureName) {
    featureName = Operations.capitalizeFirstLetter(featureName);

    return '''
import 'package:flutter/material.dart';

class ${featureName}Screen extends StatelessWidget {
  final bool isLoading; // Add a boolean flag to determine if data is loading
  final String data; // Add the data parameter

    const ${featureName}Screen({
    super.key,
    required this.isLoading, // Add the isLoading parameter
    required this.data, // Add the data parameter
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('$featureName Screen'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // If loading, show a circular progress indicator
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    } else {
      // If not loading, show the data
      return const Center(
        child: Text('Data: data'),
      );
    }
  }
}
    ''';
  }
}
