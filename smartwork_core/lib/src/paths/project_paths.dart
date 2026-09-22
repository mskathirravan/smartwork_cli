import 'package:path/path.dart' as path;

class ProjectPaths {
  final String projectRoot;

  ProjectPaths({required this.projectRoot});

  String get lib => path.join(projectRoot, 'lib');

  String get test => path.join(projectRoot, 'test');

  String get readmeFile => path.join(projectRoot, 'README.md');

  String get docs => path.join(projectRoot, 'docs');

  String docFile(String fileName) => path.join(docs, fileName);

  String get assets => path.join(projectRoot, 'assets');

  String get assetsImages => path.join(assets, 'images');

  String get assetsFonts => path.join(assets, 'fonts');

  String get assetsIcons => path.join(assets, 'icons');

  String get assetsAnimations => path.join(assets, 'animations');

  String get smartworkDir => path.join(projectRoot, '.smartwork');

  String get projectConfigFile => path.join(smartworkDir, 'project.yaml');

  String get pubspecFile => path.join(projectRoot, 'pubspec.yaml');

  String get l10nConfigFile => path.join(projectRoot, 'l10n.yaml');

  String get l10n => path.join(lib, 'l10n');

  String l10nArbFile(String locale) => path.join(l10n, 'app_$locale.arb');

  String get mainDartFile => path.join(lib, 'main.dart');

  String get core => path.join(lib, 'core');

  String get coreConstants => path.join(lib, 'core', 'constants');

  String get coreConstantsAppFile =>
      path.join(coreConstants, 'app_constants.dart');

  String get coreConstantsApiFile =>
      path.join(coreConstants, 'api_constants.dart');

  String get coreConstantsAssetFile =>
      path.join(coreConstants, 'asset_constants.dart');

  String get coreConstantsStorageFile =>
      path.join(coreConstants, 'storage_constants.dart');

  String get coreConstantsColorsFile =>
      path.join(coreConstants, 'app_colors.dart');

  String get coreConstantsDimensionsFile =>
      path.join(coreConstants, 'app_dimensions.dart');

  String get coreConstantsScreenDimensionsFile =>
      path.join(coreConstants, 'screen_dimensions.dart');

  String get coreConstantsBarrelFile =>
      path.join(coreConstants, 'constants.dart');

  String get coreUtilities => path.join(lib, 'core', 'utilities');

  String get coreUtilitiesAppPlatformFile =>
      path.join(coreUtilities, 'app_platform.dart');

  String get coreUtilitiesDateTimeExtensionsFile =>
      path.join(coreUtilities, 'date_time_extensions.dart');

  String get coreUtilitiesStringExtensionsFile =>
      path.join(coreUtilities, 'string_extensions.dart');

  String get coreUtilitiesColorHexFile =>
      path.join(coreUtilities, 'color_hex.dart');

  String get coreUtilitiesFileSizeFile =>
      path.join(coreUtilities, 'file_size.dart');

  String get coreUtilitiesBarrelFile =>
      path.join(coreUtilities, 'utilities.dart');

  String get coreEnvironment => path.join(lib, 'core', 'environment');

  String get coreEnvironmentFile =>
      path.join(coreEnvironment, 'environment.dart');

  String get coreEnvironmentUrlsFile =>
      path.join(coreEnvironment, 'environment_urls.dart');

  String get coreEnvironmentManagerFile =>
      path.join(coreEnvironment, 'environment_manager.dart');

  String get testCore => path.join(test, 'core');

  String get testCoreConstantsFile =>
      path.join(testCore, 'constants', 'constants_test.dart');

  String get testCoreScreenDimensionsFile =>
      path.join(testCore, 'constants', 'screen_dimensions_test.dart');

  String get testCoreUtilitiesAppPlatformFile =>
      path.join(testCore, 'utilities', 'app_platform_test.dart');

  String get testCoreUtilitiesDateTimeExtensionsFile =>
      path.join(testCore, 'utilities', 'date_time_extensions_test.dart');

  String get testCoreUtilitiesStringExtensionsFile =>
      path.join(testCore, 'utilities', 'string_extensions_test.dart');

  String get testCoreUtilitiesColorHexFile =>
      path.join(testCore, 'utilities', 'color_hex_test.dart');

  String get testCoreUtilitiesFileSizeFile =>
      path.join(testCore, 'utilities', 'file_size_test.dart');

  String get testCoreEnvironmentFile =>
      path.join(testCore, 'environment', 'environment_test.dart');

  String get sharedUi => path.join(lib, 'shared', 'ui');

  String sharedUiFile(String fileName) => path.join(sharedUi, fileName);

  String get sharedUiBarrelFile => path.join(sharedUi, 'shared_ui.dart');

  String get testSharedUi => path.join(test, 'shared', 'ui');

