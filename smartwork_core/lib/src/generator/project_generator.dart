import 'dart:io';

import 'package:path/path.dart' as path;

import '../filesystem/file_writer.dart';
import '../models/feature_config.dart';
import '../models/font_config.dart';
import '../models/project_config.dart';
import '../models/project_config_file.dart';
import '../models/service_definition.dart';
import '../paths/project_paths.dart';
import '../template/constants/constants_templates.dart';
import '../template/utilities/utilities_templates.dart';
import '../template/clean_architecture/clean_architecture_templates.dart';
import '../template/environment/environment_templates.dart';
import '../template/home/home_templates.dart';
import '../template/mvp/mvp_templates.dart';
import '../template/mvvm/mvvm_templates.dart';
import '../template/naming_conventions.dart';
import '../template/shared_ui/shared_ui_templates.dart';
import '../template/template.dart';
import '../template/template_engine.dart';
import 'core_test_generator.dart';
import 'debug_feature_generator.dart';
import 'feature_generator.dart';
import 'localization_generator.dart';
import 'main_dart_generator.dart';
import 'project_documentation_generator.dart';
import 'pubspec_generator.dart';
import 'routing_generator.dart';
import 'service_generator.dart';

class ProjectGenerationResult {
  final int featureCount;
  final int fileCount;
  final int directoryCount;

  ProjectGenerationResult({
    required this.featureCount,
    required this.fileCount,
    required this.directoryCount,
  });
}

class ProjectGenerator {
  final String outputPath;
  final ProjectConfig config;
  final bool includeFontSample;
  final String? projectDescription;

  ProjectGenerator({
    required this.outputPath,
    required this.config,
    this.includeFontSample = false,
    this.projectDescription,
  });

  Future<ProjectGenerationResult> generate() async {
    await _generateDotSmartworkConfig();
    await _generateAssets();
    await _generateLocalization();
    await _generateCoreConstants();
    await _generateCoreUtilities();
    await _generateEnvironment();
    await _generateSharedUi();
    await _generateSharedUiTests();
    await _generateServices();
    await _generateServiceTests();
    final homeResult = await _generateHome();
    await _generateDebug();
    await _generateDebugTests();
    final featuresResult = await _generateFeatures();
    await regenerateRouting();
    await _generatePubspec();
    await removeStaleFlutterWidgetTest();
    await _generateCoreTests();
    await _generateMain();

    return ProjectGenerationResult(
      featureCount: homeResult.featureCount + featuresResult.featureCount,
      fileCount: homeResult.fileCount + featuresResult.fileCount,
      directoryCount: homeResult.directoryCount + featuresResult.directoryCount,
    );
  }

  Future<void> clearGeneratedContent() async {
    final paths = ProjectPaths(projectRoot: outputPath);

    for (final dir in [
      paths.core,
      paths.features,
      paths.services,
      paths.testCore,
      paths.testFeatures,
      paths.testServices,
    ]) {
      final directory = Directory(dir);
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }

    final mainFile = File(paths.mainDartFile);
    if (mainFile.existsSync()) {
      await mainFile.delete();
    }
  }

  Future<void> _generateAssets() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    for (final dir in [
      paths.assetsImages,
      paths.assetsFonts,
      paths.assetsIcons,
      paths.assetsAnimations,
    ]) {
      await Directory(dir).create(recursive: true);
    }

