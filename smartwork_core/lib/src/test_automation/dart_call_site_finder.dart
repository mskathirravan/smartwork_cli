import 'dart_lexical_scanner.dart';

class CallSite {
  final String argumentsSource;

  final int argumentsStart;

  final int argumentsEnd;

  final int positionalArgumentCount;

  final Set<String> namedArgumentNames;

  CallSite({
    required this.argumentsSource,
    required this.argumentsStart,
    required this.argumentsEnd,
    required this.positionalArgumentCount,
    required this.namedArgumentNames,
  });
}

class DartCallSiteFinder {
  List<CallSite> findCalls(String source, String name) {
    final scanner = DartLexicalScanner(source);
    final pattern = RegExp(r'\b' + RegExp.escape(name) + r'\s*\(');
    final sites = <CallSite>[];

    for (final match in pattern.allMatches(source)) {
      if (!scanner.isCode(match.start)) continue;

      final openParen = match.end - 1;
      final closeParen = scanner.matchingBracket(openParen);
      if (closeParen == null) continue;

      final argsSource = source.substring(openParen + 1, closeParen);
      final parts = DartLexicalScanner.splitTopLevel(argsSource);

      var positionalCount = 0;
      final namedNames = <String>{};
      for (final part in parts) {
        final trimmedPart = part.trim();
        if (trimmedPart.isEmpty) continue;
        final namedMatch =
            RegExp(r'^([A-Za-z_]\w*)\s*:').firstMatch(trimmedPart);
        if (namedMatch != null) {
          namedNames.add(namedMatch.group(1)!);
        } else {
          positionalCount++;
        }
      }

      sites.add(CallSite(
        argumentsSource: argsSource,
        argumentsStart: openParen + 1,
        argumentsEnd: closeParen,
        positionalArgumentCount: positionalCount,
        namedArgumentNames: namedNames,
      ));
    }

    return sites;
  }

  bool referencesIdentifier(String source, String identifier) {
    final scanner = DartLexicalScanner(source);
    final pattern = RegExp(r'\b' + RegExp.escape(identifier) + r'\b');
    for (final match in pattern.allMatches(source)) {
      if (scanner.isCode(match.start)) return true;
    }
    return false;
  }
}
