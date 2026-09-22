import 'dart_lexical_scanner.dart';

class ParameterSignature {
  final String name;
  final bool isNamed;
  final bool isRequired;

  final String? defaultValueSource;

  final String? typeSource;

  ParameterSignature({
    required this.name,
    required this.isNamed,
    required this.isRequired,
    this.defaultValueSource,
    this.typeSource,
  });

  bool get isPositional => !isNamed;

  bool get isNullable => typeSource?.endsWith('?') ?? false;
}

class CallableSignature {
  final String name;
  final List<ParameterSignature> parameters;

  CallableSignature({required this.name, required this.parameters});

  List<ParameterSignature> get positional =>
      parameters.where((p) => p.isPositional).toList();

  List<ParameterSignature> get requiredPositional =>
      positional.where((p) => p.isRequired).toList();
}

class DartSignatureAnalyzer {
  static final _classDeclaration = RegExp(r'\b(abstract\s+)?class\s+(\w+)\b');
  static final _enumDeclaration = RegExp(r'\benum\s+(\w+)\s*\{');
  static final _extendsClause = RegExp(r'\bextends\s+(\w+)\b');
  static final _implementsClause = RegExp(r'\bimplements\s+([\w,\s]+?)\{');
  static final _asyncModifier = RegExp(r'^(async\*?|sync\*)\s*');

  bool _looksLikeDeclaration(String afterCloseParen) {
    final after = afterCloseParen.trimLeft().replaceFirst(_asyncModifier, '');
    return after.startsWith('{') ||
        after.startsWith('=>') ||
        after.startsWith(';') ||
        after.startsWith(':');
  }

  ({int start, int end})? classBodyRange(String source, String className) {
    final scanner = DartLexicalScanner(source);
    for (final match in _classDeclaration.allMatches(source)) {
      if (!scanner.isCode(match.start)) continue;
      if (match.group(2) != className) continue;

      final openBrace = source.indexOf('{', match.end);
      if (openBrace == -1) return null;
      final closeBrace = scanner.matchingBracket(openBrace);
      if (closeBrace == null) return null;
      return (start: openBrace + 1, end: closeBrace);
    }
    return null;
  }

  bool isAbstractClass(String source, String className) {
    final scanner = DartLexicalScanner(source);
    for (final match in _classDeclaration.allMatches(source)) {
      if (!scanner.isCode(match.start)) continue;
      if (match.group(2) == className) return match.group(1) != null;
    }
    return false;
  }

  CallableSignature? constructorSignature(String source, String className) {
    final body = classBodyRange(source, className);
    if (body == null) return null;
    final classSource = source.substring(body.start, body.end);

    final ctor = RegExp(
      r'(?:const\s+)?\b' + RegExp.escape(className) + r'\s*\(',
    );
    final scanner = DartLexicalScanner(classSource);
    for (final match in ctor.allMatches(classSource)) {
      if (!scanner.isCode(match.start)) continue;

      final openParen = match.end - 1;
      final closeParen = scanner.matchingBracket(openParen);
      if (closeParen == null) continue;

      if (!_looksLikeDeclaration(classSource.substring(closeParen + 1))) {
        continue;
      }

      final paramsSource = classSource.substring(openParen + 1, closeParen);
      return CallableSignature(
        name: className,
        parameters: _parseParameterList(paramsSource),
      );
    }
    return null;
  }

  CallableSignature? methodSignature(
    String source,
    String className,
    String methodName,
  ) {
    final body = classBodyRange(source, className);
    if (body == null) return null;
    final classSource = source.substring(body.start, body.end);

    final method = RegExp(r'\b' + RegExp.escape(methodName) + r'\s*\(');
    final scanner = DartLexicalScanner(classSource);
    for (final match in method.allMatches(classSource)) {
      if (!scanner.isCode(match.start)) continue;

      final openParen = match.end - 1;
      final closeParen = scanner.matchingBracket(openParen);
      if (closeParen == null) continue;

      if (!_looksLikeDeclaration(classSource.substring(closeParen + 1))) {
        continue;
      }

      final paramsSource = classSource.substring(openParen + 1, closeParen);
      return CallableSignature(
        name: methodName,
        parameters: _parseParameterList(paramsSource),
      );
    }
    return null;
  }

  List<String> methodNames(String source, String className) {
    final body = classBodyRange(source, className);
    if (body == null) return const [];
    final classSource = source.substring(body.start, body.end);
    final scanner = DartLexicalScanner(classSource);

    final names = <String>{};
    final declaration = RegExp(r'\b(\w+)\s*\(');
    for (final match in declaration.allMatches(classSource)) {
      if (!scanner.isCode(match.start)) continue;
      final name = match.group(1)!;
      if (name.startsWith('_') || name == className) continue;
      final openParen = match.end - 1;
      final closeParen = scanner.matchingBracket(openParen);
      if (closeParen == null) continue;
      if (_looksLikeDeclaration(classSource.substring(closeParen + 1))) {
        names.add(name);
      }
    }
    return names.toList()..sort();
  }

