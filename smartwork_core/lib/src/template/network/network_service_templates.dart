import '../../models/project_config.dart';
import '../template.dart';
import '../testing/storage_test_setup.dart';

class NetworkServiceTemplates {
  static String exceptionSource() {
    return '''/// Provider-neutral error every `NetworkService` call can throw — the
/// same shape regardless of which provider (Http/Dio/other) is
/// actually configured.
abstract class NetworkException implements Exception {
  final String message;

  const NetworkException(this.message);

  @override
  String toString() => message;
}

/// The request timed out — either connecting, sending, or waiting for a
/// response, within `NetworkService.timeout` (or a per-request override).
class NetworkTimeoutException extends NetworkException {
  const NetworkTimeoutException([super.message = 'The request timed out.']);
}

/// No real connection to the server could be established at all — no
/// internet, DNS failure, connection refused, an untrusted certificate,
/// ... — as distinct from [NetworkTimeoutException] (a connection that
/// *was* attempted but took too long) or an HTTP-level error (a
/// connection that succeeded, but the server responded with a failing
/// status code).
class NetworkConnectionException extends NetworkException {
  const NetworkConnectionException([
    super.message = 'Could not connect to the network.',
  ]);
}

class UnauthorizedException extends NetworkException {
  const UnauthorizedException([super.message = 'Unauthorized (401).']);
}

class ForbiddenException extends NetworkException {
  const ForbiddenException([super.message = 'Forbidden (403).']);
}

class NotFoundException extends NetworkException {
  const NotFoundException([super.message = 'Not found (404).']);
}

class ServerErrorException extends NetworkException {
  final int statusCode;

  ServerErrorException(this.statusCode, [String? message])
    : super(message ?? 'Server error (\$statusCode).');
}

/// A response came back, but it could not be treated as one — e.g. a
/// provider reporting a failed response with no usable status code at
/// all. Distinct from [ServerErrorException]/[UnknownNetworkException],
/// which both have a real, if unwelcome, response to report.
class InvalidResponseException extends NetworkException {
  const InvalidResponseException([
    super.message = 'The server returned an invalid response.',
  ]);
}

class UnknownNetworkException extends NetworkException {
  const UnknownNetworkException([
    super.message = 'An unknown network error occurred.',
  ]);
}

/// Maps a real HTTP status code to the matching [NetworkException] —
/// the one place every provider translates a real response into
/// SmartWork's provider-neutral error model.
NetworkException networkExceptionForStatusCode(int statusCode) {
  return switch (statusCode) {
    401 => const UnauthorizedException(),
    403 => const ForbiddenException(),
    404 => const NotFoundException(),
    >= 500 => ServerErrorException(statusCode),
    _ => const UnknownNetworkException(),
  };
}
''';
  }

  static String responseSource() {
    return '''/// A provider-neutral response — the same shape regardless of which
/// provider (Http/Dio/other) `NetworkService` is actually backed by.
class NetworkResponse {
  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;

  const NetworkResponse({
    required this.statusCode,
    this.data,
    this.headers = const {},
  });
}
''';
  }

  static String serviceSource(Network network) {
    return switch (network) {
      Network.http => _httpServiceSource(),
      Network.dio => _dioServiceSource(),
      Network.other => _otherServiceSource(),
    };
  }

