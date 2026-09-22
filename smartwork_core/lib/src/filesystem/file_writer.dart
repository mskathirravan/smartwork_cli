import 'dart:io';

class FileWriter {
  Future<void> write(String filePath, String content) async {
    final file = File(filePath);
    final parentDir = file.parent;

    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    await file.writeAsString(content);
  }

  Future<void> writeBytes(String filePath, List<int> bytes) async {
    final file = File(filePath);
    final parentDir = file.parent;

    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    await file.writeAsBytes(bytes);
  }

  Future<void> copyFile(String sourcePath, String destPath) async {
    final destFile = File(destPath);
    final parentDir = destFile.parent;

    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    await File(sourcePath).copy(destPath);
  }
}
