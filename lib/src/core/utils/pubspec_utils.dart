import 'dart:io';

class PubspecUtils {
  static bool writePubspecFile(String pattern) {
    final directoryPath = '${Directory.current.path}';
    final pubspecFile = File('$directoryPath/pubspec.yaml');
    final patternToAdd = 'app_pattern: $pattern';

    try {
      // Read the existing pubspec.yaml content
      final lines = pubspecFile.readAsLinesSync();

      // Find the line containing 'app_pattern'
      final appPatternLineIndex =
          lines.indexWhere((line) => line.trim().startsWith('app_pattern:'));

      // If 'app_pattern' is found, overwrite its value
      if (appPatternLineIndex != -1) {
        lines[appPatternLineIndex] = '$patternToAdd';
        pubspecFile.writeAsStringSync(lines.join('\n'));
        //  print('Overwritten existing app_pattern value in pubspec.yaml');
        return true;
      } else {
        // If 'app_pattern' is not found, add it after the 'name' field
        final indexOfNameField = lines.indexOf('name:');
        lines.insert(indexOfNameField + 1, '$patternToAdd');
        pubspecFile.writeAsStringSync(lines.join('\n'));
        //  print('Added $patternToAdd to pubspec.yaml');
        return true;
      }
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }

  static String? readPubspecFile() {
    final directoryPath = '${Directory.current.path}';
    final pubspecFile = File('$directoryPath/pubspec.yaml');

    try {
      // Read the existing pubspec.yaml content
      final lines = pubspecFile.readAsLinesSync();

      // Find the line containing 'app_pattern'
      final appPatternLine = lines.firstWhere(
          (line) => line.trim().startsWith('app_pattern:'),
          orElse: () => '');

      // Extract the value associated with 'app_pattern'
      final patternValue = appPatternLine.split(':').last.trim();
      return patternValue.isNotEmpty ? patternValue : null;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }
}
