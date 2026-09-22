import '../../models/project_config.dart';
import '../template.dart';
import '../testing/storage_test_setup.dart';

class StorageServiceTemplates {
  static String serviceSource(Storage storage) {
    return switch (storage) {
      Storage.sharedPreferences => _sharedPreferencesServiceSource(),
      Storage.hive => _hiveServiceSource(),
      Storage.other => _otherServiceSource(),
    };
  }

  static String _sharedPreferencesServiceSource() {
    return '''import 'package:shared_preferences/shared_preferences.dart';

/// Application-level boundary for simple, provider-neutral value
/// storage (get/set/remove/contains/clear over string, bool, int,
/// double, and string-list values) — never a database abstraction.
///
/// Provider-neutral: features, repositories, and data sources call this
/// — never `package:shared_preferences`/`package:hive_flutter`
/// directly. The configured provider (SharedPreferences here) is an
/// implementation detail of this file alone.
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  /// Nothing to set up for SharedPreferences — present for API
  /// symmetry with the Hive-backed implementation, which does need
  /// this. Called once from `Bootstrap.initialize()`.
  Future<void> initialize() async {}

  Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<bool?> getBool(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  Future<void> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<int?> getInt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key);
  }

  Future<void> setInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<double?> getDouble(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(key);
  }

  Future<void> setDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  Future<List<String>?> getStringList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key);
  }

  Future<void> setStringList(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);
  }

  Future<bool> containsKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(key);
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
''';
  }

  static String _hiveServiceSource() {
    return '''import 'package:hive_flutter/hive_flutter.dart';

/// Application-level boundary for simple, provider-neutral value
/// storage (get/set/remove/contains/clear over string, bool, int,
/// double, and string-list values) — never a database abstraction.
///
/// Provider-neutral: features, repositories, and data sources call this
/// — never `package:shared_preferences`/`package:hive_flutter`
/// directly. The configured provider (Hive here) is an implementation
/// detail of this file alone.
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const _boxName = 'smartwork_storage';

  bool _initialized = false;

  /// Sets Hive's storage directory via `Hive.initFlutter()` — required
  /// once before any box can be opened. Called once from
  /// `Bootstrap.initialize()`, before anything else that persists.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await Hive.initFlutter();
  }

  /// Untyped, not `Box<String>`: Hive natively (de)serializes String,
  /// bool, int, double, and `List` values with no adapter needed, so
  /// one box holds every value type this service supports — reading a
  /// key back with the matching typed getter is what keeps that safe.
  Future<Box> _box() => Hive.openBox(_boxName);

  Future<String?> getString(String key) async {
    final box = await _box();
    return box.get(key) as String?;
  }

  Future<void> setString(String key, String value) async {
    final box = await _box();
    await box.put(key, value);
  }

  Future<bool?> getBool(String key) async {
    final box = await _box();
    return box.get(key) as bool?;
  }

  Future<void> setBool(String key, bool value) async {
    final box = await _box();
    await box.put(key, value);
  }

  Future<int?> getInt(String key) async {
    final box = await _box();
    return box.get(key) as int?;
  }

  Future<void> setInt(String key, int value) async {
    final box = await _box();
    await box.put(key, value);
  }

  Future<double?> getDouble(String key) async {
    final box = await _box();
    return box.get(key) as double?;
  }

  Future<void> setDouble(String key, double value) async {
    final box = await _box();
    await box.put(key, value);
  }

  Future<List<String>?> getStringList(String key) async {
    final box = await _box();
    return (box.get(key) as List?)?.cast<String>();
  }

  Future<void> setStringList(String key, List<String> value) async {
    final box = await _box();
    await box.put(key, value);
  }

  Future<bool> containsKey(String key) async {
    final box = await _box();
    return box.containsKey(key);
  }

  Future<void> remove(String key) async {
    final box = await _box();
    await box.delete(key);
  }

  Future<void> clear() async {
    final box = await _box();
    await box.clear();
  }
}
''';
  }

