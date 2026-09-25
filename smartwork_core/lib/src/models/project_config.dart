import 'app_icon_config.dart';
import 'font_config.dart';
import 'localization_config.dart';
import 'service_definition.dart';
import 'splash_config.dart';

/// A platform the generated Flutter app runs on (an App Target).
enum AppTarget {
  /// Android.
  android,

  /// iOS.
  ios,

  /// Web.
  web,

  /// Windows.
  windows,

  /// macOS.
  macos,

  /// Linux.
  linux,
}

/// Folder and display names for an [AppTarget].
extension AppTargetPlatform on AppTarget {
  /// The platform folder `flutter create` makes for it, e.g. `ios`.
  String get platformFolder => name;

  /// Its human-readable name, e.g. `iOS`.
  String get displayName => switch (this) {
        AppTarget.android => 'Android',
        AppTarget.ios => 'iOS',
        AppTarget.web => 'Web',
        AppTarget.windows => 'Windows',
        AppTarget.macos => 'macOS',
        AppTarget.linux => 'Linux',
      };
}

/// The architecture a project's features are generated in.
enum Architecture {
  /// Clean Architecture: data, domain and presentation layers.
  cleanArchitecture,

  /// Model-View-ViewModel.
  mvvm,

  /// Model-View-Presenter.
  mvp,
}

/// The state management library a project's features use.
enum StateManagement {
  /// flutter_bloc's `Bloc` (events and states).
  bloc,

  /// flutter_bloc's `Cubit`.
  cubit,

  /// GetX.
  getx,

  /// Riverpod.
  riverpod,
}

/// The HTTP client the generated network service uses.
enum Network {
  /// The `http` package.
  http,

  /// The `dio` package.
  dio,

  /// Bring your own: SmartWork adds no dependency or networking code.
  other,
}

/// The local storage the generated storage service uses.
enum Storage {
  /// The `shared_preferences` package.
  sharedPreferences,

  /// The `hive_flutter` package.
  hive,

  /// Bring your own: SmartWork adds no dependency or persistence code.
  other,
}

/// A SmartWork project's configuration: everything `smartwork init` asks
/// for. Stored in the project's `.smartwork/project.yaml` (see
/// `ProjectConfigFile`) and updated by the other commands.
class ProjectConfig {
  /// The Dart package name, e.g. `shop_app`.
  final String projectName;

  /// The platforms the app runs on. Defaults to Android and iOS.
  final Set<AppTarget> appTargets;

  /// The architecture features are generated in.
  final Architecture architecture;

  /// The state management features use.
  final StateManagement stateManagement;

  /// The HTTP client of the network service.
  final Network network;

  /// The local storage of the storage service.
  final Storage storage;

  /// The selected Production Services, by `Service.id`.
  final Set<String> services;

  /// The app's font: none, a custom font file, or a Google Font.
  final FontConfig fonts;

  /// The app's localization, or [LocalizationConfig.disabled].
  final LocalizationConfig localization;

  /// The Splash Screen, if one was added with `smartwork splash`.
  final SplashConfig? splash;

  /// The App Icon, if one was set with `smartwork icon`.
  final AppIconConfig? appIcon;

  /// The features generated when the project was created.
  final List<String> initialFeatures;

  /// The feature used as the app's Home screen. Defaults to `home`.
  final String homeFeatureName;

  /// A configuration; omitted collections and choices use SmartWork's
  /// defaults (Android + iOS, no services, no font, no localization).
  ProjectConfig({
    required this.projectName,
    Set<AppTarget>? appTargets,
    required this.architecture,
    required this.stateManagement,
    required this.network,
    required this.storage,
    Set<String>? services,
    FontConfig? fonts,
    LocalizationConfig? localization,
    this.splash,
    this.appIcon,
    List<String>? initialFeatures,
    this.homeFeatureName = 'home',
  })  : appTargets = appTargets ?? {AppTarget.android, AppTarget.ios},
        services = services ?? {},
        fonts = fonts ?? FontConfig.none(),
        localization = localization ?? LocalizationConfig.disabled(),
        initialFeatures = initialFeatures ?? [];

