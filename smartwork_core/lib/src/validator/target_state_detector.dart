import 'dart:io';

import 'package:path/path.dart' as path;

import '../models/project_config.dart';
import '../models/project_config_file.dart';
import '../paths/project_paths.dart';

enum TargetProjectState {
  empty,

  nonFlutterProject,

  flutterProject,

  smartworkProject,

  malformedSmartworkProject,
}

class TargetStateDetectionResult {
  final TargetProjectState state;
  final ProjectConfig? existingConfig;
  final String? detectionError;
  final Set<AppTarget> existingPlatforms;

  TargetStateDetectionResult._(
    this.state, {
    this.existingConfig,
    this.detectionError,
    required this.existingPlatforms,
  });

  factory TargetStateDetectionResult.empty() => TargetStateDetectionResult._(
        TargetProjectState.empty,
        existingPlatforms: const {},
      );

  factory TargetStateDetectionResult.nonFlutterProject({
    Set<AppTarget> existingPlatforms = const {},
  }) =>
      TargetStateDetectionResult._(
        TargetProjectState.nonFlutterProject,
        existingPlatforms: existingPlatforms,
      );

  factory TargetStateDetectionResult.flutterProject({
    required Set<AppTarget> existingPlatforms,
  }) =>
      TargetStateDetectionResult._(
        TargetProjectState.flutterProject,
        existingPlatforms: existingPlatforms,
      );

  factory TargetStateDetectionResult.smartworkProject(
    ProjectConfig config, {
    required Set<AppTarget> existingPlatforms,
  }) =>
      TargetStateDetectionResult._(
        TargetProjectState.smartworkProject,
        existingConfig: config,
        existingPlatforms: existingPlatforms,
      );

  factory TargetStateDetectionResult.malformedSmartworkProject(
    String error, {
    required Set<AppTarget> existingPlatforms,
  }) =>
      TargetStateDetectionResult._(
        TargetProjectState.malformedSmartworkProject,
        detectionError: error,
        existingPlatforms: existingPlatforms,
      );
}

class TargetStateDetector {
  Future<TargetStateDetectionResult> detect(String projectPath) async {
    final paths = ProjectPaths(projectRoot: projectPath);

    if (File(paths.projectConfigFile).existsSync()) {
      try {
        final config = await ProjectConfigFile(projectPath: projectPath).read();
        return TargetStateDetectionResult.smartworkProject(
          config,
          existingPlatforms: existingPlatforms(projectPath),
        );
      } catch (e) {
        return TargetStateDetectionResult.malformedSmartworkProject(
          e.toString(),
          existingPlatforms: existingPlatforms(projectPath),
        );
      }
    }

    final dir = Directory(projectPath);
    if (!dir.existsSync() || dir.listSync().isEmpty) {
      return TargetStateDetectionResult.empty();
    }

    final hasPubspec = File(paths.pubspecFile).existsSync();
    final hasLib = Directory(paths.lib).existsSync();
    final platforms = existingPlatforms(projectPath);

    if (hasPubspec && hasLib && platforms.isNotEmpty) {
      return TargetStateDetectionResult.flutterProject(
        existingPlatforms: platforms,
      );
    }

    return TargetStateDetectionResult.nonFlutterProject(
      existingPlatforms: platforms,
    );
  }

  Set<AppTarget> existingPlatforms(String projectPath) {
    return AppTarget.values
        .where((target) =>
            Directory(path.join(projectPath, target.platformFolder))
                .existsSync())
        .toSet();
  }
}