  static String _httpServiceSource() {
    return '''import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../../core/environment/environment_manager.dart';
import 'network_exception.dart';
import 'network_response.dart';

/// Application-level boundary for network requests.
///
/// Provider-neutral: features, repositories, and data sources call this
/// — never `package:http`/`package:dio` directly. The configured
/// provider (Http here) is an implementation detail of this file alone.
class NetworkService {
  NetworkService._();

  static final NetworkService instance = NetworkService._();

  http.Client _client = http.Client();

  /// Swaps the underlying client for a test double. Never used by
  /// generated application code — only by this service's own generated
  /// test.
  @visibleForTesting
  set debugClient(http.Client client) => _client = client;

  final Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
  };

  /// Applied to every request this service makes, unless a call passes
  /// its own `timeout:`.
  Duration timeout = const Duration(seconds: 30);

  /// Sets the `Authorization` header sent with every subsequent
  /// request — e.g. from `SecureSessionManager.instance.accessToken`
  /// after sign-in. Pass `null` to remove it (e.g. on sign-out).
  void setAuthToken(String? token) {
    if (token == null) {
      _defaultHeaders.remove('Authorization');
    } else {
      _defaultHeaders['Authorization'] = 'Bearer \$token';
    }
  }

  /// Sets a header sent with every subsequent request (e.g. a custom
  /// API key header). `Content-Type` defaults to `application/json`.
  void setDefaultHeader(String key, String value) =>
      _defaultHeaders[key] = value;

  Future<NetworkResponse> get(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _send(
    'GET',
    path,
    queryParameters: queryParameters,
    headers: headers,
    timeout: timeout,
  );

  Future<NetworkResponse> post(
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _send(
    'POST',
    path,
    queryParameters: queryParameters,
    body: body,
    headers: headers,
    timeout: timeout,
  );

  Future<NetworkResponse> put(
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _send(
    'PUT',
    path,
    queryParameters: queryParameters,
    body: body,
    headers: headers,
    timeout: timeout,
  );

  Future<NetworkResponse> patch(
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _send(
    'PATCH',
    path,
    queryParameters: queryParameters,
    body: body,
    headers: headers,
    timeout: timeout,
  );

  Future<NetworkResponse> delete(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _send(
    'DELETE',
    path,
    queryParameters: queryParameters,
    headers: headers,
    timeout: timeout,
  );

  Future<NetworkResponse> _send(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final baseUri = Uri.parse(
      '\${EnvironmentManager.instance.currentBaseUrl}\$path',
    );
    final uri = queryParameters == null || queryParameters.isEmpty
        ? baseUri
        : baseUri.replace(
            queryParameters: {...baseUri.queryParameters, ...queryParameters},
          );

    final request = http.Request(method, uri)
      ..headers.addAll(_defaultHeaders)
      ..headers.addAll(headers ?? const {});
    if (body != null) {
      request.body = body is String ? body : jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout ?? this.timeout),
      );
    } on TimeoutException {
      throw const NetworkTimeoutException();
    } on http.ClientException {
      throw const NetworkConnectionException();
    } catch (_) {
      throw const UnknownNetworkException();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return NetworkResponse(
        statusCode: response.statusCode,
        data: response.body,
        headers: response.headers,
      );
    }
    throw networkExceptionForStatusCode(response.statusCode);
  }
}
''';
  }

