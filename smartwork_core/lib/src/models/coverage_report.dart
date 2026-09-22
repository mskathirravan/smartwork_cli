class CoverageGap {
  final String file;

  final String? function;

  final int line;

  final String? description;

  CoverageGap({
    required this.file,
    this.function,
    required this.line,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'file': file,
        'function': function,
        'line': line,
        'description': description,
      };
}

class FileCoverage {
  final String file;
  final int linesFound;
  final int linesHit;
  final int? functionsFound;
  final int? functionsHit;
  final int? branchesFound;
  final int? branchesHit;
  final List<CoverageGap> gaps;

  FileCoverage({
    required this.file,
    required this.linesFound,
    required this.linesHit,
    this.functionsFound,
    this.functionsHit,
    this.branchesFound,
    this.branchesHit,
    this.gaps = const [],
  });

  double get lineCoverage => linesFound == 0 ? 1.0 : linesHit / linesFound;

  double? get functionCoverage => functionsFound == null
      ? null
      : (functionsFound == 0 ? 1.0 : functionsHit! / functionsFound!);

  double? get branchCoverage => branchesFound == null
      ? null
      : (branchesFound == 0 ? 1.0 : branchesHit! / branchesFound!);

  Map<String, dynamic> toJson() => {
        'file': file,
        'lineCoverage': lineCoverage,
        'functionCoverage': functionCoverage,
        'branchCoverage': branchCoverage,
        'linesFound': linesFound,
        'linesHit': linesHit,
        'functionsFound': functionsFound,
        'functionsHit': functionsHit,
        'branchesFound': branchesFound,
        'branchesHit': branchesHit,
        'gaps': gaps.map((g) => g.toJson()).toList(),
      };
}

class CoverageReport {
  final List<FileCoverage> files;

  CoverageReport({required this.files});

  int get totalLinesFound => files.fold(0, (sum, f) => sum + f.linesFound);
  int get totalLinesHit => files.fold(0, (sum, f) => sum + f.linesHit);

  double get lineCoverage =>
      totalLinesFound == 0 ? 1.0 : totalLinesHit / totalLinesFound;

  double? get functionCoverage {
    final withFunctions = files.where((f) => f.functionCoverage != null);
    if (withFunctions.isEmpty) return null;
    final found =
        withFunctions.fold<int>(0, (sum, f) => sum + f.functionsFound!);
    final hit = withFunctions.fold<int>(0, (sum, f) => sum + f.functionsHit!);
    return found == 0 ? 1.0 : hit / found;
  }

  double? get branchCoverage {
    final withBranches = files.where((f) => f.branchCoverage != null);
    if (withBranches.isEmpty) return null;
    final found = withBranches.fold<int>(0, (sum, f) => sum + f.branchesFound!);
    final hit = withBranches.fold<int>(0, (sum, f) => sum + f.branchesHit!);
    return found == 0 ? 1.0 : hit / found;
  }

  List<CoverageGap> get allGaps => [for (final f in files) ...f.gaps];

  CoverageReport forFeature(String featurePrefix) => CoverageReport(
        files: files.where((f) => f.file.startsWith(featurePrefix)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'lineCoverage': lineCoverage,
        'functionCoverage': functionCoverage,
        'branchCoverage': branchCoverage,
        'files': files.map((f) => f.toJson()).toList(),
      };
}
