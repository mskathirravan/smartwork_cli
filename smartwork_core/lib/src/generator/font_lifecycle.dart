import 'dart:io';

import 'package:path/path.dart' as path;

import '../filesystem/file_writer.dart';
import '../models/font_config.dart';
import '../models/project_config.dart';
import '../models/project_config_file.dart';
import '../paths/project_paths.dart';
import '../template/shared_ui/shared_ui_templates.dart';
import '../template/template_engine.dart';
import 'project_generator.dart';
import 'pubspec_generator.dart';
import 'service_generator.dart';

class FontSourceFileNotFoundException implements Exception {
  final String sourcePath;

  FontSourceFileNotFoundException(this.sourcePath);

  @override
  String toString() => 'Font file not found: $sourcePath';
}

class FontLifecycle {
  Future<void> updateFont({
    required String projectPath,
    required FontConfig fonts,
  }) async {
    final config = await ProjectConfigFile(projectPath: projectPath).read();

    if (fonts.type == FontType.custom) {
      for (final file in fonts.custom!.files) {
        if (!await File(file.sourcePath).exists()) {
          throw FontSourceFileNotFoundException(file.sourcePath);
        }
      }
    }

    final paths = ProjectPaths(projectRoot: projectPath);
    final fileWriter = FileWriter();

    if (config.fonts.type == FontType.custom) {
      for (final file in config.fonts.custom!.files) {
        await _deleteIfExists(
          File(path.join(paths.assetsFonts, file.assetFileName)),
        );
      }
    }

    if (fonts.type == FontType.custom) {
      await Directory(paths.assetsFonts).create(recursive: true);
      for (final file in fonts.custom!.files) {
        await fileWriter.copyFile(
          file.sourcePath,
          path.join(paths.assetsFonts, file.assetFileName),
        );
      }
    }

    final updatedConfig = config.copyWith(fonts: fonts);
    await ProjectConfigFile(projectPath: projectPath).write(updatedConfig);

    await ServiceGenerator().generate(
      services: updatedConfig.services,
      projectName: updatedConfig.projectName,
      paths: paths,
      fileWriter: fileWriter,
      network: updatedConfig.network,
      storage: updatedConfig.storage,
      fonts: fonts,
    );
    await ServiceGenerator().generateTests(
      services: updatedConfig.services,
      projectName: updatedConfig.projectName,
      paths: paths,
      fileWriter: fileWriter,
      network: updatedConfig.network,
      storage: updatedConfig.storage,
      fonts: fonts,
    );

    await _syncPubspec(updatedConfig, paths, fileWriter);
  }

  Future<bool> updateFontSample({
    required String projectPath,
    required bool includeSample,
  }) async {
    final config = await ProjectConfigFile(projectPath: projectPath).read();
    final paths = ProjectPaths(projectRoot: projectPath);
    final fileWriter = FileWriter();
    final sampleFile = File(paths.sharedUiFile('font_sample.dart'));

    if (!includeSample || config.fonts.type == FontType.none) {
      await _deleteIfExists(sampleFile);
    } else {
      await fileWriter.write(
        sampleFile.path,
        TemplateEngine().render(
          SharedUiTemplates.fontSampleTemplate(config.fonts),
          {},
        ),
      );
    }

    await ProjectGenerator(outputPath: projectPath, config: config)
        .regenerateSharedUiBarrel();

    return sampleFile.existsSync();
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
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
