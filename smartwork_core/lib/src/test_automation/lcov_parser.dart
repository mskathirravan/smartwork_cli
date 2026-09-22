import '../models/coverage_report.dart';

class LcovParser {
  CoverageReport parse(String lcovContent) {
    final files = <FileCoverage>[];

    String? currentFile;
    int linesFound = 0, linesHit = 0;
    int? functionsFound, functionsHit;
    int? branchesFound, branchesHit;
    final zeroLineGaps = <int, CoverageGap>{};
    final functionLineByName = <String, int>{};
    final zeroCountFunctionNames = <String>{};
    final branchGaps = <CoverageGap>[];

    void flush() {
      if (currentFile == null) return;

      for (final name in zeroCountFunctionNames) {
        final line = functionLineByName[name];
        if (line != null && zeroLineGaps.containsKey(line)) {
          zeroLineGaps[line] = CoverageGap(
            file: currentFile!,
            function: name,
            line: line,
          );
        }
      }

      files.add(FileCoverage(
        file: currentFile!,
        linesFound: linesFound,
        linesHit: linesHit,
        functionsFound: functionsFound,
        functionsHit: functionsHit,
        branchesFound: branchesFound,
        branchesHit: branchesHit,
        gaps: [
          ...zeroLineGaps.values,
          ...branchGaps,
        ],
      ));
    }

    void reset() {
      currentFile = null;
      linesFound = 0;
      linesHit = 0;
      functionsFound = null;
      functionsHit = null;
      branchesFound = null;
      branchesHit = null;
      zeroLineGaps.clear();
      functionLineByName.clear();
      zeroCountFunctionNames.clear();
      branchGaps.clear();
    }

    for (final rawLine in lcovContent.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final colon = line.indexOf(':');
      final tag = colon == -1 ? line : line.substring(0, colon);
      final rest = colon == -1 ? '' : line.substring(colon + 1);

      switch (tag) {
        case 'SF':
          currentFile = rest.trim();

        case 'DA':
          final parts = rest.split(',');
          final lineNum = int.tryParse(parts[0]) ?? -1;
          final count = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
          if (lineNum >= 0 && count == 0) {
            zeroLineGaps[lineNum] = CoverageGap(
              file: currentFile ?? '',
              line: lineNum,
            );
          }

        case 'LF':
          linesFound = int.tryParse(rest) ?? 0;

        case 'LH':
          linesHit = int.tryParse(rest) ?? 0;

        case 'FN':
          final parts = rest.split(',');
          final lineNum = int.tryParse(parts[0]);
          final name = parts.length > 1 ? parts[1] : null;
          if (lineNum != null && name != null) {
            functionLineByName[name] = lineNum;
          }

        case 'FNDA':
          final parts = rest.split(',');
          final count = int.tryParse(parts[0]) ?? 0;
          final name = parts.length > 1 ? parts[1] : null;
          if (name != null && count == 0) {
            zeroCountFunctionNames.add(name);
          }

        case 'FNF':
          functionsFound = int.tryParse(rest) ?? 0;

        case 'FNH':
          functionsHit = int.tryParse(rest) ?? 0;

        case 'BRDA':
          final parts = rest.split(',');
          if (parts.length >= 4) {
            final lineNum = int.tryParse(parts[0]) ?? -1;
            final block = parts[1];
            final branch = parts[2];
            final taken = parts[3];
            if (taken == '-' || taken == '0') {
              branchGaps.add(CoverageGap(
                file: currentFile ?? '',
                line: lineNum,
                description: 'branch $block/$branch not taken',
              ));
            }
          }

        case 'BRF':
          branchesFound = int.tryParse(rest) ?? 0;

        case 'BRH':
          branchesHit = int.tryParse(rest) ?? 0;

        case 'end_of_record':
          flush();
          reset();
      }
    }

    return CoverageReport(files: files);
  }
}