  Set<String>? hierarchyMembers(String source, String baseName) {
    final scanner = DartLexicalScanner(source);

    for (final match in _enumDeclaration.allMatches(source)) {
      if (!scanner.isCode(match.start)) continue;
      if (match.group(1) != baseName) continue;
      final openBrace = match.end - 1;
      final closeBrace = scanner.matchingBracket(openBrace);
      if (closeBrace == null) return null;
      final body = source.substring(openBrace + 1, closeBrace);
      final constants = RegExp(r'\b(\w+)\b')
          .allMatches(body)
          .map((m) => m.group(1)!)
          .where((n) => n.isNotEmpty)
          .toSet();
      return constants;
    }

    final baseExists = classBodyRange(source, baseName) != null;
    if (!baseExists) return null;

    final members = <String>{};
    for (final match in _classDeclaration.allMatches(source)) {
      if (!scanner.isCode(match.start)) continue;
      final name = match.group(2)!;
      if (name == baseName) continue;

      final declEnd = source.indexOf('{', match.end);
      if (declEnd == -1) continue;
      final headerSource = source.substring(match.end, declEnd + 1);

      final extendsMatch = _extendsClause.firstMatch(headerSource);
      final implementsMatch = _implementsClause.firstMatch(headerSource);
      final extendsBase = extendsMatch?.group(1) == baseName;
      final implementsBase = implementsMatch != null &&
          implementsMatch
              .group(1)!
              .split(',')
              .map((s) => s.trim())
              .contains(baseName);

      if (extendsBase || implementsBase) members.add(name);
    }
    return members;
  }

  List<ParameterSignature> _parseParameterList(String paramsSource) {
    final trimmed = paramsSource.trim();
    if (trimmed.isEmpty) return const [];

    final scanner = DartLexicalScanner(trimmed);
    var groupStart = -1;
    var depth = 0;
    for (var i = 0; i < trimmed.length; i++) {
      if (!scanner.isCode(i)) continue;
      final c = trimmed[i];
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (depth == 0 && (c == '{' || c == '[')) {
        groupStart = i;
        break;
      }
    }

    final result = <ParameterSignature>[];

    String positionalPrefix;
    String? groupInner;
    var isNamedGroup = false;

    if (groupStart == -1) {
      positionalPrefix = trimmed;
    } else {
      positionalPrefix = trimmed.substring(0, groupStart).trim();
      if (positionalPrefix.endsWith(',')) {
        positionalPrefix =
            positionalPrefix.substring(0, positionalPrefix.length - 1).trim();
      }
      isNamedGroup = trimmed[groupStart] == '{';
      groupInner = trimmed.substring(groupStart + 1, trimmed.length - 1);
    }

    if (positionalPrefix.isNotEmpty) {
      for (final part in DartLexicalScanner.splitTopLevel(positionalPrefix)) {
        result.add(_toParameter(part, isNamed: false, isRequired: true));
      }
    }

    if (groupInner != null) {
      for (final part in DartLexicalScanner.splitTopLevel(groupInner)) {
        result.add(_toParameter(
          part,
          isNamed: isNamedGroup,
          isRequired: !isNamedGroup ? false : null,
        ));
      }
    }

    return result;
  }

  ParameterSignature _toParameter(
    String rawText, {
    required bool isNamed,
    required bool? isRequired,
  }) {
    var text = rawText.trim();
    var required = isRequired ?? false;
    String? defaultValueSource;

    if (text.startsWith('required ')) {
      required = true;
      text = text.substring('required '.length).trim();
    }

    final defaultSplit = text.split('=');
    if (defaultSplit.length > 1) {
      text = defaultSplit.first.trim();
      defaultValueSource = defaultSplit.sublist(1).join('=').trim();
    }

    final nameMatch = RegExp(r'([A-Za-z_]\w*)$').firstMatch(text);
    final name = nameMatch?.group(1) ?? text;
    final prefix =
        nameMatch != null ? text.substring(0, nameMatch.start).trim() : '';

    final isShorthand = prefix.endsWith('this.') || prefix.endsWith('super.');
    final typeSource = (!isShorthand && prefix.isNotEmpty) ? prefix : null;

    return ParameterSignature(
      name: name,
      isNamed: isNamed,
      isRequired: required,
      defaultValueSource: defaultValueSource,
      typeSource: typeSource,
    );
  }
}