  String get testSharedUiFile => path.join(testSharedUi, 'shared_ui_test.dart');

  String get features => path.join(lib, 'features');

  String get testFeatures => path.join(test, 'features');

  String featurePath(String featureName) => path.join(features, featureName);

  String featureFile(String featureName, String filePath) =>
      path.join(featurePath(featureName), filePath);

  String testFeaturePath(String featureName) =>
      path.join(testFeatures, featureName);

  String testFeatureFile(String featureName, String filePath) =>
      path.join(testFeaturePath(featureName), filePath);

  String get featuresDebug => featurePath('debug');

  String get featuresDebugFile => path.join(featuresDebug, 'debug.dart');

  String featuresDebugFileAt(List<String> relativeSegments) =>
      path.joinAll([featuresDebug, ...relativeSegments]);

  String testFeaturesDebugFileAt(List<String> relativeSegments) =>
      path.joinAll([testFeaturesDebug, ...relativeSegments]);

  String get featuresDebugPushTestServiceFile =>
      path.join(featuresDebug, 'push_test_service.dart');

  String get featuresDebugPageFileClean =>
      path.join(featuresDebug, 'presentation', 'pages', 'debug_page.dart');

  String get featuresDebugPageFileMvvm =>
      path.join(featuresDebug, 'views', 'debug_page.dart');

  String get featuresDebugViewModelFileMvvm =>
      path.join(featuresDebug, 'viewmodels', 'debug_view_model.dart');

  String get featuresDebugPageFileMvp =>
      path.join(featuresDebug, 'views', 'debug_page.dart');

  String get featuresDebugPresenterFileMvp =>
      path.join(featuresDebug, 'presenters', 'debug_presenter.dart');

  String get testFeaturesDebug => testFeaturePath('debug');

  String get testFeaturesDebugPushTestServiceFile =>
      path.join(testFeaturesDebug, 'push_test_service_test.dart');

  String get testFeaturesDebugPageFileClean => path.join(
      testFeaturesDebug, 'presentation', 'pages', 'debug_page_test.dart');

  String get testFeaturesDebugPageFileMvvm =>
      path.join(testFeaturesDebug, 'views', 'debug_page_test.dart');

  String get testFeaturesDebugPageFileMvp =>
      path.join(testFeaturesDebug, 'views', 'debug_page_test.dart');

  String get services => path.join(lib, 'services');

  String get servicesBarrelFile => path.join(services, 'services.dart');

  String get testServices => path.join(test, 'services');

  String serviceFolderFile(String folderName, String fileName) =>
      path.join(services, folderName, fileName);

  String testServiceFolderFile(String folderName, String fileName) =>
      path.join(testServices, folderName, fileName);

  String get servicesNetwork => path.join(services, 'network');

  String get servicesNetworkServiceFile =>
      path.join(servicesNetwork, 'network_service.dart');

  String get servicesNetworkExceptionFile =>
      path.join(servicesNetwork, 'network_exception.dart');

  String get servicesNetworkResponseFile =>
      path.join(servicesNetwork, 'network_response.dart');

  String get testServicesNetwork => path.join(testServices, 'network');

  String get testServicesNetworkServiceFile =>
      path.join(testServicesNetwork, 'network_service_test.dart');

  String get servicesStorage => path.join(services, 'storage');

  String get servicesStorageServiceFile =>
      path.join(servicesStorage, 'storage_service.dart');

  String get testServicesStorage => path.join(testServices, 'storage');

  String get testServicesStorageServiceFile =>
      path.join(testServicesStorage, 'storage_service_test.dart');

  String get servicesTheme => path.join(services, 'theme');

  String get servicesThemeServiceFile =>
      path.join(servicesTheme, 'theme_service.dart');

  String get servicesAppThemeFile => path.join(servicesTheme, 'app_theme.dart');

  String get testServicesTheme => path.join(testServices, 'theme');

  String get testServicesThemeServiceFile =>
      path.join(testServicesTheme, 'theme_service_test.dart');

  String get testServicesAppThemeFile =>
      path.join(testServicesTheme, 'app_theme_test.dart');

  String get servicesBootstrap => path.join(services, 'bootstrap');

  String get servicesBootstrapFile =>
      path.join(servicesBootstrap, 'bootstrap.dart');

  String get testServicesBootstrap => path.join(testServices, 'bootstrap');

  String get testServicesBootstrapFile =>
      path.join(testServicesBootstrap, 'bootstrap_test.dart');

  String get servicesRouting => path.join(services, 'routing');

  String get servicesRoutingFile =>
      path.join(servicesRouting, 'app_router.dart');

  String get testServicesRouting => path.join(testServices, 'routing');

  String get testServicesRoutingFile =>
      path.join(testServicesRouting, 'app_router_test.dart');
}
