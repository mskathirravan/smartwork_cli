import '../../../models/service_definition.dart';

String deeplinkServiceSource() {
  return '''import 'dart:async';

/// Application-level boundary for deep link handling.
///
/// Provider-neutral: a clean application-level boundary a future
/// milestone can connect a real deep-link provider to. SmartWork itself
/// never adds a concrete provider SDK here. Never navigates on its
/// own — `AppRouter` remains the single routing authority; wire
/// [uriStream]/[currentUri] into a route push at your own call site.
class DeeplinkService {
  DeeplinkService._();

  static final DeeplinkService instance = DeeplinkService._();

  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  Uri? _currentUri;

  bool _initialized = false;

  /// Whether [initialize] has already run.
  bool get isInitialized => _initialized;

  /// The most recently handled deep link URI, if any.
  Uri? get currentUri => _currentUri;

  /// Emits whenever [handleUri] records a new incoming URI.
  Stream<Uri> get uriStream => _controller.stream;

  /// Called once from `Bootstrap.initialize()`, before `runApp()`. Safe
  /// to call more than once — returns immediately if already
  /// initialized.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// Records an incoming deep link and notifies [uriStream] listeners.
  /// This is the real integration point: a future deep-link package's
  /// delivery callback (or your own platform channel) calls this
  /// instead of application code, so nothing downstream changes when
  /// one is added. Never navigates itself — see the class-level note.
  void handleUri(Uri uri) {
    _currentUri = uri;
    _controller.add(uri);
  }

  /// Closes [uriStream]. For a genuinely long-running service like this
  /// one — see `ServiceDefinition.hasInitialize` — closing what
  /// [initialize] opened when the app (or a test) is done with it.
  Future<void> dispose() async {
    await _controller.close();
  }
}
''';
}

String deeplinkServiceTestSource(String projectName) {
  final importPath =
      'package:$projectName/services/${Service.deeplink.folderName}/'
      'deeplink_service.dart';
  return '''import 'package:flutter_test/flutter_test.dart';

import '$importPath';

void main() {
  test('instance is a singleton', () {
    final a = DeeplinkService.instance;
    final b = DeeplinkService.instance;
    expect(a, same(b));
  });

  test('currentUri is null until a URI is handled', () {
    expect(DeeplinkService.instance.currentUri, isNull);
  });

  test('initialize() is idempotent', () async {
    await DeeplinkService.instance.initialize();
    await DeeplinkService.instance.initialize();

    expect(DeeplinkService.instance.isInitialized, isTrue);
  });

  test('handleUri() records currentUri and emits on uriStream', () async {
    final events = <Uri>[];
    final subscription = DeeplinkService.instance.uriStream.listen(events.add);
    final uri = Uri.parse('myapp://profile/42');

    DeeplinkService.instance.handleUri(uri);
    await Future<void>.delayed(Duration.zero);

    expect(DeeplinkService.instance.currentUri, uri);
    expect(events, [uri]);
    await subscription.cancel();
  });
}
''';
}
