import '../../../models/service_definition.dart';

String accessibilityServiceSource() {
  return '''import 'dart:async';

class AccessibilityService {
  AccessibilityService._();

  static final AccessibilityService instance = AccessibilityService._();

  double _textScaleFactor = 1.0;
  bool _screenReaderEnabled = false;
  bool _reduceMotionEnabled = false;
  bool _highContrastEnabled = false;

  final StreamController<void> _controller = StreamController<void>.broadcast();

  bool _initialized = false;

  bool get isInitialized => _initialized;

  double get textScaleFactor => _textScaleFactor;

  bool get isScreenReaderEnabled => _screenReaderEnabled;

  bool get isReduceMotionEnabled => _reduceMotionEnabled;

  bool get isHighContrastEnabled => _highContrastEnabled;

  Stream<void> get onChanged => _controller.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  void reportSettings({
    double? textScaleFactor,
    bool? screenReaderEnabled,
    bool? reduceMotionEnabled,
    bool? highContrastEnabled,
  }) {
    if (textScaleFactor != null) {
      _textScaleFactor = textScaleFactor;
    }
    if (screenReaderEnabled != null) {
      _screenReaderEnabled = screenReaderEnabled;
    }
    if (reduceMotionEnabled != null) {
      _reduceMotionEnabled = reduceMotionEnabled;
    }
    if (highContrastEnabled != null) {
      _highContrastEnabled = highContrastEnabled;
    }
    _controller.add(null);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
''';
}

String accessibilityServiceTestSource(String projectName) {
  final importPath =
      'package:$projectName/services/${Service.accessibility.folderName}/'
      'accessibility_service.dart';
  return '''import 'package:flutter_test/flutter_test.dart';

import '$importPath';

void main() {
  test('instance is a singleton', () {
    final a = AccessibilityService.instance;
    final b = AccessibilityService.instance;
    expect(a, same(b));
  });

  test('textScaleFactor defaults to 1.0, and every flag defaults to false', () {
    expect(AccessibilityService.instance.textScaleFactor, 1.0);
    expect(AccessibilityService.instance.isScreenReaderEnabled, isFalse);
    expect(AccessibilityService.instance.isReduceMotionEnabled, isFalse);
    expect(AccessibilityService.instance.isHighContrastEnabled, isFalse);
  });

  test('initialize() is idempotent', () async {
    await AccessibilityService.instance.initialize();
    await AccessibilityService.instance.initialize();

    expect(AccessibilityService.instance.isInitialized, isTrue);
  });

  test('reportSettings() updates only the fields it is given', () {
    AccessibilityService.instance.reportSettings(
      textScaleFactor: 1.5,
      screenReaderEnabled: true,
    );

    expect(AccessibilityService.instance.textScaleFactor, 1.5);
    expect(AccessibilityService.instance.isScreenReaderEnabled, isTrue);
    expect(AccessibilityService.instance.isReduceMotionEnabled, isFalse);
    expect(AccessibilityService.instance.isHighContrastEnabled, isFalse);

    AccessibilityService.instance.reportSettings(
      textScaleFactor: 1.0,
      screenReaderEnabled: false,
    );
  });

  test('reportSettings() emits on onChanged', () async {
    final events = <void>[];
    final subscription = AccessibilityService.instance.onChanged.listen(
      events.add,
    );

    AccessibilityService.instance.reportSettings(reduceMotionEnabled: true);
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));

    AccessibilityService.instance.reportSettings(reduceMotionEnabled: false);
    await subscription.cancel();
  });
}
''';
}
