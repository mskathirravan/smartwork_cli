import '../../../models/service_definition.dart';

String notificationServiceSource() {
  return '''import 'dart:async';

/// The current push-notification permission state. Never granted by
/// [NotificationService] itself — SmartWork adds no push provider, so
/// there is nothing real to grant permission from.
enum NotificationPermissionStatus { notDetermined, denied, granted }

/// Application-level boundary for push notifications.
///
/// Provider-neutral: a clean application-level boundary a future
/// milestone can connect a real push provider to. SmartWork itself
/// never adds a concrete provider SDK here.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  NotificationPermissionStatus _permissionStatus =
      NotificationPermissionStatus.notDetermined;

  bool _initialized = false;

  /// Whether [initialize] has already run.
  bool get isInitialized => _initialized;

  NotificationPermissionStatus get permissionStatus => _permissionStatus;

  /// Incoming notification payloads — feed them in via [handleIncoming].
  Stream<Map<String, dynamic>> get onNotification => _controller.stream;

  /// Called once from `Bootstrap.initialize()`, before `runApp()`. Safe
  /// to call more than once — returns immediately if already
  /// initialized.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// No push provider is included by default, so there is nothing real
  /// to request permission from; returns [NotificationPermissionStatus.
  /// denied] as the safe baseline until a provider is added.
  Future<NotificationPermissionStatus> requestPermission() async {
    _permissionStatus = NotificationPermissionStatus.denied;
    return _permissionStatus;
  }

  /// No push provider is included by default, so there is no real
  /// device token; returns `null` until a provider is added.
  Future<String?> getToken() async => null;

  /// Feeds an incoming notification payload to [onNotification]
  /// listeners. This is the real integration point: a future push
  /// provider's delivery callback calls this instead of application
  /// code, so nothing downstream changes when one is added.
  void handleIncoming(Map<String, dynamic> payload) {
    _controller.add(payload);
  }

  /// Closes [onNotification]. For a genuinely long-running service like
  /// this one — see `ServiceDefinition.hasInitialize` — closing what
  /// [initialize] opened when the app (or a test) is done with it.
  Future<void> dispose() async {
    await _controller.close();
  }
}
''';
}

String notificationServiceTestSource(String projectName) {
  final importPath =
      'package:$projectName/services/${Service.notification.folderName}/'
      'notification_service.dart';
  return '''import 'package:flutter_test/flutter_test.dart';

import '$importPath';

void main() {
  test('instance is a singleton', () {
    final a = NotificationService.instance;
    final b = NotificationService.instance;
    expect(a, same(b));
  });

  test('permissionStatus starts as notDetermined', () {
    expect(
      NotificationService.instance.permissionStatus,
      NotificationPermissionStatus.notDetermined,
    );
  });

  test('initialize() is idempotent', () async {
    await NotificationService.instance.initialize();
    await NotificationService.instance.initialize();

    expect(NotificationService.instance.isInitialized, isTrue);
  });

  test('requestPermission() returns denied as the safe baseline with no '
      'push provider configured', () async {
    final status = await NotificationService.instance.requestPermission();

    expect(status, NotificationPermissionStatus.denied);
    expect(
      NotificationService.instance.permissionStatus,
      NotificationPermissionStatus.denied,
    );
  });

  test('getToken() returns null with no push provider configured', () async {
    expect(await NotificationService.instance.getToken(), isNull);
  });

  test('handleIncoming() emits the payload on onNotification', () async {
    final events = <Map<String, dynamic>>[];
    final subscription = NotificationService.instance.onNotification.listen(
      events.add,
    );

    NotificationService.instance.handleIncoming({'title': 'Hello'});
    await Future<void>.delayed(Duration.zero);

    expect(events, [
      {'title': 'Hello'},
    ]);
    await subscription.cancel();
  });
}
''';
}
