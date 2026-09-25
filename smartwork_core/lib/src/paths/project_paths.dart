import 'package:path/path.dart' as path;

/// Where every file and folder of a SmartWork project lives, relative to
/// [projectRoot]. All paths use the host platform's separator.
class ProjectPaths {
  /// The project's root directory (the folder containing `pubspec.yaml`).
  final String projectRoot;

  /// Paths for the project at [projectRoot].
  ProjectPaths({required this.projectRoot});

  /// The project's `lib/` directory.
  String get lib => path.join(projectRoot, 'lib');

  /// The project's `test/` directory.
  String get test => path.join(projectRoot, 'test');

  /// The project's `README.md` file.
  String get readmeFile => path.join(projectRoot, 'README.md');

  /// The project's `docs/` directory.
  String get docs => path.join(projectRoot, 'docs');

  /// A file named [fileName] in the project's `docs/` directory.
  String docFile(String fileName) => path.join(docs, fileName);

  /// The project's `assets/` directory.
  String get assets => path.join(projectRoot, 'assets');

  /// The project's `assets/images/` directory.
  String get assetsImages => path.join(assets, 'images');

  /// The project's `assets/fonts/` directory.
  String get assetsFonts => path.join(assets, 'fonts');

  /// The project's `assets/icons/` directory.
  String get assetsIcons => path.join(assets, 'icons');

  /// The project's `assets/animations/` directory.
  String get assetsAnimations => path.join(assets, 'animations');

  /// The project's `.smartwork/` directory.
  String get smartworkDir => path.join(projectRoot, '.smartwork');

  /// The project's `.smartwork/project.yaml` file.
  String get projectConfigFile => path.join(smartworkDir, 'project.yaml');

  /// The project's `pubspec.yaml` file.
  String get pubspecFile => path.join(projectRoot, 'pubspec.yaml');

  /// The project's `l10n.yaml` file.
  String get l10nConfigFile => path.join(projectRoot, 'l10n.yaml');

  /// The project's `lib/l10n/` directory.
  String get l10n => path.join(lib, 'l10n');

  /// The ARB file for [locale], e.g. `lib/l10n/app_fr.arb`.
  String l10nArbFile(String locale) => path.join(l10n, 'app_$locale.arb');

  /// The project's `lib/main.dart` file.
  String get mainDartFile => path.join(lib, 'main.dart');

  /// The project's `lib/core/` directory.
  String get core => path.join(lib, 'core');

  /// The project's `lib/core/constants/` directory.
  String get coreConstants => path.join(lib, 'core', 'constants');

  /// The project's `lib/core/constants/app_constants.dart` file.
  String get coreConstantsAppFile =>
      path.join(coreConstants, 'app_constants.dart');

  /// The project's `lib/core/constants/api_constants.dart` file.
  String get coreConstantsApiFile =>
      path.join(coreConstants, 'api_constants.dart');

  /// The project's `lib/core/constants/asset_constants.dart` file.
  String get coreConstantsAssetFile =>
      path.join(coreConstants, 'asset_constants.dart');

  /// The project's `lib/core/constants/storage_constants.dart` file.
  String get coreConstantsStorageFile =>
      path.join(coreConstants, 'storage_constants.dart');

  /// The project's `lib/core/constants/app_colors.dart` file.
  String get coreConstantsColorsFile =>
      path.join(coreConstants, 'app_colors.dart');

  /// The project's `lib/core/constants/app_dimensions.dart` file.
  String get coreConstantsDimensionsFile =>
      path.join(coreConstants, 'app_dimensions.dart');

  /// The project's `lib/core/constants/screen_dimensions.dart` file.
  String get coreConstantsScreenDimensionsFile =>
      path.join(coreConstants, 'screen_dimensions.dart');

  /// The project's `lib/core/constants/constants.dart` file.
  String get coreConstantsBarrelFile =>
      path.join(coreConstants, 'constants.dart');

  /// The project's `lib/core/utilities/` directory.
  String get coreUtilities => path.join(lib, 'core', 'utilities');

