import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import '../../paths/project_paths.dart';
import 'project_scan_result.dart';

class ProjectScanner {
  Future<ProjectScanResult> scan(String projectPath) async {
    final paths = ProjectPaths(projectRoot: projectPath);

    final pubspecYaml = await _readPubspec(paths.pubspecFile);

    final dartFiles = <String, String>{};
    for (final dir in [paths.lib, paths.test]) {
      await _collectDartFiles(projectPath, dir, dartFiles);
    }

    return ProjectScanResult(
      projectPath: projectPath,
      pubspecYaml: pubspecYaml,
      dartFiles: dartFiles,
    );
  }

  Future<Map<String, dynamic>?> _readPubspec(String pubspecFilePath) async {
    final file = File(pubspecFilePath);
    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      final decoded = loadYaml(content);
      if (decoded is! YamlMap) return null;
      return _plainMap(decoded);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _plainMap(YamlMap yaml) {
    final result = <String, dynamic>{};
    for (final entry in yaml.entries) {
      result[entry.key.toString()] = _plainValue(entry.value);
    }
    return result;
  }

  dynamic _plainValue(dynamic value) {
    if (value is YamlMap) return _plainMap(value);
    if (value is YamlList) return value.map(_plainValue).toList();
    return value;
  }

  Future<void> _collectDartFiles(
    String projectRoot,
    String dir,
    Map<String, String> out,
  ) async {
    final directory = Directory(dir);
    if (!await directory.exists()) return;

    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = path
          .relative(entity.path, from: projectRoot)
          .replaceAll(path.separator, '/');
      out[relative] = await entity.readAsString();
    }
  }
}
