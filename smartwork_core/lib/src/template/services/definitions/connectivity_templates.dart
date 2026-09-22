import '../../../models/service_definition.dart';

String connectivityMonitorSource() {
  return '''import 'dart:async';

/// Application-level boundary for network connectivity awareness.
///
/// Provider-neutral: a clean application-level boundary a future
/// milestone can connect a real connectivity provider to. SmartWork
/// itself never adds a concrete provider SDK here.
class ConnectivityMonitor {
  ConnectivityMonitor._();

  static final ConnectivityMonitor instance = ConnectivityMonitor._();

  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool _isConnected = true;
  bool _monitoring = false;

  /// The most recently known connectivity state. Optimistic (`true`)
  /// until [reportConnectivity] says otherwise — SmartWork adds no
  /// connectivity package to detect this independently.
  bool get isConnected => _isConnected;

  /// Emits whenever [reportConnectivity] observes a real change while
  /// monitoring is active.
  Stream<bool> get connectionStream => _controller.stream;

  /// Starts monitoring. Called once from `Bootstrap.initialize()`,
  /// before `runApp()`.
  Future<void> initialize() async {
    startMonitoring();
  }

  /// Enables [reportConnectivity] to update [isConnected]/
  /// [connectionStream]. Call again after [stopMonitoring] to resume.
  void startMonitoring() {
    _monitoring = true;
  }

  /// Disables [reportConnectivity] until [startMonitoring] is called
  /// again.
  void stopMonitoring() {
    _monitoring = false;
  }

  /// Reports an observed connectivity change — e.g. from a failed or
  /// recovered network request. This is the real integration point: a
  /// future connectivity package feeds this same method instead of
  /// application code calling it directly, so nothing downstream
  /// changes when one is added. No-ops while not [startMonitoring]ed,
  /// and only notifies [connectionStream] on an actual change.
  void reportConnectivity(bool connected) {
    if (!_monitoring || _isConnected == connected) return;
    _isConnected = connected;
    _controller.add(connected);
  }

  /// Stops monitoring and closes [connectionStream]. For a genuinely
  /// long-running service like this one — see `ServiceDefinition.
  /// hasInitialize` — closing what [initialize] opened when the app (or
  /// a test) is done with it.
  Future<void> dispose() async {
    _monitoring = false;
    await _controller.close();
  }
}
''';
}

String connectivityMonitorTestSource(String projectName) {
  final importPath =
      'package:$projectName/services/${Service.connectivity.folderName}/'
      'connectivity_monitor.dart';
  return '''import 'package:flutter_test/flutter_test.dart';

import '$importPath';

void main() {
  tearDown(() {
    // Reset the singleton to its original defaults — isConnected=true,
    // not monitoring — so no test's outcome depends on a previous
    // test's leftover state.
    ConnectivityMonitor.instance.startMonitoring();
    ConnectivityMonitor.instance.reportConnectivity(true);
    ConnectivityMonitor.instance.stopMonitoring();
  });

  test('instance is a singleton', () {
    final a = ConnectivityMonitor.instance;
    final b = ConnectivityMonitor.instance;
    expect(a, same(b));
  });

  test('isConnected defaults to true (optimistic baseline)', () {
    expect(ConnectivityMonitor.instance.isConnected, isTrue);
  });

  test('reportConnectivity() is a no-op until monitoring starts', () {
    ConnectivityMonitor.instance.reportConnectivity(false);

    expect(ConnectivityMonitor.instance.isConnected, isTrue);
  });

  test(
    'initialize() starts monitoring so reportConnectivity() takes effect',
    () async {
      await ConnectivityMonitor.instance.initialize();

      ConnectivityMonitor.instance.reportConnectivity(false);

      expect(ConnectivityMonitor.instance.isConnected, isFalse);
    },
  );

  test(
    'reportConnectivity() emits on connectionStream while monitoring',
    () async {
      ConnectivityMonitor.instance.startMonitoring();
      final events = <bool>[];
      final subscription = ConnectivityMonitor.instance.connectionStream.listen(
        events.add,
      );

      ConnectivityMonitor.instance.reportConnectivity(false);
      await Future<void>.delayed(Duration.zero);

      expect(events, [false]);
      await subscription.cancel();
    },
  );

  test('reportConnectivity() with the same value emits nothing new', () {
    ConnectivityMonitor.instance.startMonitoring();
    ConnectivityMonitor.instance.reportConnectivity(true);
    final events = <bool>[];
    final subscription = ConnectivityMonitor.instance.connectionStream.listen(
      events.add,
    );

    ConnectivityMonitor.instance.reportConnectivity(true);

    expect(events, isEmpty);
    subscription.cancel();
  });

  test('stopMonitoring() disables reportConnectivity() again', () {
    ConnectivityMonitor.instance.startMonitoring();
    ConnectivityMonitor.instance.stopMonitoring();

    ConnectivityMonitor.instance.reportConnectivity(false);

    expect(ConnectivityMonitor.instance.isConnected, isTrue);
  });
}
''';
}
