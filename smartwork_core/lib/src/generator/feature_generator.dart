import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';

class FeatureAlreadyExistsException implements Exception {
  final String featureName;

  FeatureAlreadyExistsException(this.featureName);

  @override
  String toString() => 'Feature already exists: $featureName';
}

class FeatureGenerationResult {
  final String featureName;
  final int fileCount;
  final int directoryCount;

  FeatureGenerationResult({
    required this.featureName,
    required this.fileCount,
    required this.directoryCount,
  });
}

class FeatureGenerator {
  ArchitectureGenerator _architectureGeneratorFor(Architecture architecture) {
    switch (architecture) {
      case Architecture.cleanArchitecture:
        return CleanArchitectureGenerator();
      case Architecture.mvvm:
        return MvvmGenerator();
      case Architecture.mvp:
        return MvpGenerator();
    }
  }

  StateManagementGenerator _stateManagementGeneratorFor(
    StateManagement stateManagement,
  ) {
    switch (stateManagement) {
      case StateManagement.bloc:
        return BlocGenerator();
      case StateManagement.cubit:
        return CubitGenerator();
      case StateManagement.getx:
        return GetxGenerator();
      case StateManagement.riverpod:
        return RiverpodGenerator();
    }
  }

  bool featureExists(ProjectPaths paths, String featureName) {
    final dir = Directory(paths.featurePath(featureName));
    return dir.existsSync() && dir.listSync().isNotEmpty;
  }

  Future<FeatureGenerationResult> generate(
    FeatureConfig feature,
    ProjectConfig projectConfig,
    ProjectPaths paths,
    FileWriter fileWriter, {
    bool force = false,
  }) async {
    if (!force && featureExists(paths, feature.name)) {
      throw FeatureAlreadyExistsException(feature.name);
    }

    final singleFeatureConfig = ProjectConfig(
      projectName: projectConfig.projectName,
      appTargets: projectConfig.appTargets,
      architecture: projectConfig.architecture,
      stateManagement: projectConfig.stateManagement,
      network: projectConfig.network,
      storage: projectConfig.storage,
      services: projectConfig.services,
      initialFeatures: [feature.name],
    );

    final architectureGenerator =
        _architectureGeneratorFor(projectConfig.architecture);
    final stateManagementGenerator =
        _stateManagementGeneratorFor(projectConfig.stateManagement);

    await architectureGenerator.generate(
        singleFeatureConfig, paths, fileWriter);
    await stateManagementGenerator.generate(
      singleFeatureConfig,
      paths,
      fileWriter,
    );
    await FeatureContentGenerator().generate(
      feature,
      projectConfig.architecture,
      paths,
      fileWriter,
      projectName: projectConfig.projectName,
    );

    return _countGeneratedContents(
        paths.featurePath(feature.name), feature.name);
  }

  FeatureGenerationResult _countGeneratedContents(
    String featurePath,
    String featureName,
  ) {
    final dir = Directory(featurePath);
    if (!dir.existsSync()) {
      return FeatureGenerationResult(
        featureName: featureName,
        fileCount: 0,
        directoryCount: 0,
      );
    }

    final entries = dir.listSync(recursive: true);
    final fileCount = entries.whereType<File>().length;
    final directoryCount = entries.whereType<Directory>().length;

    return FeatureGenerationResult(
      featureName: featureName,
      fileCount: fileCount,
      directoryCount: directoryCount,
    );
  }
}
