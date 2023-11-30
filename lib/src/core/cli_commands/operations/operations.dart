import 'dart:io';

import '../../utils/log_utils.dart';

class Operations {
  static bool folderExists(
      {required String directoryPath, required String folderName}) {
    try {
      Directory folderDir = Directory('$directoryPath/$folderName');
      return folderDir.existsSync();
    } catch (e) {
      LogService.error('Error checking folder existence: $e');
      return false; // Error checking folder existence
    }
  }

  static bool createFolder(
      {required String directoryPath, required String folderName}) {
    try {
      Directory folderDir = Directory('$directoryPath/$folderName');
      folderDir.createSync(recursive: true);
      return true; // Folder created successfully
    } catch (e) {
      return false; // Error creating folder
    }
  }

  static bool createFile({
    required String directoryPath,
    required String fileName,
    required String content,
  }) {
    try {
      File file = File('$directoryPath/$fileName');
      if (file.existsSync()) {
        LogService.success('File $fileName already exists. Overwriting...');
      }

      file.writeAsStringSync(content);
      //  LogService.success('File $fileName created in $directoryPath');
      return true; // File created successfully
    } catch (e) {
      LogService.error('Error creating file: $e');
      return false; // Error creating file
    }
  }

  static bool deleteFolder(
      {required String directoryPath, required String folderName}) {
    try {
      Directory folderDir = Directory('$directoryPath/$folderName');
      if (folderDir.existsSync()) {
        folderDir.deleteSync(recursive: true);
        return true; // Folder deleted successfully
      } else {
        return false; // Folder does not exist
      }
    } catch (e) {
      return false; // Error deleting folder
    }
  }

  static bool deleteFile({required String filePath}) {
    try {
      File file = File(filePath);
      if (file.existsSync()) {
        file.deleteSync();
        LogService.success('File ${file.path} deleted');
        return true; // File deleted successfully
      } else {
        LogService.error('File ${file.path} does not exist');
        return false; // File does not exist
      }
    } catch (e) {
      LogService.error('Error deleting file: $e');
      return false; // Error deleting file
    }
  }

  static String capitalizeFirstLetter(String input) {
    if (input.isEmpty) {
      return input;
    }
    return input[0].toUpperCase() + input.substring(1);
  }
}
