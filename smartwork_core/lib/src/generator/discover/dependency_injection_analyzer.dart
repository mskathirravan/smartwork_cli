import '../../models/project_knowledge.dart';
import 'project_scan_result.dart';

final _getItInstance = RegExp(r'GetIt\.instance\b');
final _getItGeneric = RegExp(r'\bgetIt\s*<');
final _refReadOrWatch = RegExp(r'\bref\.(read|watch)\s*\(');
final _getFindOrPut = RegExp(r'Get\.(find|put)\s*<');
final _providerOf = RegExp(r'Provider\.of\s*<');
final _contextRead = RegExp(r'context\.read\s*<');
final _staticSingleton =
    RegExp(r'static\s+final\s+\w+\s+instance\s*=\s*\w+\._\(\)\s*;');

class DependencyInjectionAnalyzer {
  DiscoveredValue<DependencyInjectionKind> analyze(ProjectScanResult scan) {
    final getItEvidence = <String>[];
    final injectableEvidence = <String>[];
    final riverpodEvidence = <String>[];
    final getxEvidence = <String>[];
    final providerEvidence = <String>[];
    final staticSingletonEvidence = <String>[];

    for (final entry in scan.dartFiles.entries) {
      final filePath = entry.key;
      final content = entry.value;

      if (_getItInstance.hasMatch(content) || _getItGeneric.hasMatch(content)) {
        getItEvidence.add('$filePath: GetIt.instance/getIt<T>() usage');
      }
      if (content.contains('@injectable') || content.contains('@Injectable')) {
        injectableEvidence.add('$filePath: @injectable annotation');
      }
      if (_refReadOrWatch.hasMatch(content)) {
        riverpodEvidence.add('$filePath: ref.read/ref.watch usage');
      }
      if (_getFindOrPut.hasMatch(content)) {
        getxEvidence.add('$filePath: Get.find</Get.put< usage');
      }
      if (_providerOf.hasMatch(content) || _contextRead.hasMatch(content)) {
        providerEvidence.add(
          '$filePath: Provider.of</context.read< usage (package:provider '
          'as DI)',
        );
      }
      if (_staticSingleton.hasMatch(content)) {
        staticSingletonEvidence.add(
          '$filePath: static singleton instance accessor',
        );
      }
    }

    if (getItEvidence.isNotEmpty) {
      return DiscoveredValue(
        DependencyInjectionKind.getIt,
        confidence: DiscoveryConfidence.detected,
        evidence: getItEvidence,
      );
    }
    if (injectableEvidence.isNotEmpty) {
      return DiscoveredValue(
        DependencyInjectionKind.injectable,
        confidence: DiscoveryConfidence.detected,
        evidence: injectableEvidence,
      );
    }
    if (getxEvidence.isNotEmpty) {
      return DiscoveredValue(
        DependencyInjectionKind.getXServiceLocator,
        confidence: DiscoveryConfidence.detected,
        evidence: getxEvidence,
      );
    }
    if (riverpodEvidence.isNotEmpty) {
      return DiscoveredValue(
        DependencyInjectionKind.riverpodRef,
        confidence: DiscoveryConfidence.detected,
        evidence: riverpodEvidence,
      );
    }
    if (providerEvidence.isNotEmpty) {
      return DiscoveredValue(
        DependencyInjectionKind.providerAsDI,
        confidence: DiscoveryConfidence.detected,
        evidence: providerEvidence,
      );
    }
    if (staticSingletonEvidence.isNotEmpty) {
      return DiscoveredValue(
        DependencyInjectionKind.staticSingleton,
        confidence: DiscoveryConfidence.detected,
        evidence: staticSingletonEvidence,
      );
    }

    final names = _dependencyNames(scan.pubspecYaml);
    if (names.contains('get_it')) {
      return const DiscoveredValue(
        DependencyInjectionKind.getIt,
        confidence: DiscoveryConfidence.inferred,
        evidence: ['pubspec.yaml: get_it declared, no usage evidence found'],
      );
    }
    if (names.contains('injectable')) {
      return const DiscoveredValue(
        DependencyInjectionKind.injectable,
        confidence: DiscoveryConfidence.inferred,
        evidence: [
          'pubspec.yaml: injectable declared, no usage evidence found',
        ],
      );
    }

    return const DiscoveredValue(
      DependencyInjectionKind.none,
      confidence: DiscoveryConfidence.unknown,
      evidence: [
        'No DI framework or static-singleton convention evidence found',
      ],
    );
  }

  Set<String> _dependencyNames(Map<String, dynamic>? yaml) {
    if (yaml == null) return const {};
    final names = <String>{};
    for (final section in [yaml['dependencies'], yaml['dev_dependencies']]) {
      if (section is Map) {
        names.addAll(section.keys.map((k) => k.toString()));
      }
    }
    return names;
  }
}
