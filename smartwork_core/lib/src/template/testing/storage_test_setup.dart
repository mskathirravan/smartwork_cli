import '../../models/project_config.dart';

class StorageTestSetup {
  const StorageTestSetup._();

  static String imports(Storage storage) {
    return switch (storage) {
      Storage.sharedPreferences =>
        "import 'package:shared_preferences/shared_preferences.dart';",
      Storage.hive => "\n"
          '''import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';''',
      Storage.other => '',
    };
  }

  static String helperClass(Storage storage) {
    if (storage != Storage.hive) return '';
    return '''
class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;

  _FakePathProviderPlatform(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

''';
  }

  static String setUpAndTearDown(Storage storage) {
    return switch (storage) {
      Storage.sharedPreferences => '''  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.initialize();
  });''',
      Storage.hive => '''  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('storage_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(hiveDir.path);
    await StorageService.instance.initialize();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    hiveDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await StorageService.instance.clear();
  });''',
      Storage.other => '''  setUp(() async {
    await StorageService.instance.clear();
  });''',
    };
  }
}
