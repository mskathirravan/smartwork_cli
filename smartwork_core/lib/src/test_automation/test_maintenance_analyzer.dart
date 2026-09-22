import '../generator/discover/project_scan_result.dart';
import '../models/test_maintenance.dart';
import 'dart_call_site_finder.dart';
import 'dart_lexical_scanner.dart';
import 'dart_signature_analyzer.dart';
import 'test_discovery_service.dart';

final _isATypeArgument = RegExp(r'\bisA<\s*(\w+)\s*>');
final _isTypeCheck = RegExp(r'\bis\s+(\w+)\b');

const _wellKnownTypes = {
  'bool', 'int', 'double', 'num', 'String', 'Object', 'dynamic',
  'List', 'Map', 'Set', 'Exception', 'Error', 'Duration', 'DateTime',
  // ignore: unnecessary_string_escapes
};

class TestMaintenanceAnalyzer {
  final DartSignatureAnalyzer _signatures;
  final DartCallSiteFinder _callSites;

  TestMaintenanceAnalyzer({
    DartSignatureAnalyzer? signatures,
    DartCallSiteFinder? callSites,
  })  : _signatures = signatures ?? DartSignatureAnalyzer(),
        _callSites = callSites ?? DartCallSiteFinder();

  List<TestUpdate> analyze(
    ProjectScanResult scan,
    FeatureTestDiscovery discovery,
  ) {
    final updates = <TestUpdate>[];

    for (final subject in discovery.subjects) {
      final testFiles = discovery.testFilesForSubject[subject.name];
      if (testFiles == null || testFiles.isEmpty) continue;

      final source = scan.dartFiles[subject.filePath]!;

      final constructorSig =
          _signatures.constructorSignature(source, subject.name);
      if (constructorSig != null) {
        for (final testFile in testFiles) {
          updates.addAll(_checkCalls(
            testFile: testFile,
            testSource: scan.dartFiles[testFile]!,
            callName: subject.name,
            subjectName: subject.name,
            subjectDescription: '${subject.name}\'s constructor',
            signature: constructorSig,
            kind: TestUpdateKind.constructorArguments,
          ));
        }
      }

      for (final methodName in _signatures.methodNames(source, subject.name)) {
        final methodSig =
            _signatures.methodSignature(source, subject.name, methodName);
        if (methodSig == null) continue;

        for (final testFile in testFiles) {
          updates.addAll(_checkCalls(
            testFile: testFile,
            testSource: scan.dartFiles[testFile]!,
            callName: methodName,
            subjectName: subject.name,
            subjectDescription: '${subject.name}.$methodName()',
            signature: methodSig,
            kind: TestUpdateKind.methodCallArguments,
          ));
        }
      }

      final members = _signatures.hierarchyMembers(source, subject.name);
      if (members != null && members.isNotEmpty) {
        for (final testFile in testFiles) {
          updates.addAll(_checkStaleIdentifiers(
            testFile: testFile,
            testSource: scan.dartFiles[testFile]!,
            baseName: subject.name,
            currentMembers: members,
          ));
        }
      }
    }

    return updates;
  }

  List<TestUpdate> _checkCalls({
    required String testFile,
    required String testSource,
    required String callName,
    required String subjectName,
    required String subjectDescription,
    required CallableSignature signature,
    required TestUpdateKind kind,
  }) {
    final updates = <TestUpdate>[];
    final requiredPositional = signature.requiredPositional;
    final requiredNamed =
        signature.parameters.where((p) => p.isNamed && p.isRequired).toList();

    for (final site in _callSites.findCalls(testSource, callName)) {
      final missingPositional =
          site.positionalArgumentCount < requiredPositional.length
              ? requiredPositional.sublist(site.positionalArgumentCount)
              : const <ParameterSignature>[];
      final missingNamed = requiredNamed
          .where((p) => !site.namedArgumentNames.contains(p.name))
          .toList();
      final missing = [...missingPositional, ...missingNamed];
      if (missing.isEmpty) continue;

      final reason = '$subjectDescription now requires '
          '${missing.map((p) => p.name).join(', ')}.';

      if (missing.length > 1) {
        updates.add(TestUpdate(
          testFile: testFile,
          subject: subjectName,
          kind: kind,
          confidence: TestUpdateConfidence.low,
          reason: reason,
          oldSnippet: site.argumentsSource,
        ));
        continue;
      }

      final onlyMissing = missing.single;
      final literal = _canonicalDefaultLiteral(onlyMissing);
      if (literal == null) {
        updates.add(TestUpdate(
          testFile: testFile,
          subject: subjectName,
          kind: kind,
          confidence: TestUpdateConfidence.medium,
          reason: reason,
          oldSnippet: site.argumentsSource,
        ));
        continue;
      }

      updates.add(TestUpdate(
        testFile: testFile,
        subject: subjectName,
        kind: kind,
        confidence: TestUpdateConfidence.high,
        reason: reason,
        oldSnippet: site.argumentsSource,
        newSnippet: _appendArgument(site, onlyMissing, literal),
        startOffset: site.argumentsStart,
        endOffset: site.argumentsEnd,
      ));
    }

    return updates;
  }

  String? _canonicalDefaultLiteral(ParameterSignature param) {
    if (param.isNullable) return 'null';

    switch (param.typeSource) {
      case 'bool':
        return 'false';
      case 'int':
        return '0';
      case 'double':
        return '0.0';
      case 'num':
        return '0';
      case 'String':
        return "''";
      default:
        return null;
    }
  }

  String _appendArgument(
    CallSite site,
    ParameterSignature missingParam,
    String literal,
  ) {
    final parts = site.argumentsSource.trim().isEmpty
        ? <String>[]
        : DartLexicalScanner.splitTopLevel(site.argumentsSource);

    final positional = <String>[];
    final named = <String>[];
    for (final part in parts) {
      final trimmed = part.trim();
      if (RegExp(r'^[A-Za-z_]\w*\s*:').hasMatch(trimmed)) {
        named.add(trimmed);
      } else {
        positional.add(trimmed);
      }
    }

    if (missingParam.isNamed) {
      named.add('${missingParam.name}: $literal');
    } else {
      positional.add(literal);
    }
    return [...positional, ...named].join(', ');
  }

  List<TestUpdate> _checkStaleIdentifiers({
    required String testFile,
    required String testSource,
    required String baseName,
    required Set<String> currentMembers,
  }) {
    final updates = <TestUpdate>[];
    final candidates = <String>{
      for (final m in _isATypeArgument.allMatches(testSource)) m.group(1)!,
      for (final m in _isTypeCheck.allMatches(testSource)) m.group(1)!,
    };

    for (final candidate in candidates) {
      if (candidate == baseName) continue;
      if (currentMembers.contains(candidate)) continue;
      if (_wellKnownTypes.contains(candidate)) continue;
      if (!_callSites.referencesIdentifier(testSource, baseName)) continue;

      updates.add(TestUpdate(
        testFile: testFile,
        subject: baseName,
        kind: TestUpdateKind.staleIdentifier,
        confidence: TestUpdateConfidence.low,
        reason: '$candidate no longer exists under $baseName\'s current '
            'members (${currentMembers.join(', ')}).',
        oldSnippet: candidate,
      ));
    }

    return updates;
  }
}
