import 'dart:async';
import 'dart:io';

class FileWriter {
  static const _recordingKey = #smartworkWrittenDartFiles;

  /// Runs [body], returning every `.dart` file [write] wrote during it.
  /// Generated code is only guaranteed formatter-clean after `dart format`
  /// (a long feature or model name can overflow a template's line), so
  /// callers format exactly these files — never the developer's own code.
  static Future<Set<String>> recordDartWrites(
    Future<void> Function() body,
  ) async {
    final written = <String>{};
    await runZoned(body, zoneValues: {_recordingKey: written});
    return written;
  }

  Future<void> write(String filePath, String content) async {
    final file = File(filePath);
    final parentDir = file.parent;

    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    await file.writeAsString(content);
    if (filePath.endsWith('.dart')) {
      (Zone.current[_recordingKey] as Set<String>?)?.add(file.absolute.path);
    }
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