  static String _otherServiceSource() {
    return '''/// Application-level boundary for simple, provider-neutral value
/// storage (get/set/remove/contains/clear over string, bool, int,
/// double, and string-list values) — never a database abstraction.
///
/// Storage is configured as `other` — SmartWork added no persistence
/// package, so this keeps values in memory only: a genuinely working
/// implementation, not a placeholder, but one that does not survive an
/// app restart. Add your own package (e.g. `shared_preferences`,
/// `hive_flutter`, or another of your choice) and replace the body of
/// each method below with it — every feature already calls this one
/// class, so nothing else needs to change once you do.
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  final Map<String, Object> _memory = {};

  /// Nothing to set up for the in-memory store — present for API
  /// symmetry with the SharedPreferences/Hive-backed implementations.
  /// Called once from `Bootstrap.initialize()`.
  Future<void> initialize() async {}

  Future<String?> getString(String key) async => _memory[key] as String?;

  Future<void> setString(String key, String value) async {
    _memory[key] = value;
  }

  Future<bool?> getBool(String key) async => _memory[key] as bool?;

  Future<void> setBool(String key, bool value) async {
    _memory[key] = value;
  }

  Future<int?> getInt(String key) async => _memory[key] as int?;

  Future<void> setInt(String key, int value) async {
    _memory[key] = value;
  }

  Future<double?> getDouble(String key) async => _memory[key] as double?;

  Future<void> setDouble(String key, double value) async {
    _memory[key] = value;
  }

  Future<List<String>?> getStringList(String key) async =>
      (_memory[key] as List?)?.cast<String>();

  Future<void> setStringList(String key, List<String> value) async {
    _memory[key] = value;
  }

  Future<bool> containsKey(String key) async => _memory.containsKey(key);

  Future<void> remove(String key) async {
    _memory.remove(key);
  }

  Future<void> clear() async {
    _memory.clear();
  }
}
''';
  }

  static Template testTemplate(Storage storage) {
    return Template(content: '''import 'package:flutter_test/flutter_test.dart';
${StorageTestSetup.imports(storage)}

import 'package:{{projectName}}/services/storage/storage_service.dart';

${StorageTestSetup.helperClass(storage)}void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

${StorageTestSetup.setUpAndTearDown(storage)}

  test('initialize() is idempotent', () async {
    await StorageService.instance.initialize();
    await StorageService.instance.initialize();
  });

  test('getString() returns null for a key that was never set', () async {
    expect(await StorageService.instance.getString('missing'), isNull);
  });

  test('setString()/getString() round-trip a value', () async {
    await StorageService.instance.setString('greeting', 'hello');

    expect(await StorageService.instance.getString('greeting'), 'hello');
  });

  test('setBool()/getBool() round-trip a value', () async {
    expect(await StorageService.instance.getBool('flag'), isNull);

    await StorageService.instance.setBool('flag', true);

    expect(await StorageService.instance.getBool('flag'), isTrue);
  });

  test('setInt()/getInt() round-trip a value', () async {
    expect(await StorageService.instance.getInt('count'), isNull);

    await StorageService.instance.setInt('count', 42);

    expect(await StorageService.instance.getInt('count'), 42);
  });

  test('setDouble()/getDouble() round-trip a value', () async {
    expect(await StorageService.instance.getDouble('ratio'), isNull);

    await StorageService.instance.setDouble('ratio', 3.14);

    expect(await StorageService.instance.getDouble('ratio'), 3.14);
  });

  test('setStringList()/getStringList() round-trip a value', () async {
    expect(await StorageService.instance.getStringList('tags'), isNull);

    await StorageService.instance.setStringList('tags', ['a', 'b', 'c']);

    expect(await StorageService.instance.getStringList('tags'), [
      'a',
      'b',
      'c',
    ]);
  });

  test('containsKey() reflects whether a value was set', () async {
    expect(await StorageService.instance.containsKey('flag'), isFalse);

    await StorageService.instance.setString('flag', 'on');

    expect(await StorageService.instance.containsKey('flag'), isTrue);
  });

  test('remove() deletes a single key', () async {
    await StorageService.instance.setString('a', '1');
    await StorageService.instance.setString('b', '2');

    await StorageService.instance.remove('a');

    expect(await StorageService.instance.containsKey('a'), isFalse);
    expect(await StorageService.instance.getString('b'), '2');
  });

  test('clear() removes every key, regardless of value type', () async {
    await StorageService.instance.setString('a', '1');
    await StorageService.instance.setBool('b', true);
    await StorageService.instance.setInt('c', 1);

    await StorageService.instance.clear();

    expect(await StorageService.instance.containsKey('a'), isFalse);
    expect(await StorageService.instance.containsKey('b'), isFalse);
    expect(await StorageService.instance.containsKey('c'), isFalse);
  });
}
''');
  }
}