  static String _dioServiceSource() {
    return '''import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../../core/environment/environment_manager.dart';
import 'network_exception.dart';
import 'network_response.dart';

/// Application-level boundary for network requests.
///
/// Provider-neutral: features, repositories, and data sources call this
/// — never `package:http`/`package:dio` directly. The configured
/// provider (Dio here) is an implementation detail of this file alone.
class NetworkService {
  NetworkService._();

  static final NetworkService instance = NetworkService._();

  Dio _dio = Dio();

  /// Swaps the underlying client for a test double. Never used by
  /// generated application code — only by this service's own generated
  /// test.
  @visibleForTesting
  set debugDio(Dio dio) => _dio = dio;

  /// Applied to every request this service makes, unless a call passes
  /// its own `timeout:`.
  Duration timeout = const Duration(seconds: 30);

  /// Sets the `Authorization` header sent with every subsequent
  /// request — e.g. from `SecureSessionManager.instance.accessToken`
  /// after sign-in. Pass `null` to remove it (e.g. on sign-out).
  void setAuthToken(String? token) {
    if (token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer \$token';
    }
  }

  /// Sets a header sent with every subsequent request.
  void setDefaultHeader(String key, String value) =>
      _dio.options.headers[key] = value;

  Future<NetworkResponse> get(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _send(
    'GET',
    path,
    queryParameters: queryParameters,
    headers: headers,
    timeout: timeout,
  );

  Future<NetworkResponse> post(
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _send(
    'POST',
    path,
    queryParameters: queryParameters,
    body: body,
    headers: headers,
    timeout: timeout,
  );

  Future<NetworkResponse> put(
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _send(
    'PUT',
    path,
    queryParameters: queryParameters,
    body: body,
    headers: headers,
    timeout: timeout,
  );

  Future<NetworkResponse> patch(
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _send(
    'PATCH',
    path,
    queryParameters: queryParameters,
    body: body,
    headers: headers,
    timeout: timeout,
  );

  Future<NetworkResponse> delete(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _send(
    'DELETE',
    path,
    queryParameters: queryParameters,
    headers: headers,
    timeout: timeout,
  );

  Future<NetworkResponse> _send(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    _dio.options.baseUrl = EnvironmentManager.instance.currentBaseUrl;
    _dio.options.connectTimeout = this.timeout;

    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: headers,
          sendTimeout: timeout ?? this.timeout,
          receiveTimeout: timeout ?? this.timeout,
        ),
      );
      return NetworkResponse(
        statusCode: response.statusCode ?? 200,
        data: response.data,
        headers: response.headers.map.map(
          (key, values) => MapEntry(key, values.join(',')),
        ),
      );
    } on DioException catch (e) {
      final isTimeout =
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      if (isTimeout) throw const NetworkTimeoutException();

      final isConnectionFailure =
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.badCertificate;
      if (isConnectionFailure) throw const NetworkConnectionException();

      final statusCode = e.response?.statusCode;
      if (statusCode != null) throw networkExceptionForStatusCode(statusCode);

      if (e.type == DioExceptionType.badResponse) {
        throw const InvalidResponseException();
      }
      throw const UnknownNetworkException();
    } catch (_) {
      throw const UnknownNetworkException();
    }
  }
}
''';
  }

  static String _otherServiceSource() {
    return '''import 'network_response.dart';

/// Application-level boundary for network requests.
///
/// Network is configured as `other` — SmartWork added no networking
/// package. Add your own (e.g. `http`, `dio`, or another of your
/// choice) to `pubspec.yaml` and implement the methods below with it —
/// every feature already calls this one class, so nothing else needs
/// to change once you do.
class NetworkService {
  NetworkService._();

  static final NetworkService instance = NetworkService._();

  void setAuthToken(String? token) {}

  void setDefaultHeader(String key, String value) {}

  Future<NetworkResponse> get(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _unimplemented();

  Future<NetworkResponse> post(
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _unimplemented();

  Future<NetworkResponse> put(
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _unimplemented();

  Future<NetworkResponse> patch(
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _unimplemented();

  Future<NetworkResponse> delete(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _unimplemented();

  Never _unimplemented() {
    throw UnimplementedError(
      'Network is configured as `other`. Add your own networking '
      "package and implement NetworkService's methods with it.",
    );
  }
}
''';
  }

  static Template testTemplate(Network network, Storage storage) {
    return Template(
      content: switch (network) {
        Network.http => _httpTestSource(storage),
        Network.dio => _dioTestSource(storage),
        Network.other => _otherTestSource(),
      },
    );
  }