    await _copyCustomFontFiles(paths);
  }

  Future<void> _copyCustomFontFiles(ProjectPaths paths) async {
    final fonts = config.fonts;
    if (fonts.type != FontType.custom) return;

    for (final file in fonts.custom!.files) {
      await FileWriter().copyFile(
        file.sourcePath,
        path.join(paths.assetsFonts, file.assetFileName),
      );
    }
  }

  Future<void> _generateLocalization() async {
    await LocalizationGenerator().generate(
      outputPath: outputPath,
      localization: config.localization,
      projectName: config.projectName,
    );
  }

  Future<ProjectGenerationResult> _generateHome() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    final fileWriter = FileWriter();

    final result = await FeatureGenerator().generate(
      FeatureConfig(
        name: config.homeFeatureName,
        components: {FeatureComponent.page},
      ),
      config,
      paths,
      fileWriter,
    );
    await _overwriteHomePage(paths, fileWriter, config.homeFeatureName);

    return ProjectGenerationResult(
      featureCount: 1,
      fileCount: result.fileCount,
      directoryCount: result.directoryCount,
    );
  }

  Future<ProjectGenerationResult> _generateFeatures() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    final fileWriter = FileWriter();
    final featureGenerator = FeatureGenerator();

    var fileCount = 0;
    var directoryCount = 0;
    var featureCount = 0;

    final featuresToGenerate = config.initialFeatures
        .where((name) => name != config.homeFeatureName)
        .toSet();

    for (final featureName in featuresToGenerate) {
      final result = await featureGenerator.generate(
        FeatureConfig(name: featureName),
        config,
        paths,
        fileWriter,
      );
      fileCount += result.fileCount;
      directoryCount += result.directoryCount;
      featureCount++;
    }

    return ProjectGenerationResult(
      featureCount: featureCount,
      fileCount: fileCount,
      directoryCount: directoryCount,
    );
  }

  Future<void> _overwriteHomePage(
    ProjectPaths paths,
    FileWriter fileWriter,
    String featureName,
  ) async {
    final names = FeatureNames(featureName);
    final vars = {'featureName': names.snake, 'pascalName': names.pascal};
    final engine = TemplateEngine();
    final featurePath = paths.featurePath(featureName);

    final (String relativePath, Template template) =
        switch (config.architecture) {
      Architecture.cleanArchitecture => (
          'presentation/pages/${names.snake}_page.dart',
          HomeTemplates.pageTemplateClean(
            includeFontSample: includeFontSample,
          ),
        ),
      Architecture.mvvm => (
          'views/${names.snake}_page.dart',
          HomeTemplates.pageTemplateMvvm(
            includeFontSample: includeFontSample,
          ),
        ),
      Architecture.mvp => (
          'views/${names.snake}_page.dart',
          HomeTemplates.pageTemplateMvp(
            includeFontSample: includeFontSample,
          ),
        ),
    };

    await fileWriter.write(
      path.join(featurePath, relativePath),
      engine.render(template, vars),
    );

    final pageTestTemplate = switch (config.architecture) {
      Architecture.cleanArchitecture =>
        CleanArchitectureTemplates.pageTestTemplate(),
      Architecture.mvvm => MvvmTemplates.pageTestTemplate(),
      Architecture.mvp => MvpTemplates.pageTestTemplate(),
    };
    await fileWriter.write(
      path.join(
          paths.test, 'features', names.snake, '${names.snake}_page_test.dart'),
      engine.render(
          pageTestTemplate, {...vars, 'projectName': config.projectName}),
    );
  }

  Future<void> _generateDotSmartworkConfig() async {
    final configFile = ProjectConfigFile(projectPath: outputPath);
    await configFile.write(config);
  }

  Future<void> _generatePubspec() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    final pubspecFile = File(paths.pubspecFile);
    final generator = PubspecGenerator();
    final content = pubspecFile.existsSync()
        ? await generator.mergeInto(
            await pubspecFile.readAsString(),
            config,
            projectDescription: projectDescription,
          )
        : await generator.generate(config,
            projectDescription: projectDescription);
    await FileWriter().write(paths.pubspecFile, content);
  }

  Future<void> removeStaleFlutterWidgetTest() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    final staleTest = File(path.join(paths.test, 'widget_test.dart'));
    if (staleTest.existsSync()) {
      await staleTest.delete();
    }
  }

  Future<void> _generateCoreConstants() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    final fileWriter = FileWriter();
    final engine = TemplateEngine();

    await fileWriter.write(
      paths.coreConstantsAppFile,
      engine.render(
        ConstantsTemplates.appConstantsTemplate(),
        {'projectName': config.projectName},
      ),
    );
    await fileWriter.write(
      paths.coreConstantsApiFile,
      engine.render(ConstantsTemplates.apiConstantsTemplate(), {}),
    );
    await fileWriter.write(
      paths.coreConstantsAssetFile,
      engine.render(ConstantsTemplates.assetConstantsTemplate(), {}),
    );
    await fileWriter.write(
      paths.coreConstantsStorageFile,
      engine.render(
        ConstantsTemplates.storageConstantsTemplate(
          includeSecureSessionKeys:
              config.services.contains(Service.secureSession.id),
        ),
        {},
      ),
    );
    await fileWriter.write(
      paths.coreConstantsColorsFile,
      engine.render(ConstantsTemplates.appColorsTemplate(), {}),
    );
    await fileWriter.write(
      paths.coreConstantsDimensionsFile,
      engine.render(ConstantsTemplates.appDimensionsTemplate(), {}),
    );
    await fileWriter.write(
      paths.coreConstantsScreenDimensionsFile,
      engine.render(ConstantsTemplates.screenDimensionsTemplate(), {}),
    );
    await fileWriter.write(
      paths.coreConstantsBarrelFile,
      engine.render(ConstantsTemplates.constantsBarrelTemplate(), {}),
    );
  }

  Future<void> _generateCoreUtilities() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    final fileWriter = FileWriter();
    final engine = TemplateEngine();

    await fileWriter.write(
      paths.coreUtilitiesAppPlatformFile,
      engine.render(UtilitiesTemplates.appPlatformTemplate(), {}),
    );
    await fileWriter.write(
      paths.coreUtilitiesDateTimeExtensionsFile,
      engine.render(UtilitiesTemplates.dateTimeExtensionsTemplate(), {}),
    );
    await fileWriter.write(
      paths.coreUtilitiesStringExtensionsFile,
      engine.render(UtilitiesTemplates.stringExtensionsTemplate(), {}),
    );
    await fileWriter.write(
      paths.coreUtilitiesColorHexFile,
      engine.render(UtilitiesTemplates.colorHexTemplate(), {}),
    );
    await fileWriter.write(
      paths.coreUtilitiesFileSizeFile,
      engine.render(UtilitiesTemplates.fileSizeTemplate(), {}),
    );
    await fileWriter.write(
      paths.coreUtilitiesBarrelFile,
      engine.render(UtilitiesTemplates.utilitiesBarrelTemplate(), {}),
    );
  }

  Future<void> _generateEnvironment() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    final fileWriter = FileWriter();
    final engine = TemplateEngine();

    await fileWriter.write(
      paths.coreEnvironmentFile,
      engine.render(EnvironmentTemplates.environmentTemplate(), {}),
    );
    await fileWriter.write(
      paths.coreEnvironmentUrlsFile,
      engine.render(EnvironmentTemplates.environmentUrlsTemplate(), {}),
    );
    await fileWriter.write(
      paths.coreEnvironmentManagerFile,
      engine.render(EnvironmentTemplates.environmentManagerTemplate(), {}),
    );
  }

  Future<void> _generateSharedUi() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    final fileWriter = FileWriter();
    final engine = TemplateEngine();

    await fileWriter.write(
      paths.sharedUiFile('loading_indicator.dart'),
      engine.render(SharedUiTemplates.loadingIndicatorTemplate(), {}),
    );
    await fileWriter.write(
      paths.sharedUiFile('app_alert.dart'),
      engine.render(SharedUiTemplates.appAlertTemplate(), {}),
    );
    await fileWriter.write(
      paths.sharedUiFile('maintenance_view.dart'),
      engine.render(SharedUiTemplates.maintenanceViewTemplate(), {}),
    );
    await fileWriter.write(
      paths.sharedUiFile('empty_state_view.dart'),
      engine.render(SharedUiTemplates.emptyStateViewTemplate(), {}),
    );
    await fileWriter.write(
      paths.sharedUiFile('error_state_view.dart'),
      engine.render(SharedUiTemplates.errorStateViewTemplate(), {}),
    );
    await fileWriter.write(
      paths.sharedUiFile('accessible.dart'),
      engine.render(SharedUiTemplates.accessibleTemplate(), {}),
    );
    if (includeFontSample) {
      await fileWriter.write(
        paths.sharedUiFile('font_sample.dart'),
        engine.render(SharedUiTemplates.fontSampleTemplate(config.fonts), {}),
      );
    }
    await regenerateSharedUiBarrel();
  }

  Future<void> regenerateSharedUiBarrel() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    final splashPresent =
        File(paths.sharedUiFile('splash_screen.dart')).existsSync();
    final fontSamplePresent =
        File(paths.sharedUiFile('font_sample.dart')).existsSync();
    await FileWriter().write(
      paths.sharedUiBarrelFile,
      TemplateEngine().render(
        SharedUiTemplates.sharedUiBarrelTemplate(
          splashPresent: splashPresent,
          fontSamplePresent: fontSamplePresent,
        ),
        {},
      ),
    );
  }

  Future<void> _generateSharedUiTests() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    final fileWriter = FileWriter();
    final engine = TemplateEngine();

    await fileWriter.write(
      paths.testSharedUiFile,
      engine.render(
        SharedUiTemplates.sharedUiTestTemplate(),
        {'projectName': config.projectName},
      ),
    );
  }

  Future<void> _generateServices() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    await ServiceGenerator().generate(
      services: config.services,
      projectName: config.projectName,
      paths: paths,
      fileWriter: FileWriter(),
      network: config.network,
      storage: config.storage,
      fonts: config.fonts,
    );
  }

  Future<void> _generateServiceTests() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    await ServiceGenerator().generateTests(
      services: config.services,
      projectName: config.projectName,
      paths: paths,
      fileWriter: FileWriter(),
      network: config.network,
      storage: config.storage,
      fonts: config.fonts,
    );
  }

  Future<void> _generateDebug() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    await DebugFeatureGenerator().generate(
      config.architecture,
      config.stateManagement,
      paths,
      FileWriter(),
    );
  }

  Future<void> _generateDebugTests() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    await DebugFeatureGenerator().generateTests(
      architecture: config.architecture,
      stateManagement: config.stateManagement,
      storage: config.storage,
      paths: paths,
      fileWriter: FileWriter(),
      projectName: config.projectName,
    );
  }

  Future<void> regenerateRouting() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    final generator = RoutingGenerator();
    final content = generator.generate(
      homeFeatureName: config.homeFeatureName,
      otherFeatures: config.initialFeatures,
    );
    await FileWriter().write(paths.servicesRoutingFile, content);

    final testContent = generator.generateTest(
      homeFeatureName: config.homeFeatureName,
      projectName: config.projectName,
      otherFeatures: config.initialFeatures,
    );
    await FileWriter().write(paths.testServicesRoutingFile, testContent);
  }

  Future<void> _generateCoreTests() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    await CoreTestGenerator().generate(
      config: config,
      paths: paths,
      fileWriter: FileWriter(),
    );
  }

  Future<void> _generateMain() async {
    final paths = ProjectPaths(projectRoot: outputPath);
    final content = MainDartGenerator().generate(config);
    await FileWriter().write(paths.mainDartFile, content);
  }

  Future<void> generateDocumentation() async {
    final files = ProjectDocumentationGenerator().generateAll(config);
    final fileWriter = FileWriter();
    for (final entry in files.entries) {
      await fileWriter.write(path.join(outputPath, entry.key), entry.value);
    }
  }
}
