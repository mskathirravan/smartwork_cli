import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('DartLexicalScanner.isCode', () {
    test(
        'marks a // line comment as non-code, real code before it as '
        'code', () {
      final source = 'foo(); // bar(1, 2)';
      final scanner = DartLexicalScanner(source);

      expect(scanner.isCode(source.indexOf('foo')), isTrue);
      expect(scanner.isCode(source.indexOf('bar')), isFalse);
    });

    test('marks a /* */ block comment as non-code', () {
      final source = 'foo(); /* bar(1, 2)\nstill a comment */ baz();';
      final scanner = DartLexicalScanner(source);

      expect(scanner.isCode(source.indexOf('bar')), isFalse);
      expect(scanner.isCode(source.indexOf('still')), isFalse);
      expect(scanner.isCode(source.indexOf('baz')), isTrue);
    });

    test('marks a single-quoted string literal as non-code', () {
      final source = "login('call bloc.login(1, 2) here');";
      final scanner = DartLexicalScanner(source);

      expect(scanner.isCode(source.indexOf('login(')), isTrue);
      expect(scanner.isCode(source.lastIndexOf('login(')), isFalse);
    });

    test('marks a double-quoted string literal as non-code', () {
      final source = 'login("call bloc.login(1, 2) here");';
      final scanner = DartLexicalScanner(source);

      expect(scanner.isCode(source.lastIndexOf('login(')), isFalse);
    });

    test('marks a triple-quoted string as non-code, across lines', () {
      final source = "login();\nfinal x = '''\nlogin(1, 2)\n''';\nreal();";
      final scanner = DartLexicalScanner(source);

      expect(scanner.isCode(source.indexOf('login()')), isTrue);
      expect(scanner.isCode(source.lastIndexOf('login(')), isFalse);
      expect(scanner.isCode(source.indexOf('real()')), isTrue);
    });

    test('respects an escaped quote inside a single-quoted string', () {
      final source = r"login('it\'s a test'); real();";
      final scanner = DartLexicalScanner(source);

      expect(scanner.isCode(source.indexOf('real()')), isTrue);
    });
  });

  group('DartLexicalScanner.matchingBracket', () {
    test('finds the matching close paren for a simple call', () {
      final source = 'login(email, password)';
      final scanner = DartLexicalScanner(source);

      final open = source.indexOf('(');
      expect(scanner.matchingBracket(open), source.indexOf(')'));
    });

    test(
        'finds the matching close paren across a nested named-'
        'parameter brace block — the exact shape a naive `[^)]*`-style '
        'regex cannot handle, since the block itself contains no `)` '
        'but does contain `{`/`}`', () {
      final source = "LoginCubit({required this.repository})";
      final scanner = DartLexicalScanner(source);

      final open = source.indexOf('(');
      expect(scanner.matchingBracket(open), source.length - 1);
    });

    test(
        'finds the matching close paren across a nested call '
        'argument', () {
      final source = 'foo(bar(1, 2), 3)';
      final scanner = DartLexicalScanner(source);

      final open = source.indexOf('(');
      expect(scanner.matchingBracket(open), source.length - 1);
    });

    test('ignores a bracket character that is inside a string literal', () {
      final source = "foo('not a real )', 2)";
      final scanner = DartLexicalScanner(source);

      final open = source.indexOf('(');
      expect(scanner.matchingBracket(open), source.length - 1);
    });

    test('ignores a bracket character that is inside a comment', () {
      final source = 'foo(1 /* ) not real */, 2)';
      final scanner = DartLexicalScanner(source);

      final open = source.indexOf('(');
      expect(scanner.matchingBracket(open), source.length - 1);
    });

    test(
        'returns null for an unmatched opening bracket — an honest '
        "failure, never a guess at where malformed source 'probably' "
        'ends', () {
      final source = 'foo(1, 2';
      final scanner = DartLexicalScanner(source);

      final open = source.indexOf('(');
      expect(scanner.matchingBracket(open), isNull);
    });

    test('returns null when the given offset is not an opening bracket', () {
      final scanner = DartLexicalScanner('foo(1)');
      expect(scanner.matchingBracket(0), isNull);
    });
  });
}
