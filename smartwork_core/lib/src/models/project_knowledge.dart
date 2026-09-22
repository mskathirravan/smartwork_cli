import 'feature_config.dart';
import 'project_config.dart';

enum DiscoveryConfidence { declared, detected, inferred, unknown }

class DiscoveredValue<T> {
  final T value;
  final DiscoveryConfidence confidence;
  final List<String> evidence;

  const DiscoveredValue(
    this.value, {
    required this.confidence,
    this.evidence = const [],
  });
}

class ProjectInfo {
  final String name;
  final String path;
  final bool isFlutterProject;
  final bool isSmartworkProject;

  ProjectInfo({
    required this.name,
    required this.path,
    required this.isFlutterProject,
    required this.isSmartworkProject,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'isFlutterProject': isFlutterProject,
        'isSmartworkProject': isSmartworkProject,
      };
}

class FrameworkInfo {
  final String? dartSdkConstraint;
  final String? flutterSdkConstraint;

  FrameworkInfo({this.dartSdkConstraint, this.flutterSdkConstraint});

  Map<String, dynamic> toJson() => {
        'dartSdkConstraint': dartSdkConstraint,
        'flutterSdkConstraint': flutterSdkConstraint,
      };
}

class DependencyInfo {
  final String name;
  final String versionConstraint;
  final bool isDev;

  DependencyInfo({
    required this.name,
    required this.versionConstraint,
    required this.isDev,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'versionConstraint': versionConstraint,
        'isDev': isDev,
      };
}

enum DependencyInjectionKind {
  staticSingleton,

  getIt,

  injectable,

  providerAsDI,

  getXServiceLocator,

  riverpodRef,

  none,
}

class FeatureKnowledge {
  final String name;
  final String path;
  final Set<FeatureComponent> components;
  final bool hasState;
  final DiscoveryConfidence confidence;
  final List<String> evidence;

  FeatureKnowledge({
    required this.name,
    required this.path,
    required this.components,
    required this.hasState,
    required this.confidence,
    this.evidence = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'components': components.map((c) => c.name).toList(),
        'hasState': hasState,
        'confidence': confidence.name,
        'evidence': evidence,
      };
}

class TestKnowledge {
  final bool hasTestDirectory;
  final bool mirrorsFeatureStructure;
  final List<String> declaredTestingPackages;
  final bool hasDetectedTestCalls;

  TestKnowledge({
    required this.hasTestDirectory,
    required this.mirrorsFeatureStructure,
    required this.declaredTestingPackages,
    required this.hasDetectedTestCalls,
  });

  Map<String, dynamic> toJson() => {
        'hasTestDirectory': hasTestDirectory,
        'mirrorsFeatureStructure': mirrorsFeatureStructure,
        'declaredTestingPackages': declaredTestingPackages,
        'hasDetectedTestCalls': hasDetectedTestCalls,
      };
}

class ProjectKnowledge {
  final DiscoveredValue<ProjectInfo> project;
  final DiscoveredValue<FrameworkInfo> framework;
  final DiscoveredValue<Set<AppTarget>> platforms;
  final DiscoveredValue<List<DependencyInfo>> dependencies;
  final DiscoveredValue<Architecture?> architecture;
  final DiscoveredValue<StateManagement?> stateManagement;
  final DiscoveredValue<DependencyInjectionKind> dependencyInjection;
  final DiscoveredValue<List<FeatureKnowledge>> features;
  final DiscoveredValue<TestKnowledge> tests;

  ProjectKnowledge({
    required this.project,
    required this.framework,
    required this.platforms,
    required this.dependencies,
    required this.architecture,
    required this.stateManagement,
    required this.dependencyInjection,
    required this.features,
    required this.tests,
  });

  Map<String, dynamic> toJson() => {
        'project': {
          'value': project.value.toJson(),
          'confidence': project.confidence.name,
          'evidence': project.evidence,
        },
        'framework': {
          'value': framework.value.toJson(),
          'confidence': framework.confidence.name,
          'evidence': framework.evidence,
        },
        'platforms': {
          'value': platforms.value.map((t) => t.name).toList(),
          'confidence': platforms.confidence.name,
          'evidence': platforms.evidence,
        },
        'dependencies': {
          'value': dependencies.value.map((d) => d.toJson()).toList(),
          'confidence': dependencies.confidence.name,
          'evidence': dependencies.evidence,
        },
        'architecture': {
          'value': architecture.value?.name,
          'confidence': architecture.confidence.name,
          'evidence': architecture.evidence,
        },
        'stateManagement': {
          'value': stateManagement.value?.name,
          'confidence': stateManagement.confidence.name,
          'evidence': stateManagement.evidence,
        },
        'dependencyInjection': {
          'value': dependencyInjection.value.name,
          'confidence': dependencyInjection.confidence.name,
          'evidence': dependencyInjection.evidence,
        },
        'features': {
          'value': features.value.map((f) => f.toJson()).toList(),
          'confidence': features.confidence.name,
          'evidence': features.evidence,
        },
        'tests': {
          'value': tests.value.toJson(),
          'confidence': tests.confidence.name,
          'evidence': tests.evidence,
        },
      };
}
