import '../generator/discover/project_scan_result.dart';

final _classDeclaration =
    RegExp(r'^\s*(abstract\s+)?class\s+(\w+)', multiLine: true);

class ProductionSubject {
  final String name;

  final String filePath;

  final bool isAbstract;

  ProductionSubject({
    required this.name,
    required this.filePath,
    this.isAbstract = false,
  });
}

class FeatureTestDiscovery {
  final String feature;

  final List<String> productionFiles;

  final List<ProductionSubject> subjects;

  final List<String> testFiles;

  final Map<String, List<String>> testFilesForSubject;

  final List<ProductionSubject> untestedSubjects;

  FeatureTestDiscovery({
    required this.feature,
    required this.productionFiles,
    required this.subjects,
    required this.testFiles,
    required this.testFilesForSubject,
    required this.untestedSubjects,
  });
}

class TestDiscoveryService {
  FeatureTestDiscovery discover(ProjectScanResult scan, String feature) {
    final productionFiles = scan.filesUnderFeature(feature).toList()..sort();

    final subjects = <ProductionSubject>[];
    for (final filePath in productionFiles) {
      final content = scan.dartFiles[filePath]!;
      for (final match in _classDeclaration.allMatches(content)) {
        final name = match.group(2)!;
        if (name.startsWith('_')) continue;
        subjects.add(ProductionSubject(
          name: name,
          filePath: filePath,
          isAbstract: match.group(1) != null,
        ));
      }
    }

    final testPrefix = 'test/features/$feature/';
    final testFiles = scan.dartFiles.keys
        .where((p) => p.startsWith(testPrefix))
        .toList()
      ..sort();

    final testFilesForSubject = <String, List<String>>{};
    for (final subject in subjects) {
      final referencingFiles = <String>[];
      final reference = RegExp(r'\b' + RegExp.escape(subject.name) + r'\b');
      for (final testFile in testFiles) {
        if (reference.hasMatch(scan.dartFiles[testFile]!)) {
          referencingFiles.add(testFile);
        }
      }
      if (referencingFiles.isNotEmpty) {
        testFilesForSubject[subject.name] = referencingFiles;
      }
    }

    final untestedSubjects = subjects
        .where((s) => !testFilesForSubject.containsKey(s.name))
        .toList();

    return FeatureTestDiscovery(
      feature: feature,
      productionFiles: productionFiles,
      subjects: subjects,
      testFiles: testFiles,
      testFilesForSubject: testFilesForSubject,
      untestedSubjects: untestedSubjects,
    );
  }
}
