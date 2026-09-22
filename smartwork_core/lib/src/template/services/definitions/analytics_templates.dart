import '../../../models/service_definition.dart';

String analyticsServiceSource() {
  return '''import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Application-level boundary for product analytics.
///
/// Provider-neutral: a clean application-level boundary a future
/// milestone can connect a real analytics provider to. SmartWork itself
/// never adds a concrete provider SDK here.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  String? _userId;
  final Map<String, Object?> _userProperties = {};

  bool _initialized = false;

  /// Whether [initialize] has already run.
  bool get isInitialized => _initialized;

  String? get userId => _userId;

  Map<String, Object?> get userProperties => Map.unmodifiable(_userProperties);

  /// Called once from `Bootstrap.initialize()`, before `runApp()`. Safe
  /// to call more than once — returns immediately if already
  /// initialized.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// No analytics SDK is included by default; this logs to the debug
  /// console in debug builds so events are visible during development,
  /// and is a no-op in release.
  void trackEvent(String name, {Map<String, Object?>? parameters}) {
    if (!kDebugMode) return;
    developer.log(
      'trackEvent: \$name \${parameters ?? const {}}',
      name: 'Analytics',
    );
  }

  void setUserId(String? userId) {
    _userId = userId;
    if (!kDebugMode) return;
    developer.log('setUserId: \$userId', name: 'Analytics');
  }

  void setUserProperty(String name, Object? value) {
    _userProperties[name] = value;
    if (!kDebugMode) return;
    developer.log('setUserProperty: \$name=\$value', name: 'Analytics');
  }

  void logScreenView(String screenName) {
    if (!kDebugMode) return;
    developer.log('logScreenView: \$screenName', name: 'Analytics');
  }
}
''';
}

String analyticsServiceTestSource(String projectName) {
  final importPath =
      'package:$projectName/services/${Service.analytics.folderName}/'
      'analytics_service.dart';
  return '''import 'package:flutter_test/flutter_test.dart';

import '$importPath';

void main() {
  test('instance is a singleton', () {
    final a = AnalyticsService.instance;
    final b = AnalyticsService.instance;
    expect(a, same(b));
  });

  test('initialize() is idempotent', () async {
    await AnalyticsService.instance.initialize();
    await AnalyticsService.instance.initialize();

    expect(AnalyticsService.instance.isInitialized, isTrue);
  });

  test('setUserId() stores the current user id', () {
    AnalyticsService.instance.setUserId('user-42');

    expect(AnalyticsService.instance.userId, 'user-42');
  });

  test('setUserProperty() stores the property for later inspection', () {
    AnalyticsService.instance.setUserProperty('plan', 'pro');

    expect(AnalyticsService.instance.userProperties['plan'], 'pro');
  });

  test('trackEvent()/logScreenView() run without throwing', () {
    expect(
      () => AnalyticsService.instance.trackEvent(
        'login_success',
        parameters: {'method': 'email'},
      ),
      returnsNormally,
    );
    expect(
      () => AnalyticsService.instance.logScreenView('home'),
      returnsNormally,
    );
  });
}
''';
}