  /// The project's `lib/core/utilities/app_platform.dart` file.
  String get coreUtilitiesAppPlatformFile =>
      path.join(coreUtilities, 'app_platform.dart');

  /// The project's `lib/core/utilities/date_time_extensions.dart` file.
  String get coreUtilitiesDateTimeExtensionsFile =>
      path.join(coreUtilities, 'date_time_extensions.dart');

  /// The project's `lib/core/utilities/string_extensions.dart` file.
  String get coreUtilitiesStringExtensionsFile =>
      path.join(coreUtilities, 'string_extensions.dart');

  /// The project's `lib/core/utilities/color_hex.dart` file.
  String get coreUtilitiesColorHexFile =>
      path.join(coreUtilities, 'color_hex.dart');

  /// The project's `lib/core/utilities/file_size.dart` file.
  String get coreUtilitiesFileSizeFile =>
      path.join(coreUtilities, 'file_size.dart');

  /// The project's `lib/core/utilities/utilities.dart` file.
  String get coreUtilitiesBarrelFile =>
      path.join(coreUtilities, 'utilities.dart');

  /// The project's `lib/core/environment/` directory.
  String get coreEnvironment => path.join(lib, 'core', 'environment');

  /// The project's `lib/core/environment/environment.dart` file.
  String get coreEnvironmentFile =>
      path.join(coreEnvironment, 'environment.dart');

  /// The project's `lib/core/environment/environment_urls.dart` file.
  String get coreEnvironmentUrlsFile =>
      path.join(coreEnvironment, 'environment_urls.dart');

  /// The project's `lib/core/environment/environment_manager.dart` file.
  String get coreEnvironmentManagerFile =>
      path.join(coreEnvironment, 'environment_manager.dart');

  /// The project's `test/core/` directory.
  String get testCore => path.join(test, 'core');

  /// The project's `test/core/constants/constants_test.dart` file.
  String get testCoreConstantsFile =>
      path.join(testCore, 'constants', 'constants_test.dart');

  /// The project's `test/core/constants/screen_dimensions_test.dart` file.
  String get testCoreScreenDimensionsFile =>
      path.join(testCore, 'constants', 'screen_dimensions_test.dart');

  /// The project's `test/core/utilities/app_platform_test.dart` file.
  String get testCoreUtilitiesAppPlatformFile =>
      path.join(testCore, 'utilities', 'app_platform_test.dart');

  /// The project's `test/core/utilities/date_time_extensions_test.dart` file.
  String get testCoreUtilitiesDateTimeExtensionsFile =>
      path.join(testCore, 'utilities', 'date_time_extensions_test.dart');

  /// The project's `test/core/utilities/string_extensions_test.dart` file.
  String get testCoreUtilitiesStringExtensionsFile =>
      path.join(testCore, 'utilities', 'string_extensions_test.dart');

  /// The project's `test/core/utilities/color_hex_test.dart` file.
  String get testCoreUtilitiesColorHexFile =>
      path.join(testCore, 'utilities', 'color_hex_test.dart');

  /// The project's `test/core/utilities/file_size_test.dart` file.
  String get testCoreUtilitiesFileSizeFile =>
      path.join(testCore, 'utilities', 'file_size_test.dart');

  /// The project's `test/core/environment/environment_test.dart` file.
  String get testCoreEnvironmentFile =>
      path.join(testCore, 'environment', 'environment_test.dart');

  /// The project's `lib/shared/ui/` directory.
  String get sharedUi => path.join(lib, 'shared', 'ui');

  /// A file named [fileName] in `lib/shared/ui/`.
  String sharedUiFile(String fileName) => path.join(sharedUi, fileName);

  /// The project's `lib/shared/ui/shared_ui.dart` file.
  String get sharedUiBarrelFile => path.join(sharedUi, 'shared_ui.dart');

  /// The project's `test/shared/ui/` directory.
  String get testSharedUi => path.join(test, 'shared', 'ui');

