import '../../../models/service_definition.dart';

String crashReportingServiceSource() {
  return '''import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Application-level boundary for crash/error reporting.
///
/// Provider-neutral: a clean application-level boundary a future
/// milestone can connect a real crash-reporting provider to. SmartWork
/// itself never adds a concrete provider SDK here.
class CrashReportingService {
  CrashReportingService._();

  static final CrashReportingService instance = CrashReportingService._();

  String? _userId;

  bool _initialized = false;

  /// Whether [initialize] has already run.
  bool get isInitialized => _initialized;

  String? get userId => _userId;

  /// Called once from `Bootstrap.initialize()`, before `runApp()`. Safe
  /// to call more than once — returns immediately if already
  /// initialized.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// Associates subsequent reports with [userId] (e.g. after sign-in).
  /// Pass `null` on sign-out.
  void setUser(String? userId) {
    _userId = userId;
  }

  void recordError(Object error, StackTrace? stackTrace, {String? reason}) {
    if (!kDebugMode) return;
    developer.log(
      reason ?? 'recordError',
      name: 'CrashReporting',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void recordException(Exception exception, StackTrace? stackTrace) {
    recordError(exception, stackTrace, reason: 'recordException');
  }

  /// Records a framework-level error. Wire this into
  /// `FlutterError.onError` in `main.dart` to capture rendering/layout
  /// errors Flutter itself catches.
  void recordFlutterError(FlutterErrorDetails details) {
    recordError(details.exception, details.stack, reason: 'recordFlutterError');
  }
}
''';
}

String crashReportingServiceTestSource(String projectName) {
  final importPath =
      'package:$projectName/services/${Service.crashReporting.folderName}/'
      'crash_reporting_service.dart';
  return '''import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '$importPath';

void main() {
  test('instance is a singleton', () {
    final a = CrashReportingService.instance;
    final b = CrashReportingService.instance;
    expect(a, same(b));
  });

  test('initialize() is idempotent', () async {
    await CrashReportingService.instance.initialize();
    await CrashReportingService.instance.initialize();

    expect(CrashReportingService.instance.isInitialized, isTrue);
  });

  test('setUser() stores the current user id', () {
    CrashReportingService.instance.setUser('user-42');

    expect(CrashReportingService.instance.userId, 'user-42');

    CrashReportingService.instance.setUser(null);
  });

  test('recordError/recordException/recordFlutterError run without '
      'throwing', () {
    expect(
      () => CrashReportingService.instance.recordError(
        Exception('boom'),
        StackTrace.current,
      ),
      returnsNormally,
    );
    expect(
      () => CrashReportingService.instance.recordException(
        Exception('boom'),
        StackTrace.current,
      ),
      returnsNormally,
    );
    expect(
      () => CrashReportingService.instance.recordFlutterError(
        FlutterErrorDetails(exception: Exception('boom')),
      ),
      returnsNormally,
    );
  });
}
''';
}