  static String _httpTestSource(Storage storage) {
    return '''import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
${StorageTestSetup.imports(storage)}

import 'package:{{projectName}}/core/environment/environment.dart';
import 'package:{{projectName}}/core/environment/environment_manager.dart';
import 'package:{{projectName}}/services/network/network_exception.dart';
import 'package:{{projectName}}/services/network/network_service.dart';
import 'package:{{projectName}}/services/storage/storage_service.dart';

class _StubClient extends http.BaseClient {
  final int statusCode;
  final String body;
  final List<http.BaseRequest> requests = [];

  _StubClient({this.statusCode = 200, this.body = ''});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return http.StreamedResponse(Stream.value(body.codeUnits), statusCode);
  }
}

class _ThrowingClient extends http.BaseClient {
  final Object error;

  _ThrowingClient(this.error);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw error;
  }
}

${StorageTestSetup.helperClass(storage)}void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

${StorageTestSetup.setUpAndTearDown(storage)}

  tearDown(() async {
    await EnvironmentManager.instance.setEnvironment(Environment.prod);
    NetworkService.instance.setAuthToken(null);
  });

  test('instance is a singleton', () {
    final a = NetworkService.instance;
    final b = NetworkService.instance;
    expect(a, same(b));
  });

  test('requests resolve through the active environment base URL', () async {
    final stub = _StubClient();
    NetworkService.instance.debugClient = stub;

    await NetworkService.instance.get('/probe');

    expect(
      stub.requests.single.url.toString(),
      '\${EnvironmentManager.instance.currentBaseUrl}/probe',
    );
  });

  group('queryParameters', () {
    test('no queryParameters leaves the URI without a query string', () async {
      final stub = _StubClient();
      NetworkService.instance.debugClient = stub;

      await NetworkService.instance.get('/probe');

      expect(stub.requests.single.url.query, isEmpty);
    });

    test('a single queryParameter is encoded onto the URI', () async {
      final stub = _StubClient();
      NetworkService.instance.debugClient = stub;

      await NetworkService.instance.get(
        '/probe',
        queryParameters: {'page': '1'},
      );

      expect(stub.requests.single.url.queryParameters, {'page': '1'});
    });

    test('multiple queryParameters are all encoded onto the URI', () async {
      final stub = _StubClient();
      NetworkService.instance.debugClient = stub;

      await NetworkService.instance.get(
        '/probe',
        queryParameters: {'page': '1', 'limit': '20', 'search': 'flutter'},
      );

      expect(stub.requests.single.url.queryParameters, {
        'page': '1',
        'limit': '20',
        'search': 'flutter',
      });
    });

    test('special characters in queryParameters are percent-encoded and '
        'decode back to the original value', () async {
      final stub = _StubClient();
      NetworkService.instance.debugClient = stub;

      await NetworkService.instance.get(
        '/probe',
        queryParameters: {'q': 'a b&c=d/e'},
      );

      expect(stub.requests.single.url.queryParameters['q'], 'a b&c=d/e');
    });

    test('an empty queryParameter value is preserved', () async {
      final stub = _StubClient();
      NetworkService.instance.debugClient = stub;

      await NetworkService.instance.get(
        '/probe',
        queryParameters: {'search': ''},
      );

      expect(stub.requests.single.url.queryParameters['search'], '');
    });
  });

  group('headers', () {
    test('setDefaultHeader() is sent on every request', () async {
      final stub = _StubClient();
      NetworkService.instance.debugClient = stub;
      NetworkService.instance.setDefaultHeader('X-Api-Key', 'abc');

      await NetworkService.instance.get('/probe');

      expect(stub.requests.single.headers['X-Api-Key'], 'abc');
    });

    test('setAuthToken() sends a Bearer Authorization header', () async {
      final stub = _StubClient();
      NetworkService.instance.debugClient = stub;
      NetworkService.instance.setAuthToken('abc123');

      await NetworkService.instance.get('/probe');

      expect(stub.requests.single.headers['Authorization'], 'Bearer abc123');
    });

    test(
      'a request header overrides a default header of the same name',
      () async {
        final stub = _StubClient();
        NetworkService.instance.debugClient = stub;
        NetworkService.instance.setDefaultHeader('Content-Type', 'default/x');

        await NetworkService.instance.get(
          '/probe',
          headers: {'Content-Type': 'override/y'},
        );

        expect(stub.requests.single.headers['Content-Type'], 'override/y');
      },
    );

    test('a request header not present in the defaults is still sent '
        'alongside them', () async {
      final stub = _StubClient();
      NetworkService.instance.debugClient = stub;
      NetworkService.instance.setDefaultHeader('X-Api-Key', 'abc');

      await NetworkService.instance.get(
        '/probe',
        headers: {'X-Trace-Id': 'trace-1'},
      );

      expect(stub.requests.single.headers['X-Api-Key'], 'abc');
      expect(stub.requests.single.headers['X-Trace-Id'], 'trace-1');
    });
  });

  test('a 2xx response returns a NetworkResponse with the real body', () async {
    final stub = _StubClient(statusCode: 200, body: '{"ok":true}');
    NetworkService.instance.debugClient = stub;

    final response = await NetworkService.instance.get('/probe');

    expect(response.statusCode, 200);
    expect(response.data, '{"ok":true}');
  });

  test('a 401 response throws UnauthorizedException', () async {
    NetworkService.instance.debugClient = _StubClient(statusCode: 401);

    expect(
      () => NetworkService.instance.get('/probe'),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('a 403 response throws ForbiddenException', () async {
    NetworkService.instance.debugClient = _StubClient(statusCode: 403);

    expect(
      () => NetworkService.instance.get('/probe'),
      throwsA(isA<ForbiddenException>()),
    );
  });

  test('a 404 response throws NotFoundException', () async {
    NetworkService.instance.debugClient = _StubClient(statusCode: 404);

    expect(
      () => NetworkService.instance.get('/probe'),
      throwsA(isA<NotFoundException>()),
    );
  });

  test(
    'a 500 response throws ServerErrorException with the real code',
    () async {
      NetworkService.instance.debugClient = _StubClient(statusCode: 500);

      try {
        await NetworkService.instance.get('/probe');
        fail('expected ServerErrorException');
      } on ServerErrorException catch (e) {
        expect(e.statusCode, 500);
      }
    },
  );

  test('an unmapped error status throws UnknownNetworkException', () async {
    NetworkService.instance.debugClient = _StubClient(statusCode: 418);

    expect(
      () => NetworkService.instance.get('/probe'),
      throwsA(isA<UnknownNetworkException>()),
    );
  });

  test(
    'a client-level connection failure throws NetworkConnectionException',
    () async {
      NetworkService.instance.debugClient = _ThrowingClient(
        http.ClientException('Connection refused'),
      );

      expect(
        () => NetworkService.instance.get('/probe'),
        throwsA(isA<NetworkConnectionException>()),
      );
    },
  );

  test(
    'a request that exceeds the timeout throws NetworkTimeoutException',
    () async {
      NetworkService.instance.timeout = const Duration(milliseconds: 1);
      addTearDown(
        () => NetworkService.instance.timeout = const Duration(seconds: 30),
      );
      NetworkService.instance.debugClient = _SlowClient();

      expect(
        () => NetworkService.instance.get('/probe'),
        throwsA(isA<NetworkTimeoutException>()),
      );
    },
  );

  test(
    'post()/put()/patch()/delete() all reach the configured client',
    () async {
      final stub = _StubClient();
      NetworkService.instance.debugClient = stub;

      await NetworkService.instance.post('/a', body: {'x': 1});
      await NetworkService.instance.put('/b', body: {'x': 1});
      await NetworkService.instance.patch('/c', body: {'x': 1});
      await NetworkService.instance.delete('/d');

      expect(stub.requests.map((r) => r.method), [
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
      ]);
    },
  );
}

class _SlowClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future<void>.delayed(const Duration(seconds: 5));
    return http.StreamedResponse(const Stream.empty(), 200);
  }
}
''';
  }