  /// The project's `test/shared/ui/shared_ui_test.dart` file.
  String get testSharedUiFile => path.join(testSharedUi, 'shared_ui_test.dart');

  /// The project's `lib/features/` directory.
  String get features => path.join(lib, 'features');

  /// The project's `test/features/` directory.
  String get testFeatures => path.join(test, 'features');

  /// The folder of feature [featureName]: `lib/features/<featureName>/`.
  String featurePath(String featureName) => path.join(features, featureName);

  /// [filePath] inside feature [featureName]'s folder.
  String featureFile(String featureName, String filePath) =>
      path.join(featurePath(featureName), filePath);

  /// The test folder of feature [featureName]:
  /// `test/features/<featureName>/`.
  String testFeaturePath(String featureName) =>
      path.join(testFeatures, featureName);

  /// [filePath] inside feature [featureName]'s test folder.
  String testFeatureFile(String featureName, String filePath) =>
      path.join(testFeaturePath(featureName), filePath);

  /// The project's `lib/features/debug/` directory.
  String get featuresDebug => featurePath('debug');

  /// The project's `lib/features/debug/debug.dart` file.
  String get featuresDebugFile => path.join(featuresDebug, 'debug.dart');

  /// A file inside the Debug feature, from its path segments.
  String featuresDebugFileAt(List<String> relativeSegments) =>
      path.joinAll([featuresDebug, ...relativeSegments]);

  /// A file inside the Debug feature's tests, from its path segments.
  String testFeaturesDebugFileAt(List<String> relativeSegments) =>
      path.joinAll([testFeaturesDebug, ...relativeSegments]);

  /// The project's `lib/features/debug/push_test_service.dart` file.
  String get featuresDebugPushTestServiceFile =>
      path.join(featuresDebug, 'push_test_service.dart');

  /// The project's `lib/features/debug/presentation/pages/debug_page.dart` file.
  String get featuresDebugPageFileClean =>
      path.join(featuresDebug, 'presentation', 'pages', 'debug_page.dart');

  /// The project's `lib/features/debug/views/debug_page.dart` file.
  String get featuresDebugPageFileMvvm =>
      path.join(featuresDebug, 'views', 'debug_page.dart');

  /// The project's `lib/features/debug/viewmodels/debug_view_model.dart` file.
  String get featuresDebugViewModelFileMvvm =>
      path.join(featuresDebug, 'viewmodels', 'debug_view_model.dart');

  /// The project's `lib/features/debug/views/debug_page.dart` file.
  String get featuresDebugPageFileMvp =>
      path.join(featuresDebug, 'views', 'debug_page.dart');

  /// The project's `lib/features/debug/presenters/debug_presenter.dart` file.
  String get featuresDebugPresenterFileMvp =>
      path.join(featuresDebug, 'presenters', 'debug_presenter.dart');

  /// The project's `test/features/debug/` directory.
  String get testFeaturesDebug => testFeaturePath('debug');

  /// The project's `test/features/debug/push_test_service_test.dart` file.
  String get testFeaturesDebugPushTestServiceFile =>
      path.join(testFeaturesDebug, 'push_test_service_test.dart');

  /// The project's `test/features/debug/presentation/pages/debug_page_test.dart` file.
  String get testFeaturesDebugPageFileClean => path.join(
      testFeaturesDebug, 'presentation', 'pages', 'debug_page_test.dart');

  /// The project's `test/features/debug/views/debug_page_test.dart` file.
  String get testFeaturesDebugPageFileMvvm =>
      path.join(testFeaturesDebug, 'views', 'debug_page_test.dart');

  /// The project's `test/features/debug/views/debug_page_test.dart` file.
  String get testFeaturesDebugPageFileMvp =>
      path.join(testFeaturesDebug, 'views', 'debug_page_test.dart');

  /// The project's `lib/services/` directory.
  String get services => path.join(lib, 'services');

  /// The project's `lib/services/services.dart` file.
  String get servicesBarrelFile => path.join(services, 'services.dart');

