import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'project_config.dart';

class ProjectConfigFile {
  final String projectPath;

  ProjectConfigFile({required this.projectPath});

  String get _configPath =>
      path.join(projectPath, '.smartwork', 'project.yaml');

  Future<ProjectConfig> read() async {
    final file = File(_configPath);
    if (!await file.exists()) {
      throw FileSystemException('Configuration file not found', _configPath);
    }

    try {
      final content = await file.readAsString();
      final yaml = loadYaml(content) as YamlMap;
      final map = _convertYamlToPlainMap(yaml);
      return ProjectConfig.fromYaml(map);
    } on Exception catch (e) {
      throw FileSystemException('Invalid YAML format: $e', _configPath);
    }
  }

  Future<void> write(ProjectConfig config) async {
    final dir = Directory(path.join(projectPath, '.smartwork'));
    await dir.create(recursive: true);

    final file = File(_configPath);
    final yamlMap = config.toYaml();
    final yamlString = _mapToYamlString(yamlMap);
    await file.writeAsString(yamlString);
  }

  String _mapToYamlString(Map<String, dynamic> map) {
    final buffer = StringBuffer();
    for (final entry in map.entries) {
      buffer.writeln('${entry.key}: ${_valueToYamlString(entry.value)}');
    }
    return buffer.toString();
  }

  String _valueToYamlString(dynamic value) {
    if (value is String) {
      return "'$value'";
    } else if (value is List) {
      if (value.isEmpty) {
        return '[]';
      }
      final items = value.map((v) => _valueToYamlString(v)).join(', ');
      return '[$items]';
    }
    return value.toString();
  }

  Map<String, dynamic> _convertYamlToPlainMap(YamlMap yaml) {
    final result = <String, dynamic>{};
    for (final entry in yaml.entries) {
      result[entry.key as String] = _convertYamlValue(entry.value);
    }
    return result;
  }

  dynamic _convertYamlValue(dynamic value) {
    if (value is YamlMap) {
      return _convertYamlToPlainMap(value);
    } else if (value is YamlList) {
      return value.map((item) => _convertYamlValue(item)).toList();
    }
    return value;
  }
}
