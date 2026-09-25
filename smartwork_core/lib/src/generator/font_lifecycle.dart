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

    final removeSample = !includeSample || config.fonts.type == FontType.none;
    if (removeSample && !_isFontSampleUsed(paths, sampleFile)) {
      await _deleteIfExists(sampleFile);
    } else {
      // Also rewritten (for the current font) when removal was asked for
      // but the project's own code still uses FontSample — e.g. a Home
      // page generated with the sample — since SmartWork never edits that
      // code, deleting the file would stop the project compiling.
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

  /// Whether any Dart file under lib/ or test/, other than the sample
  /// itself, uses `FontSample`.
  bool _isFontSampleUsed(ProjectPaths paths, File sampleFile) {
    for (final dir in [paths.lib, paths.test]) {
      final root = Directory(dir);
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.absolute.path == sampleFile.absolute.path) continue;
        if (entity.readAsStringSync().contains('FontSample(')) return true;
      }
    }
    return false;
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
