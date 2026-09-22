import '../../models/project_config.dart';
import '../../models/project_knowledge.dart';
import '../../validator/target_state_detector.dart';
import 'architecture_analyzer.dart';
import 'dependency_analyzer.dart';
import 'dependency_injection_analyzer.dart';
import 'feature_analyzer.dart';
import 'project_scan_result.dart';
import 'project_scanner.dart';
import 'state_management_analyzer.dart';
import 'test_analyzer.dart';

class NotAFlutterProjectException implements Exception {
  final String projectPath;

  NotAFlutterProjectException(this.projectPath);

  @override
  String toString() =>
      'Not a Flutter project: "$projectPath" has no pubspec.yaml + lib/ '
      '+ platform folder, and no .smartwork/project.yaml.';
}

class DiscoverLifecycle {
  final ProjectScanner _scanner;
  final TargetStateDetector _detector;

  DiscoverLifecycle({
    ProjectScanner? scanner,
    TargetStateDetector? detector,
  })  : _scanner = scanner ?? ProjectScanner(),
        _detector = detector ?? TargetStateDetector();

  Future<ProjectKnowledge> discover(String projectPath) async {
    final detection = await _detector.detect(projectPath);

    if (detection.state == TargetProjectState.empty ||
        detection.state == TargetProjectState.nonFlutterProject) {
      throw NotAFlutterProjectException(projectPath);
    }

    final scan = await _scanner.scan(projectPath);
    final isSmartworkProject =
        detection.state == TargetProjectState.smartworkProject;
    final config = detection.existingConfig;

    return ProjectKnowledge(
      project: _projectInfo(projectPath, scan, detection, isSmartworkProject),
      framework: _framework(scan),
      platforms: _platforms(detection, config, isSmartworkProject),
      dependencies: DependencyAnalyzer().analyze(scan),
      architecture: isSmartworkProject
          ? DiscoveredValue(
              config!.architecture,
              confidence: DiscoveryConfidence.declared,
              evidence: [
                '.smartwork/project.yaml: architecture=${config.architecture.name}',
              ],
            )
          : ArchitectureAnalyzer().analyze(scan),
      stateManagement: isSmartworkProject
          ? DiscoveredValue(
              config!.stateManagement,
              confidence: DiscoveryConfidence.declared,
              evidence: [
                '.smartwork/project.yaml: stateManagement=${config.stateManagement.name}',
              ],
            )
          : StateManagementAnalyzer().analyze(scan),
      dependencyInjection: DependencyInjectionAnalyzer().analyze(scan),
      features: FeatureAnalyzer().analyze(scan),
      tests: TestAnalyzer().analyze(scan),
    );
  }

  DiscoveredValue<ProjectInfo> _projectInfo(
    String projectPath,
    ProjectScanResult scan,
    TargetStateDetectionResult detection,
    bool isSmartworkProject,
  ) {
    final looksLikeFlutterProject = scan.pubspecYaml != null &&
        scan.dartFiles.keys.any((p) => p.startsWith('lib/'));

    final name = isSmartworkProject
        ? detection.existingConfig!.projectName
        : (scan.pubspecYaml?['name'] as String?) ?? _basename(projectPath);

    final info = ProjectInfo(
      name: name,
      path: projectPath,
      isFlutterProject: looksLikeFlutterProject,
      isSmartworkProject: isSmartworkProject,
    );

    if (isSmartworkProject) {
      return DiscoveredValue(
        info,
        confidence: DiscoveryConfidence.declared,
        evidence: const ['.smartwork/project.yaml found and valid'],
      );
    }

    if (detection.state == TargetProjectState.malformedSmartworkProject) {
      return DiscoveredValue(
        info,
        confidence: looksLikeFlutterProject
            ? DiscoveryConfidence.detected
            : DiscoveryConfidence.unknown,
        evidence: [
          '.smartwork/project.yaml exists but could not be read: ${detection.detectionError}',
        ],
      );
    }

    return DiscoveredValue(
      info,
      confidence: DiscoveryConfidence.detected,
      evidence: const [
        'pubspec.yaml + lib/ + at least one platform folder found (no .smartwork/project.yaml)',
      ],
    );
  }

  DiscoveredValue<FrameworkInfo> _framework(ProjectScanResult scan) {
    final yaml = scan.pubspecYaml;
    if (yaml == null) {
      return DiscoveredValue(
        FrameworkInfo(),
        confidence: DiscoveryConfidence.unknown,
        evidence: const ['pubspec.yaml not found or could not be parsed'],
      );
    }

    final environment = yaml['environment'];
    String? dartSdk;
    String? flutterSdk;
    if (environment is Map) {
      dartSdk = environment['sdk']?.toString();
      flutterSdk = environment['flutter']?.toString();
    }

    return DiscoveredValue(
      FrameworkInfo(
          dartSdkConstraint: dartSdk, flutterSdkConstraint: flutterSdk),
      confidence: DiscoveryConfidence.declared,
      evidence: [
        if (dartSdk != null) 'pubspec.yaml: environment.sdk=$dartSdk',
        if (flutterSdk != null) 'pubspec.yaml: environment.flutter=$flutterSdk',
      ],
    );
  }

  DiscoveredValue<Set<AppTarget>> _platforms(
    TargetStateDetectionResult detection,
    ProjectConfig? config,
    bool isSmartworkProject,
  ) {
    if (isSmartworkProject) {
      return DiscoveredValue(
        config!.appTargets,
        confidence: DiscoveryConfidence.declared,
        evidence: const ['.smartwork/project.yaml: appTargets'],
      );
    }

    return DiscoveredValue(
      detection.existingPlatforms,
      confidence: detection.existingPlatforms.isEmpty
          ? DiscoveryConfidence.unknown
          : DiscoveryConfidence.detected,
      evidence: const ['Platform folder(s) found on disk'],
    );
  }

  String _basename(String projectPath) {
    final normalized = projectPath.replaceAll('\\', '/');
    final trimmed = normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    final slash = trimmed.lastIndexOf('/');
    return slash == -1 ? trimmed : trimmed.substring(slash + 1);
  }
}