  /// A copy with the given settings replaced.
  ProjectConfig copyWith({
    Set<AppTarget>? appTargets,
    Set<String>? services,
    FontConfig? fonts,
    LocalizationConfig? localization,
    SplashConfig? splash,
    AppIconConfig? appIcon,
    List<String>? initialFeatures,
  }) {
    return ProjectConfig(
      projectName: projectName,
      appTargets: appTargets ?? this.appTargets,
      architecture: architecture,
      stateManagement: stateManagement,
      network: network,
      storage: storage,
      services: services ?? this.services,
      fonts: fonts ?? this.fonts,
      localization: localization ?? this.localization,
      splash: splash ?? this.splash,
      appIcon: appIcon ?? this.appIcon,
      initialFeatures: initialFeatures ?? this.initialFeatures,
      homeFeatureName: homeFeatureName,
    );
  }

  /// [appTargets] in [AppTarget] declaration order.
  List<AppTarget> get orderedAppTargets =>
      AppTarget.values.where(appTargets.contains).toList();

  /// [services] as [Service]s, in [Service] declaration order.
  List<Service> get orderedServices =>
      Service.values.where((s) => services.contains(s.id)).toList();

  /// Reads a configuration from `.smartwork/project.yaml` contents.
  factory ProjectConfig.fromYaml(Map<String, dynamic> yaml) {
    return ProjectConfig(
      projectName: yaml['projectName'] as String,
      appTargets: _parseAppTargets(yaml),
      architecture: Architecture.values.byName(yaml['architecture'] as String),
      stateManagement:
          StateManagement.values.byName(yaml['stateManagement'] as String),
      network: Network.values.byName(yaml['network'] as String),
      storage: Storage.values.byName(yaml['storage'] as String),
      services: Set.from(yaml['services'] as List? ?? []),
      fonts: FontConfig.fromYaml(
        (yaml['fonts'] as Map?)?.cast<String, dynamic>(),
      ),
      localization: LocalizationConfig.fromYaml(
        (yaml['localization'] as Map?)?.cast<String, dynamic>(),
      ),
      splash: yaml['splash'] != null
          ? SplashConfig.fromYaml(
              (yaml['splash'] as Map).cast<String, dynamic>(),
            )
          : null,
      appIcon: yaml['appIcon'] != null
          ? AppIconConfig.fromYaml(
              (yaml['appIcon'] as Map).cast<String, dynamic>(),
            )
          : null,
      initialFeatures: List.from(yaml['initialFeatures'] as List? ?? []),
      homeFeatureName: yaml['homeFeatureName'] as String? ?? 'home',
    );
  }

  static Set<AppTarget> _parseAppTargets(Map<String, dynamic> yaml) {
    if (yaml.containsKey('appTargets')) {
      final raw = yaml['appTargets'] as List? ?? [];
      return raw.map((v) => AppTarget.values.byName(v as String)).toSet();
    }
    return Set<AppTarget>.from(AppTarget.values);
  }

  /// The configuration as written to `.smartwork/project.yaml`.
  Map<String, dynamic> toYaml() {
    return {
      'projectName': projectName,
      'appTargets': orderedAppTargets.map((t) => t.name).toList(),
      'architecture': architecture.name,
      'stateManagement': stateManagement.name,
      'network': network.name,
      'storage': storage.name,
      'services': orderedServices.map((s) => s.id).toList(),
      'fonts': fonts.toYaml(),
      'localization': localization.toYaml(),
      if (splash != null) 'splash': splash!.toYaml(),
      if (appIcon != null) 'appIcon': appIcon!.toYaml(),
      'initialFeatures': initialFeatures,
      'homeFeatureName': homeFeatureName,
    };
  }
}
