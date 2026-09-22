import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Real `flutter test --coverage` output (Flutter 3.47.0), captured
/// verbatim during this milestone's own development — see
/// `LcovParser`'s own doc comment. Line-coverage only: no `FN`/`FNDA`/
/// `BRDA` records at all.
const _realFlutterLcov = '''
SF:lib/sample.dart
DA:1,2
DA:3,1
DA:4,1
DA:6,0
DA:7,0
DA:13,2
DA:14,0
LF:7
LH:4
end_of_record
SF:lib/main.dart
DA:3,0
DA:4,0
DA:8,1
LF:26
LH:24
end_of_record
''';

/// A hand-built tracefile exercising the richer, standard LCOV record
/// types (`FN`/`FNDA`/`FNF`/`FNH`/`BRDA`/`BRF`/`BRH`) that real Flutter
/// output doesn't currently emit — this parser still recognizes them,
/// per its own doc comment, for a future Flutter version or a
/// non-Flutter tracefile.
const _richLcov = '''
SF:lib/features/auth/auth_repository_impl.dart
FN:3,login
FN:10,logout
FNDA:2,login
FNDA:0,logout
FNF:2
FNH:1
DA:3,2
DA:4,2
DA:10,0
DA:11,0
BRDA:4,0,0,2
BRDA:4,0,1,0
LF:4
LH:2
BRF:2
BRH:1
end_of_record
''';

void main() {
  group('LcovParser', () {
    test(
        'parses real Flutter output into line-only FileCoverage, with '
        'function/branch counters left null rather than fabricated', () {
      final report = LcovParser().parse(_realFlutterLcov);

      expect(report.files, hasLength(2));

      final sample =
          report.files.firstWhere((f) => f.file == 'lib/sample.dart');
      expect(sample.linesFound, 7);
      expect(sample.linesHit, 4);
      expect(sample.functionsFound, isNull);
      expect(sample.functionCoverage, isNull);
      expect(sample.branchesFound, isNull);
      expect(sample.branchCoverage, isNull);
    });

    test('reports one CoverageGap per zero-execution DA line', () {
      final report = LcovParser().parse(_realFlutterLcov);
      final sample =
          report.files.firstWhere((f) => f.file == 'lib/sample.dart');

      expect(sample.gaps.map((g) => g.line), containsAll([6, 7, 14]));
      expect(sample.gaps.every((g) => g.file == 'lib/sample.dart'), isTrue);
      expect(sample.gaps.every((g) => g.function == null), isTrue);
    });

    test(
        'the project-wide lineCoverage is a real, computed aggregate '
        'across every file, and functionCoverage/branchCoverage stay '
        'null when no file recorded that data', () {
      final report = LcovParser().parse(_realFlutterLcov);

      expect(report.totalLinesFound, 33);
      expect(report.totalLinesHit, 28);
      expect(report.lineCoverage, closeTo(28 / 33, 0.0001));
      expect(report.functionCoverage, isNull);
      expect(report.branchCoverage, isNull);
    });

    test(
        'correlates a zero-count FNDA function to its exact FN '
        'declaration line, naming it on that line\'s gap', () {
      final report = LcovParser().parse(_richLcov);
      final file = report.files.single;

      expect(file.functionsFound, 2);
      expect(file.functionsHit, 1);
      expect(file.functionCoverage, 0.5);

      final logoutGap = file.gaps.firstWhere((g) => g.line == 10);
      expect(logoutGap.function, 'logout');

      // "login" was called (FNDA:2,login) — never reported as a gap.
      expect(file.gaps.any((g) => g.function == 'login'), isFalse);
    });

    test(
        'reports a real branch gap with the exact block/branch that '
        'was not taken, from BRDA', () {
      final report = LcovParser().parse(_richLcov);
      final file = report.files.single;

      expect(file.branchesFound, 2);
      expect(file.branchesHit, 1);
      expect(file.branchCoverage, 0.5);

      final branchGap = file.gaps.firstWhere((g) => g.description != null);
      expect(branchGap.line, 4);
      expect(branchGap.description, 'branch 0/1 not taken');
    });

    test('an empty tracefile produces an empty report', () {
      final report = LcovParser().parse('');
      expect(report.files, isEmpty);
      expect(report.lineCoverage, 1.0);
    });

    test('forFeature narrows to only files under that feature\'s prefix', () {
      final report = LcovParser().parse(_realFlutterLcov);
      final narrowed = report.forFeature('lib/sample');

      expect(narrowed.files, hasLength(1));
      expect(narrowed.files.single.file, 'lib/sample.dart');
    });
  });
}