  static String _dioTestSource(Storage storage) {
    return '''import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
${StorageTestSetup.imports(storage)}

import 'package:{{projectName}}/core/environment/environment.dart';
import 'package:{{projectName}}/core/environment/environment_manager.dart';
import 'package:{{projectName}}/services/network/network_exception.dart';
import 'package:{{projectName}}/services/network/network_service.dart';
import 'package:{{projectName}}/services/storage/storage_service.dart';

class _StubAdapter implements HttpClientAdapter {
  final int statusCode;
  final String body;
  final List<RequestOptions> requests = [];

  _StubAdapter({this.statusCode = 200, this.body = '{}'});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(body, statusCode);
  }

  @override
  void close({bool force = false}) {}
}

class _ThrowingAdapter implements HttpClientAdapter {
  final DioException Function(RequestOptions options) build;

  _ThrowingAdapter(this.build);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw build(options);
  }

  @override
  void close({bool force = false}) {}
}

${StorageTestSetup.helperClass(storage)}void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

${StorageTestSetup.setUpAndTearDown(storage)}

  tearDown(() async {
    await EnvironmentManager.instance.setEnvironment(Environment.prod);
    NetworkService.instance.setAuthToken(null);
  });

  test('instance is a singleton', () {
    final a = NetworkService.instance;
    final b = NetworkService.instance;
    expect(a, same(b));
  });

  test('requests resolve through the active environment base URL', () async {
    final adapter = _StubAdapter();
    NetworkService.instance.debugDio = Dio()..httpClientAdapter = adapter;

    await NetworkService.instance.get('/probe');

    expect(
      adapter.requests.single.uri.toString(),
      '\${EnvironmentManager.instance.currentBaseUrl}/probe',
    );
  });

  group('queryParameters', () {
    test('no queryParameters leaves the URI without a query string', () async {
      final adapter = _StubAdapter();
      NetworkService.instance.debugDio = Dio()..httpClientAdapter = adapter;

      await NetworkService.instance.get('/probe');

      expect(adapter.requests.single.uri.query, isEmpty);
    });

    test('a single queryParameter is encoded onto the URI', () async {
      final adapter = _StubAdapter();
      NetworkService.instance.debugDio = Dio()..httpClientAdapter = adapter;

      await NetworkService.instance.get(
        '/probe',
        queryParameters: {'page': '1'},
      );

      expect(adapter.requests.single.uri.queryParameters, {'page': '1'});
    });

    test('multiple queryParameters are all encoded onto the URI', () async {
      final adapter = _StubAdapter();
      NetworkService.instance.debugDio = Dio()..httpClientAdapter = adapter;

      await NetworkService.instance.get(
        '/probe',
        queryParameters: {'page': '1', 'limit': '20', 'search': 'flutter'},
      );

      expect(adapter.requests.single.uri.queryParameters, {
        'page': '1',
        'limit': '20',
        'search': 'flutter',
      });
    });

    test('special characters in queryParameters are percent-encoded and '
        'decode back to the original value', () async {
      final adapter = _StubAdapter();
      NetworkService.instance.debugDio = Dio()..httpClientAdapter = adapter;

      await NetworkService.instance.get(
        '/probe',
        queryParameters: {'q': 'a b&c=d/e'},
      );

      expect(adapter.requests.single.uri.queryParameters['q'], 'a b&c=d/e');
    });

    test('an empty queryParameter value is preserved', () async {
      final adapter = _StubAdapter();
      NetworkService.instance.debugDio = Dio()..httpClientAdapter = adapter;

      await NetworkService.instance.get(
        '/probe',
        queryParameters: {'search': ''},
      );

      expect(adapter.requests.single.uri.queryParameters['search'], '');
    });
  });

  group('headers', () {
    test('setDefaultHeader() is sent on every request', () async {
      final adapter = _StubAdapter();
      NetworkService.instance.debugDio = Dio()..httpClientAdapter = adapter;
      NetworkService.instance.setDefaultHeader('X-Api-Key', 'abc');

      await NetworkService.instance.get('/probe');

      expect(adapter.requests.single.headers['X-Api-Key'], 'abc');
    });

    test('setAuthToken() sends a Bearer Authorization header', () async {
      final adapter = _StubAdapter();
      NetworkService.instance.debugDio = Dio()..httpClientAdapter = adapter;
      NetworkService.instance.setAuthToken('abc123');

      await NetworkService.instance.get('/probe');

      expect(adapter.requests.single.headers['Authorization'], 'Bearer abc123');
    });

    test(
      'a request header overrides a default header of the same name',
      () async {
        final adapter = _StubAdapter();
        NetworkService.instance.debugDio = Dio()..httpClientAdapter = adapter;
        NetworkService.instance.setDefaultHeader('X-Trace-Id', 'default');

        await NetworkService.instance.get(
          '/probe',
          headers: {'X-Trace-Id': 'override'},
        );

        expect(adapter.requests.single.headers['X-Trace-Id'], 'override');
      },
    );
  });

  test('a 2xx response returns a NetworkResponse', () async {
    NetworkService.instance.debugDio = Dio()
      ..httpClientAdapter = _StubAdapter(statusCode: 200, body: '{"ok":true}');

    final response = await NetworkService.instance.get('/probe');

    expect(response.statusCode, 200);
  });

  test('a 401 response throws UnauthorizedException', () async {
    NetworkService.instance.debugDio = Dio()
      ..httpClientAdapter = _StubAdapter(statusCode: 401);

    expect(
      () => NetworkService.instance.get('/probe'),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('a 404 response throws NotFoundException', () async {
    NetworkService.instance.debugDio = Dio()
      ..httpClientAdapter = _StubAdapter(statusCode: 404);

    expect(
      () => NetworkService.instance.get('/probe'),
      throwsA(isA<NotFoundException>()),
    );
  });

  test(
    'a 500 response throws ServerErrorException with the real code',
    () async {
      NetworkService.instance.debugDio = Dio()
        ..httpClientAdapter = _StubAdapter(statusCode: 500);

      try {
        await NetworkService.instance.get('/probe');
        fail('expected ServerErrorException');
      } on ServerErrorException catch (e) {
        expect(e.statusCode, 500);
      }
    },
  );

  test('a connectionError throws NetworkConnectionException, not '
      'UnknownNetworkException', () async {
    NetworkService.instance.debugDio = Dio()
      ..httpClientAdapter = _ThrowingAdapter(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );

    expect(
      () => NetworkService.instance.get('/probe'),
      throwsA(isA<NetworkConnectionException>()),
    );
  });

  test('a connectionTimeout throws NetworkTimeoutException', () async {
    NetworkService.instance.debugDio = Dio()
      ..httpClientAdapter = _ThrowingAdapter(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
      );

    expect(
      () => NetworkService.instance.get('/probe'),
      throwsA(isA<NetworkTimeoutException>()),
    );
  });

  test(
    'a badResponse with no status code throws InvalidResponseException',
    () async {
      NetworkService.instance.debugDio = Dio()
        ..httpClientAdapter = _ThrowingAdapter(
          (options) => DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
          ),
        );

      expect(
        () => NetworkService.instance.get('/probe'),
        throwsA(isA<InvalidResponseException>()),
      );
    },
  );

  test(
    'post()/put()/patch()/delete() all reach the configured client',
    () async {
      final adapter = _StubAdapter();
      NetworkService.instance.debugDio = Dio()..httpClientAdapter = adapter;

      await NetworkService.instance.post('/a', body: {'x': 1});
      await NetworkService.instance.put('/b', body: {'x': 1});
      await NetworkService.instance.patch('/c', body: {'x': 1});
      await NetworkService.instance.delete('/d');

      expect(adapter.requests.map((r) => r.method), [
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
      ]);
    },
  );
}
''';
  }

