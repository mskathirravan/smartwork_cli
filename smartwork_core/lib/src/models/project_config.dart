import 'app_icon_config.dart';
import 'font_config.dart';
import 'localization_config.dart';
import 'service_definition.dart';
import 'splash_config.dart';

enum AppTarget { android, ios, web, windows, macos, linux }

extension AppTargetPlatform on AppTarget {
  String get platformFolder => name;

  String get displayName => switch (this) {
        AppTarget.android => 'Android',
        AppTarget.ios => 'iOS',
        AppTarget.web => 'Web',
        AppTarget.windows => 'Windows',
        AppTarget.macos => 'macOS',
        AppTarget.linux => 'Linux',
      };
}

enum Architecture { cleanArchitecture, mvvm, mvp }

enum StateManagement { bloc, cubit, getx, riverpod }

enum Network { http, dio, other }

enum Storage { sharedPreferences, hive, other }

class ProjectConfig {
  final String projectName;

  final Set<AppTarget> appTargets;
  final Architecture architecture;
  final StateManagement stateManagement;
  final Network network;
  final Storage storage;

  final Set<String> services;

  final FontConfig fonts;

  final LocalizationConfig localization;

  final SplashConfig? splash;

  final AppIconConfig? appIcon;
  final List<String> initialFeatures;

  final String homeFeatureName;

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

  List<AppTarget> get orderedAppTargets =>
      AppTarget.values.where(appTargets.contains).toList();

  List<Service> get orderedServices =>
      Service.values.where((s) => services.contains(s.id)).toList();

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
