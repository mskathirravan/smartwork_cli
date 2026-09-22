import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../filesystem/file_writer.dart';
import '../models/project_config.dart';
import '../models/project_config_file.dart';
import '../paths/project_paths.dart';
import '../template/naming_conventions.dart';
import 'feature_generator.dart';
import 'feature_lifecycle.dart' show FeatureNotFoundException;
import 'model_generator.dart';

class JsonFileNotFoundException implements Exception {
  final String jsonFilePath;

  JsonFileNotFoundException(this.jsonFilePath);

  @override
  String toString() => 'JSON file not found: $jsonFilePath';
}

class InvalidJsonException implements Exception {
  final String jsonFilePath;
  final String message;

  InvalidJsonException(this.jsonFilePath, this.message);

  @override
  String toString() => 'Invalid JSON in "$jsonFilePath": $message';
}

class ModelFileCollisionException implements Exception {
  final List<String> existingFiles;

  ModelFileCollisionException(this.existingFiles);

  @override
  String toString() => 'Refusing to overwrite existing model file(s): '
      '${existingFiles.join(', ')}. No files were generated.';
}

class ModelGenerationResult {
  final List<String> generatedFiles;

  final List<String> classNames;

  ModelGenerationResult({
    required this.generatedFiles,
    required this.classNames,
  });
}

class ModelLifecycle {
  Future<ModelGenerationResult> generateFromJson({
    required String projectPath,
    required String jsonFilePath,
    required String featureName,
  }) async {
    final config = await ProjectConfigFile(projectPath: projectPath).read();
    final paths = ProjectPaths(projectRoot: projectPath);

    if (!FeatureGenerator().featureExists(paths, featureName)) {
      throw FeatureNotFoundException(featureName);
    }

    final jsonFile = File(jsonFilePath);
    if (!await jsonFile.exists()) {
      throw JsonFileNotFoundException(jsonFilePath);
    }

    final raw = await jsonFile.readAsString();
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw InvalidJsonException(jsonFilePath, e.message);
    }

    final rootBaseName = _rootBaseNameFor(jsonFilePath);
    final classes = ModelGenerator().inferClasses(
      rootBaseName: rootBaseName,
      decodedJson: decoded,
    );

    final modelDir = _modelDirFor(config.architecture, paths, featureName);
    final targetPaths = <GeneratedModelClass, String>{};
    final collisions = <String>[];
    for (final generatedClass in classes) {
      final targetPath =
          path.join(modelDir, '${generatedClass.fileBaseName}_model.dart');
      targetPaths[generatedClass] = targetPath;
      if (File(targetPath).existsSync()) {
        collisions.add(path.relative(targetPath, from: projectPath));
      }
    }
    if (collisions.isNotEmpty) {
      throw ModelFileCollisionException(collisions);
    }

    final fileWriter = FileWriter();
    final generatedFiles = <String>[];
    for (final generatedClass in classes) {
      final targetPath = targetPaths[generatedClass]!;
      await fileWriter.write(
        targetPath,
        ModelGenerator().renderSource(generatedClass),
      );
      generatedFiles.add(path.relative(targetPath, from: projectPath));
    }

    await _updateFeatureBarrel(
      paths: paths,
      featureName: featureName,
      generatedAbsolutePaths: targetPaths.values.toList(),
    );

    return ModelGenerationResult(
      generatedFiles: generatedFiles,
      classNames: classes.map((c) => c.className).toList(),
    );
  }

  String _rootBaseNameFor(String jsonFilePath) {
    final baseName = path.basenameWithoutExtension(jsonFilePath);
    return NamingConventions.toPascalCase(baseName);
  }

  String _modelDirFor(
    Architecture architecture,
    ProjectPaths paths,
    String featureName,
  ) {
    final featurePath = paths.featurePath(featureName);
    return switch (architecture) {
      Architecture.cleanArchitecture =>
        path.join(featurePath, 'data', 'models'),
      Architecture.mvvm => path.join(featurePath, 'models'),
      Architecture.mvp => path.join(featurePath, 'models'),
    };
  }

  Future<void> _updateFeatureBarrel({
    required ProjectPaths paths,
    required String featureName,
    required List<String> generatedAbsolutePaths,
  }) async {
    final featurePath = paths.featurePath(featureName);
    final barrelFile = File(path.join(featurePath, '$featureName.dart'));

    final existingLines = await barrelFile.exists()
        ? (await barrelFile.readAsString())
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList()
        : <String>[];

    for (final absolutePath in generatedAbsolutePaths) {
      final relative = path.relative(absolutePath, from: featurePath);
      final exportLine = "export '$relative';";
      if (!existingLines.contains(exportLine)) {
        existingLines.add(exportLine);
      }
    }

    final content =
        existingLines.isEmpty ? '' : '${existingLines.join('\n')}\n';
    await FileWriter().write(barrelFile.path, content);
  }
}
