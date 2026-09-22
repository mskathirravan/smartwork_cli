import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('DartSignatureAnalyzer.constructorSignature', () {
    test('reads a positional this.-shorthand constructor', () {
      const source = '''
class AuthRepositoryImpl {
  final AuthDataSource dataSource;
  const AuthRepositoryImpl(this.dataSource);
}
''';
      final sig = DartSignatureAnalyzer()
          .constructorSignature(source, 'AuthRepositoryImpl');

      expect(sig, isNotNull);
      expect(sig!.parameters, hasLength(1));
      expect(sig.parameters.single.name, 'dataSource');
      expect(sig.parameters.single.isPositional, isTrue);
      expect(sig.parameters.single.isRequired, isTrue);
      expect(sig.parameters.single.defaultValueSource, isNull);
    });

    test('reads a named required constructor parameter', () {
      const source = '''
class LoginCubit {
  LoginCubit({required this.repository});
  final AuthRepository repository;
}
''';
      final sig =
          DartSignatureAnalyzer().constructorSignature(source, 'LoginCubit');

      expect(sig!.parameters.single.name, 'repository');
      expect(sig.parameters.single.isNamed, isTrue);
      expect(sig.parameters.single.isRequired, isTrue);
    });

    test(
        'reads a named optional constructor parameter with a default '
        'value', () {
      const source = '''
class LoginCubit {
  LoginCubit({this.rememberMe = false});
  final bool rememberMe;
}
''';
      final sig =
          DartSignatureAnalyzer().constructorSignature(source, 'LoginCubit');

      expect(sig!.parameters.single.name, 'rememberMe');
      expect(sig.parameters.single.isRequired, isFalse);
      expect(sig.parameters.single.defaultValueSource, 'false');
    });

    test(
        'reads an optional-positional bracketed parameter as not '
        'required', () {
      const source = '''
class Auth {
  const Auth([this.token]);
  final String? token;
}
''';
      final sig = DartSignatureAnalyzer().constructorSignature(source, 'Auth');

      expect(sig!.parameters.single.isRequired, isFalse);
    });

    test('returns null for a class with no explicit constructor', () {
      const source = 'class AuthInitial extends AuthState {}';
      final sig =
          DartSignatureAnalyzer().constructorSignature(source, 'AuthInitial');

      expect(sig, isNull);
    });

    test('returns null for a class not declared in the source', () {
      final sig =
          DartSignatureAnalyzer().constructorSignature('class Foo {}', 'Bar');
      expect(sig, isNull);
    });

    test(
        'never matches a constructor call site inside the class body '
        'as if it were the declaration', () {
      const source = '''
class Wrapper {
  Wrapper({required this.dep});
  final Dep dep;

  static Wrapper create() => Wrapper(dep: Dep());
}
''';
      final sig =
          DartSignatureAnalyzer().constructorSignature(source, 'Wrapper');

      expect(sig!.parameters.single.name, 'dep');
      expect(sig.parameters.single.isRequired, isTrue);
    });
  });

  group('DartSignatureAnalyzer.methodSignature', () {
    test(
        'reads a multi-parameter async method signature — regression: '
        'the `async` keyword between `)` and `{` must not defeat the '
        '"is this a real declaration" check', () {
      const source = '''
class AuthBloc {
  Future<void> login(String email, String password, {bool rememberMe = false}) async {
    // ...
  }
}
''';
      final sig =
          DartSignatureAnalyzer().methodSignature(source, 'AuthBloc', 'login');

      expect(sig, isNotNull);
      expect(sig!.parameters.map((p) => p.name),
          ['email', 'password', 'rememberMe']);
      expect(sig.requiredPositional.map((p) => p.name), ['email', 'password']);
      expect(sig.parameters.last.defaultValueSource, 'false');
    });

    test(
        'never matches a call site of the same method name elsewhere '
        'in the class as if it were the declaration', () {
      const source = '''
class AuthBloc {
  void retry() {
    login('a@test.com', 'password');
  }

  Future<void> login(String email, String password) async {}
}
''';
      final sig =
          DartSignatureAnalyzer().methodSignature(source, 'AuthBloc', 'login');

      expect(sig!.parameters, hasLength(2));
    });

    test('returns null for a method not declared on that class', () {
      final sig =
          DartSignatureAnalyzer().methodSignature('class Foo {}', 'Foo', 'bar');
      expect(sig, isNull);
    });
  });

  group('DartSignatureAnalyzer.methodNames', () {
    test(
        'lists every public method declared directly on the class, '
        'excluding private methods', () {
      const source = '''
class AuthBloc {
  Future<void> login(String email, String password) async {}
  void _internalHelper() {}
  void logout() {}
}
''';
      final names = DartSignatureAnalyzer().methodNames(source, 'AuthBloc');

      expect(names, ['login', 'logout']);
    });
  });

  group('DartSignatureAnalyzer.hierarchyMembers', () {
    test('reads real enum constants', () {
      const source = 'enum LoginState { loading, authenticated, otpRequired }';
      final members =
          DartSignatureAnalyzer().hierarchyMembers(source, 'LoginState');

      expect(members, {'loading', 'authenticated', 'otpRequired'});
    });

    test(
        'reads every class extending or implementing a sealed/abstract '
        'base', () {
      const source = '''
abstract class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading implements AuthState {}
class Unrelated {}
''';
      final members =
          DartSignatureAnalyzer().hierarchyMembers(source, 'AuthState');

      expect(members, {'AuthInitial', 'AuthLoading'});
    });

    test(
        'returns null when the base name is neither an enum nor a '
        'declared class at all — never an empty set standing in for '
        '"unknown"', () {
      final members =
          DartSignatureAnalyzer().hierarchyMembers('class Foo {}', 'Bar');
      expect(members, isNull);
    });
  });
}
