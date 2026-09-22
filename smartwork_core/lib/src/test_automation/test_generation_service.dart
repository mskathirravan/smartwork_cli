import '../generator/discover/project_scan_result.dart';
import '../models/test_analysis.dart';
import '../models/test_scenario.dart';
import 'test_discovery_service.dart';

final _defaultConstructor = RegExp(r'(?:const\s+)?(\w+)\s*\(([^)]*)\)\s*[;{:]');

class UnknownPackageNameException implements Exception {
  @override
  String toString() =>
      'pubspec.yaml has no "name" field; cannot build a package import '
      'for a generated test.';
}

class TestGenerationService {
  TestGenerationPlan generate(
    ProjectScanResult scan,
    FeatureTestDiscovery discovery,
    List<TestScenario> scenarios,
  ) {
    final skipped = <TestScenario>[];
    final byTestFilePath = <String, List<TestScenario>>{};

    for (final scenario in scenarios) {
      if (scenario.status != TestScenarioStatus.missing) {
        skipped.add(scenario);
        continue;
      }

      final subject = discovery.subjects.firstWhere(
        (s) => s.name == scenario.subject,
      );
      final testFilePath = _testFilePathFor(subject.filePath);
      (byTestFilePath[testFilePath] ??= []).add(scenario);
    }

    final changes = <TestChange>[];
    if (byTestFilePath.isNotEmpty) {
      final packageName = scan.pubspecYaml?['name'] as String?;
      if (packageName == null) throw UnknownPackageNameException();

      for (final entry in byTestFilePath.entries) {
        final testFilePath = entry.key;
        final scenariosForFile = entry.value;

        if (scan.dartFiles.containsKey(testFilePath)) {
          skipped.addAll(scenariosForFile);
          continue;
        }

        final subjectsForFile = scenariosForFile
            .map((s) => discovery.subjects.firstWhere(
                  (subject) => subject.name == s.subject,
                ))
            .toList();

        final blocksWithFlags =
            subjectsForFile.map((s) => _blockFor(scan, s)).toList();
        final needsProductionImport = blocksWithFlags.any((b) => !b.isSkipped);

        changes.add(TestChange(
          kind: TestChangeKind.create,
          filePath: testFilePath,
          content: _fileContent(
            packageName: needsProductionImport ? packageName : null,
            productionFilePath: subjectsForFile.first.filePath,
            blocks: blocksWithFlags.map((b) => b.content),
          ),
          scenarios: scenariosForFile,
        ));
      }
    }

    return TestGenerationPlan(
      feature: discovery.feature,
      changes: changes,
      skipped: skipped,
    );
  }

  String _testFilePathFor(String productionFilePath) {
    final withoutExtension =
        productionFilePath.substring(0, productionFilePath.length - 5);
    return 'test/${withoutExtension.substring(4)}_test.dart';
  }

  String _productionImport(String packageName, String productionFilePath) =>
      'package:$packageName/${productionFilePath.substring(4)}';

  String _fileContent({
    required String? packageName,
    required String productionFilePath,
    required Iterable<String> blocks,
  }) =>
      '''
import 'package:flutter_test/flutter_test.dart';
${packageName == null ? '' : "import '${_productionImport(packageName, productionFilePath)}';\n"}
void main() {
${blocks.join('')}}
''';

  _Block _blockFor(ProjectScanResult scan, ProductionSubject subject) {
    if (subject.isAbstract) {
      return _Block.skipped(_skippedBlock(
        subject.name,
        '${subject.name} is an abstract class and cannot be constructed '
        'directly; test it through a concrete subclass instead.',
      ));
    }

    final source = scan.dartFiles[subject.filePath] ?? '';

    if (_hasOnlyPrivateConstructor(source, subject.name)) {
      return _Block.skipped(_skippedBlock(
        subject.name,
        '${subject.name} has no public constructor (a private/singleton '
        'constructor pattern); smartwork test generate cannot safely '
        'guess how to obtain an instance. Supply one and replace this '
        'scaffold.',
      ));
    }

    if (_needsConstructorArgument(source, subject.name)) {
      return _Block.skipped(_skippedBlock(
        subject.name,
        '${subject.name} has a required constructor argument; '
        'smartwork test generate cannot safely guess a fake for it. '
        'Supply one and replace this scaffold.',
      ));
    }

    return _Block.smoke(_smokeBlock(subject.name));
  }

  bool _hasOnlyPrivateConstructor(String source, String subjectName) {
    final escaped = RegExp.escape(subjectName);
    final hasPrivate = RegExp('$escaped\\._\\s*\\(').hasMatch(source);
    if (!hasPrivate) return false;
    final hasPublic = RegExp('$escaped\\s*\\(').hasMatch(source);
    return !hasPublic;
  }

  bool _needsConstructorArgument(String source, String subjectName) {
    RegExpMatch? match;
    for (final candidate in _defaultConstructor.allMatches(source)) {
      if (candidate.group(1) == subjectName) {
        match = candidate;
        break;
      }
    }
    if (match == null) {
      return false;
    }

    final params = match.group(2)!.trim();
    if (params.isEmpty) return false;
    if (RegExp(r'^\[[^\]]*\]$').hasMatch(params)) return false;
    if (RegExp(r'^\{[^}]*\}$').hasMatch(params)) {
      return params.contains('required');
    }
    return true;
  }

  String _smokeBlock(String subjectName) => '''
  group('$subjectName', () {
    test('can be constructed', () {
      expect($subjectName(), isNotNull);
    });
  });
''';

  String _skippedBlock(String subjectName, String reason) => '''
  group('$subjectName', () {
    test(
      '$subjectName needs a real test — fill in its constructor dependencies',
      () {},
      skip: '$reason',
    );
  });
''';
}

class _Block {
  final String content;
  final bool isSkipped;

  _Block.smoke(this.content) : isSkipped = false;
  _Block.skipped(this.content) : isSkipped = true;
}
