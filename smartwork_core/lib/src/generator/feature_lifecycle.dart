import 'dart:io';

import 'package:path/path.dart' as path;

import '../filesystem/file_writer.dart';
import '../models/feature_config.dart';
import '../models/project_config.dart';
import '../models/project_config_file.dart';
import '../paths/project_paths.dart';
import 'feature_generator.dart';
import 'project_generator.dart';
import 'routing_generator.dart';

class FeatureNotFoundException implements Exception {
  final String featureName;

  FeatureNotFoundException(this.featureName);

  @override
  String toString() => 'Feature not found: $featureName';
}

class HomeFeatureNotRemovableException implements Exception {
  final String featureName;

  HomeFeatureNotRemovableException(this.featureName);

  @override
  String toString() =>
      'Cannot remove "$featureName": it is this project\'s configured '
      'Home feature (ProjectConfig.homeFeatureName), a framework-level '
      'concept, not an ordinary feature.';
}

class DebugFeatureNotRemovableException implements Exception {
  @override
  String toString() =>
      'Cannot remove "debug": it is the framework-level Debug feature '
      '(lib/features/debug/), not an ordinary feature.';
}

class FeatureAddResult {
  final FeatureGenerationResult generation;

  final bool addedToRouting;

  FeatureAddResult({required this.generation, required this.addedToRouting});
}

class FeatureRemoveResult {
  final String featureName;

  final bool wasRouted;

  FeatureRemoveResult({required this.featureName, required this.wasRouted});
}

class FeatureLifecycle {
  Future<FeatureAddResult> addFeature({
    required String projectPath,
    required FeatureConfig feature,
  }) async {
    final config = await ProjectConfigFile(projectPath: projectPath).read();
    final paths = ProjectPaths(projectRoot: projectPath);

    final generation = await FeatureGenerator().generate(
      feature,
      config,
      paths,
      FileWriter(),
    );

    final hasPage = feature
        .resolveDependencies()
        .components
        .contains(FeatureComponent.page);
    final isRoutable = hasPage &&
        RoutingGenerator.resolveRoutableFeatureNames(
          [feature.name],
          homeFeatureName: config.homeFeatureName,
        ).isNotEmpty;

    if (isRoutable && !config.initialFeatures.contains(feature.name)) {
      final updatedConfig = _withInitialFeatures(
        config,
        [...config.initialFeatures, feature.name],
      );
      await ProjectConfigFile(projectPath: projectPath).write(updatedConfig);
      await ProjectGenerator(outputPath: projectPath, config: updatedConfig)
          .regenerateRouting();
    }

    return FeatureAddResult(generation: generation, addedToRouting: isRoutable);
  }

  Future<FeatureRemoveResult> removeFeature({
    required String projectPath,
    required String featureName,
  }) async {
    final config = await ProjectConfigFile(projectPath: projectPath).read();
    final paths = ProjectPaths(projectRoot: projectPath);

    if (featureName == config.homeFeatureName) {
      throw HomeFeatureNotRemovableException(featureName);
    }
    if (featureName == 'debug') {
      throw DebugFeatureNotRemovableException();
    }
    if (!FeatureGenerator().featureExists(paths, featureName)) {
      throw FeatureNotFoundException(featureName);
    }

    await Directory(paths.featurePath(featureName)).delete(recursive: true);

    final testDir = Directory(path.join(paths.test, 'features', featureName));
    if (testDir.existsSync()) {
      await testDir.delete(recursive: true);
    }

    final wasRouted = config.initialFeatures.contains(featureName);
    final updatedConfig = _withInitialFeatures(
      config,
      config.initialFeatures.where((name) => name != featureName).toList(),
    );
    await ProjectConfigFile(projectPath: projectPath).write(updatedConfig);
    await ProjectGenerator(outputPath: projectPath, config: updatedConfig)
        .regenerateRouting();

    return FeatureRemoveResult(featureName: featureName, wasRouted: wasRouted);
  }

  ProjectConfig _withInitialFeatures(
    ProjectConfig config,
    List<String> initialFeatures,
  ) {
    return config.copyWith(initialFeatures: initialFeatures);
  }
}
