class DartLexicalScanner {
  final String source;
  late final List<bool> _isCode;

  DartLexicalScanner(this.source) {
    _isCode = _scan();
  }

  bool isCode(int offset) =>
      offset >= 0 && offset < _isCode.length && _isCode[offset];

  int? matchingBracket(int openOffset) {
    if (openOffset < 0 || openOffset >= source.length) return null;
    final open = source[openOffset];
    final close = const {'(': ')', '[': ']', '{': '}'}[open];
    if (close == null) return null;

    var depth = 0;
    for (var i = openOffset; i < source.length; i++) {
      if (!isCode(i)) continue;
      final c = source[i];
      if (c == open) {
        depth++;
      } else if (c == close) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }

  static List<String> splitTopLevel(String source) {
    final scanner = DartLexicalScanner(source);
    final parts = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < source.length; i++) {
      if (!scanner.isCode(i)) continue;
      final c = source[i];
      if (c == '(' || c == '[' || c == '{') depth++;
      if (c == ')' || c == ']' || c == '}') depth--;
      if (c == ',' && depth == 0) {
        parts.add(source.substring(start, i));
        start = i + 1;
      }
    }
    final last = source.substring(start).trim();
    if (last.isNotEmpty) parts.add(last);
    return parts;
  }

  List<bool> _scan() {
    final mask = List<bool>.filled(source.length, true);
    var i = 0;
    while (i < source.length) {
      final c = source[i];

      if (c == '/' && _peek(i + 1) == '/') {
        final start = i;
        while (i < source.length && source[i] != '\n') {
          i++;
        }
        _markNonCode(mask, start, i);
        continue;
      }

      if (c == '/' && _peek(i + 1) == '*') {
        final start = i;
        i += 2;
        while (i < source.length && !_at(i, '*/')) {
          i++;
        }
        i = _clamp(i + 2);
        _markNonCode(mask, start, i);
        continue;
      }

      final tripleQuote = _tripleQuoteAt(i);
      if (tripleQuote != null) {
        final start = i;
        i += tripleQuote.length;
        while (i < source.length && !_at(i, tripleQuote)) {
          i++;
        }
        i = _clamp(i + tripleQuote.length);
        _markNonCode(mask, start, i);
        continue;
      }

      if (c == "'" || c == '"') {
        final quote = c;
        final start = i;
        i++;
        while (i < source.length && source[i] != quote) {
          if (source[i] == '\\' && i + 1 < source.length) {
            i += 2;
            continue;
          }
          if (source[i] == '\n') break;
          i++;
        }
        i = _clamp(i + 1);
        _markNonCode(mask, start, i);
        continue;
      }

      i++;
    }
    return mask;
  }

  String? _tripleQuoteAt(int i) {
    for (final q in const ["'''", '"""']) {
      if (_at(i, q)) return q;
    }
    return null;
  }

  bool _at(int i, String text) => source.startsWith(text, i);

  String? _peek(int i) => i < source.length ? source[i] : null;

  int _clamp(int i) => i > source.length ? source.length : i;

  void _markNonCode(List<bool> mask, int start, int end) {
    for (var j = start; j < end && j < mask.length; j++) {
      mask[j] = false;
    }
  }
}
