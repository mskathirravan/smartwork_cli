import 'dart:io';

import '../filesystem/file_writer.dart';
import '../models/localization_config.dart';
import '../models/project_config.dart';
import '../models/project_config_file.dart';
import '../paths/project_paths.dart';
import 'localization_generator.dart';
import 'main_dart_generator.dart';
import 'pubspec_generator.dart';

class LocalizationLifecycle {
  Future<void> updateLocalization({
    required String projectPath,
    required LocalizationConfig localization,
  }) async {
    final config = await ProjectConfigFile(projectPath: projectPath).read();
    final updatedConfig = config.copyWith(localization: localization);
    final paths = ProjectPaths(projectRoot: projectPath);
    final fileWriter = FileWriter();

    await ProjectConfigFile(projectPath: projectPath).write(updatedConfig);

    await LocalizationGenerator().generate(
      outputPath: projectPath,
      localization: localization,
      projectName: updatedConfig.projectName,
    );

    await fileWriter.write(
      paths.mainDartFile,
      MainDartGenerator().generate(updatedConfig),
    );

    await _syncPubspec(updatedConfig, paths, fileWriter);
  }

  Future<void> _syncPubspec(
    ProjectConfig config,
    ProjectPaths paths,
    FileWriter fileWriter,
  ) async {
    final pubspecFile = File(paths.pubspecFile);
    if (!await pubspecFile.exists()) return;

    final existing = await pubspecFile.readAsString();
    final merged = await PubspecGenerator().mergeInto(existing, config);
    await fileWriter.write(paths.pubspecFile, merged);
  }
}
