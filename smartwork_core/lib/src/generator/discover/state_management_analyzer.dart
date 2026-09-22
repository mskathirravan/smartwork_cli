import '../../models/project_config.dart';
import '../../models/project_knowledge.dart';
import 'project_scan_result.dart';

final _extendsBloc = RegExp(r'extends\s+Bloc\s*<');
final _extendsCubit = RegExp(r'extends\s+Cubit\s*<');
final _extendsStateNotifier = RegExp(r'extends\s+StateNotifier\s*<');
final _extendsGetxController = RegExp(r'extends\s+GetxController\b');
final _getPutOrFind = RegExp(r'Get\.(put|find)\s*<');

class StateManagementAnalyzer {
  DiscoveredValue<StateManagement?> analyze(ProjectScanResult scan) {
    final blocEvidence = <String>[];
    final cubitEvidence = <String>[];
    final riverpodEvidence = <String>[];
    final getxEvidence = <String>[];

    for (final entry in scan.dartFiles.entries) {
      final filePath = entry.key;
      final content = entry.value;

      if (_extendsBloc.hasMatch(content)) {
        blocEvidence.add('$filePath: class extends Bloc<...>');
      }
      if (_extendsCubit.hasMatch(content)) {
        cubitEvidence.add('$filePath: class extends Cubit<...>');
      }
      if (_extendsStateNotifier.hasMatch(content) ||
          content.contains('StateNotifierProvider')) {
        riverpodEvidence.add(
          '$filePath: StateNotifier/StateNotifierProvider usage',
        );
      }
      if (_extendsGetxController.hasMatch(content) ||
          _getPutOrFind.hasMatch(content)) {
        getxEvidence.add('$filePath: GetxController/Get.put/Get.find usage');
      }
    }

    final detected = <StateManagement, List<String>>{
      if (blocEvidence.isNotEmpty) StateManagement.bloc: blocEvidence,
      if (cubitEvidence.isNotEmpty) StateManagement.cubit: cubitEvidence,
      if (riverpodEvidence.isNotEmpty)
        StateManagement.riverpod: riverpodEvidence,
      if (getxEvidence.isNotEmpty) StateManagement.getx: getxEvidence,
    };

    if (detected.length == 1) {
      final entry = detected.entries.single;
      return DiscoveredValue(
        entry.key,
        confidence: DiscoveryConfidence.detected,
        evidence: entry.value,
      );
    }

    if (detected.length == 2 &&
        detected.containsKey(StateManagement.bloc) &&
        detected.containsKey(StateManagement.cubit)) {
      return DiscoveredValue(
        StateManagement.bloc,
        confidence: DiscoveryConfidence.detected,
        evidence: [
          ...detected[StateManagement.bloc]!,
          ...detected[StateManagement.cubit]!,
          'Both Bloc and Cubit subclasses found — reporting bloc as the primary style since Cubit is a restricted form of Bloc',
        ],
      );
    }

    if (detected.length > 1) {
      return DiscoveredValue(
        null,
        confidence: DiscoveryConfidence.unknown,
        evidence: [
          'Multiple, non-overlapping state-management frameworks detected:',
          for (final entries in detected.values) ...entries,
        ],
      );
    }

    return _fromDeclaredDependenciesOnly(scan);
  }

  DiscoveredValue<StateManagement?> _fromDeclaredDependenciesOnly(
    ProjectScanResult scan,
  ) {
    final yaml = scan.pubspecYaml;
    final names = _dependencyNames(yaml);

    final hasFlutterBloc = names.contains('flutter_bloc');
    final hasRiverpod =
        names.contains('riverpod') || names.contains('flutter_riverpod');
    final hasGet = names.contains('get');
    final declaredCount =
        [hasFlutterBloc, hasRiverpod, hasGet].where((b) => b).length;

    if (declaredCount == 0) {
      return const DiscoveredValue(
        null,
        confidence: DiscoveryConfidence.unknown,
        evidence: [
          'No known state-management dependency or usage evidence found',
        ],
      );
    }

    if (hasFlutterBloc && declaredCount == 1) {
      return const DiscoveredValue(
        null,
        confidence: DiscoveryConfidence.inferred,
        evidence: [
          'pubspec.yaml: flutter_bloc declared, but no Bloc/Cubit class evidence found — dependency alone cannot distinguish Bloc from Cubit',
        ],
      );
    }

    if (hasRiverpod && declaredCount == 1) {
      return DiscoveredValue(
        StateManagement.riverpod,
        confidence: DiscoveryConfidence.inferred,
        evidence: const [
          'pubspec.yaml: riverpod declared, no usage evidence found',
        ],
      );
    }

    if (hasGet && declaredCount == 1) {
      return DiscoveredValue(
        StateManagement.getx,
        confidence: DiscoveryConfidence.inferred,
        evidence: const [
          'pubspec.yaml: get declared, no usage evidence found',
        ],
      );
    }

    return DiscoveredValue(
      null,
      confidence: DiscoveryConfidence.inferred,
      evidence: [
        'Multiple state-management dependencies declared with no usage evidence: ${[
          if (hasFlutterBloc) 'flutter_bloc',
          if (hasRiverpod) 'riverpod',
          if (hasGet) 'get',
        ].join(', ')}',
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