  /// The project's `test/services/` directory.
  String get testServices => path.join(test, 'services');

  /// [fileName] in the service folder `lib/services/<folderName>/`.
  String serviceFolderFile(String folderName, String fileName) =>
      path.join(services, folderName, fileName);

  /// [fileName] in the service test folder
  /// `test/services/<folderName>/`.
  String testServiceFolderFile(String folderName, String fileName) =>
      path.join(testServices, folderName, fileName);

  /// The project's `lib/services/network/` directory.
  String get servicesNetwork => path.join(services, 'network');

  /// The project's `lib/services/network/network_service.dart` file.
  String get servicesNetworkServiceFile =>
      path.join(servicesNetwork, 'network_service.dart');

  /// The project's `lib/services/network/network_exception.dart` file.
  String get servicesNetworkExceptionFile =>
      path.join(servicesNetwork, 'network_exception.dart');

  /// The project's `lib/services/network/network_response.dart` file.
  String get servicesNetworkResponseFile =>
      path.join(servicesNetwork, 'network_response.dart');

  /// The project's `test/services/network/` directory.
  String get testServicesNetwork => path.join(testServices, 'network');

  /// The project's `test/services/network/network_service_test.dart` file.
  String get testServicesNetworkServiceFile =>
      path.join(testServicesNetwork, 'network_service_test.dart');

  /// The project's `lib/services/storage/` directory.
  String get servicesStorage => path.join(services, 'storage');

  /// The project's `lib/services/storage/storage_service.dart` file.
  String get servicesStorageServiceFile =>
      path.join(servicesStorage, 'storage_service.dart');

  /// The project's `test/services/storage/` directory.
  String get testServicesStorage => path.join(testServices, 'storage');

  /// The project's `test/services/storage/storage_service_test.dart` file.
  String get testServicesStorageServiceFile =>
      path.join(testServicesStorage, 'storage_service_test.dart');

  /// The project's `lib/services/theme/` directory.
  String get servicesTheme => path.join(services, 'theme');

  /// The project's `lib/services/theme/theme_service.dart` file.
  String get servicesThemeServiceFile =>
      path.join(servicesTheme, 'theme_service.dart');

  /// The project's `lib/services/theme/app_theme.dart` file.
  String get servicesAppThemeFile => path.join(servicesTheme, 'app_theme.dart');

  /// The project's `test/services/theme/` directory.
  String get testServicesTheme => path.join(testServices, 'theme');

  /// The project's `test/services/theme/theme_service_test.dart` file.
  String get testServicesThemeServiceFile =>
      path.join(testServicesTheme, 'theme_service_test.dart');

  /// The project's `test/services/theme/app_theme_test.dart` file.
  String get testServicesAppThemeFile =>
      path.join(testServicesTheme, 'app_theme_test.dart');

  /// The project's `lib/services/bootstrap/` directory.
  String get servicesBootstrap => path.join(services, 'bootstrap');

  /// The project's `lib/services/bootstrap/bootstrap.dart` file.
  String get servicesBootstrapFile =>
      path.join(servicesBootstrap, 'bootstrap.dart');

  /// The project's `test/services/bootstrap/` directory.
  String get testServicesBootstrap => path.join(testServices, 'bootstrap');

  /// The project's `test/services/bootstrap/bootstrap_test.dart` file.
  String get testServicesBootstrapFile =>
      path.join(testServicesBootstrap, 'bootstrap_test.dart');

  /// The project's `lib/services/routing/` directory.
  String get servicesRouting => path.join(services, 'routing');

  /// The project's `lib/services/routing/app_router.dart` file.
  String get servicesRoutingFile =>
      path.join(servicesRouting, 'app_router.dart');

  /// The project's `test/services/routing/` directory.
  String get testServicesRouting => path.join(testServices, 'routing');

  /// The project's `test/services/routing/app_router_test.dart` file.
  String get testServicesRoutingFile =>
      path.join(testServicesRouting, 'app_router_test.dart');
}
