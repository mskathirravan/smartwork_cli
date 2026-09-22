import '../../../models/service_definition.dart';

String remoteConfigServiceSource() {
  return '''class RemoteConfigService {
  RemoteConfigService._();

  static final RemoteConfigService instance = RemoteConfigService._();

  final Map<String, Object> _defaults = {};
  final Map<String, Object> _values = {};

  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  void setDefaults(Map<String, Object> defaults) {
    _defaults.addAll(defaults);
  }

  Future<bool> fetchAndActivate() async {
    _values
      ..clear()
      ..addAll(_defaults);
    return true;
  }

  String getString(String key, {String defaultValue = ''}) {
    final value = _values[key] ?? _defaults[key];
    return value is String ? value : defaultValue;
  }

  bool getBool(String key, {bool defaultValue = false}) {
    final value = _values[key] ?? _defaults[key];
    return value is bool ? value : defaultValue;
  }

  int getInt(String key, {int defaultValue = 0}) {
    final value = _values[key] ?? _defaults[key];
    return value is int ? value : defaultValue;
  }

  double getDouble(String key, {double defaultValue = 0.0}) {
    final value = _values[key] ?? _defaults[key];
    return value is double ? value : defaultValue;
  }
}
''';
}

String remoteConfigServiceTestSource(String projectName) {
  final importPath =
      'package:$projectName/services/${Service.remoteConfig.folderName}/'
      'remote_config_service.dart';
  return '''import 'package:flutter_test/flutter_test.dart';

import '$importPath';

void main() {
  test('instance is a singleton', () {
    final a = RemoteConfigService.instance;
    final b = RemoteConfigService.instance;
    expect(a, same(b));
  });

  test('initialize() is idempotent', () async {
    await RemoteConfigService.instance.initialize();
    await RemoteConfigService.instance.initialize();

    expect(RemoteConfigService.instance.isInitialized, isTrue);
  });

  test('getters return their default when no value was ever fetched', () {
    expect(
      RemoteConfigService.instance.getString('missing', defaultValue: 'x'),
      'x',
    );
    expect(
      RemoteConfigService.instance.getBool('missing', defaultValue: true),
      isTrue,
    );
    expect(RemoteConfigService.instance.getInt('missing', defaultValue: 7), 7);
    expect(
      RemoteConfigService.instance.getDouble('missing', defaultValue: 1.5),
      1.5,
    );
  });

  test('setDefaults() makes its values readable before fetchAndActivate()', () {
    RemoteConfigService.instance.setDefaults({'greeting': 'hello'});

    expect(RemoteConfigService.instance.getString('greeting'), 'hello');
  });

  test(
    'fetchAndActivate() activates the current defaults and returns true',
    () async {
      RemoteConfigService.instance.setDefaults({'enabled': true});

      final activated = await RemoteConfigService.instance.fetchAndActivate();

      expect(activated, isTrue);
      expect(RemoteConfigService.instance.getBool('enabled'), isTrue);
    },
  );

  test('a getter returns the default when the stored value is a different '
      'type', () {
    RemoteConfigService.instance.setDefaults({'count': 'not a number'});

    expect(RemoteConfigService.instance.getInt('count', defaultValue: 3), 3);
  });
}
''';
}