  static String _otherTestSource() {
    return '''import 'package:flutter_test/flutter_test.dart';

import 'package:{{projectName}}/services/network/network_service.dart';

void main() {
  test('instance is a singleton', () {
    final a = NetworkService.instance;
    final b = NetworkService.instance;
    expect(a, same(b));
  });

  test('setAuthToken()/setDefaultHeader() are harmless no-ops', () {
    expect(() => NetworkService.instance.setAuthToken('x'), returnsNormally);
    expect(
      () => NetworkService.instance.setDefaultHeader('X-Test', 'y'),
      returnsNormally,
    );
  });

  test('every request method throws UnimplementedError until a provider '
      'is added', () {
    expect(
      () => NetworkService.instance.get('/probe'),
      throwsUnimplementedError,
    );
    expect(
      () => NetworkService.instance.post('/probe'),
      throwsUnimplementedError,
    );
    expect(
      () => NetworkService.instance.put('/probe'),
      throwsUnimplementedError,
    );
    expect(
      () => NetworkService.instance.patch('/probe'),
      throwsUnimplementedError,
    );
    expect(
      () => NetworkService.instance.delete('/probe'),
      throwsUnimplementedError,
    );
  });

  test('queryParameters/timeout are accepted but have no effect on the '
      'stub — the contract stays consistent across every provider', () {
    expect(
      () => NetworkService.instance.get(
        '/probe',
        queryParameters: {'page': '1'},
        timeout: const Duration(seconds: 5),
      ),
      throwsUnimplementedError,
    );
  });
}
''';
  }
}
