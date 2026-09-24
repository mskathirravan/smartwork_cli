import '../../models/project_config.dart';
import '../template.dart';
import '../testing/storage_test_setup.dart';

class EnvironmentTemplates {
  static Template environmentTemplate() {
    return Template(content: '''enum Environment { prod, stage, dev }

extension EnvironmentLabel on Environment {
  String get label {
    switch (this) {
      case Environment.prod:
        return 'PROD';
      case Environment.stage:
        return 'STAGE';
      case Environment.dev:
        return 'DEV';
    }
  }
}
''');
  }

  static Template environmentUrlsTemplate() {
    return Template(content: '''import '../constants/constants.dart';
import 'environment.dart';

class EnvironmentUrls {
  const EnvironmentUrls._();

  static String forEnvironment(Environment environment) {
    switch (environment) {
      case Environment.prod:
        return ApiConstants.prodUrl;
      case Environment.stage:
        return ApiConstants.stageUrl;
      case Environment.dev:
        return ApiConstants.devUrl;
    }
  }
}
''');
  }

  static Template environmentManagerTemplate() {
    return Template(content: '''import 'package:flutter/foundation.dart';

import '../../services/storage/storage_service.dart';
import '../constants/constants.dart';
import 'environment.dart';
import 'environment_urls.dart';

/// A `ChangeNotifier` because `main.dart`'s root widget shows an
/// environment banner (hidden only in `Environment.prod`) that must
/// visually update the instant the Debug screen applies a new
/// environment, with no app restart.
class EnvironmentManager extends ChangeNotifier {
  EnvironmentManager._();

  static final EnvironmentManager instance = EnvironmentManager._();

  Environment _current = Environment.prod;

  Environment get currentEnvironment => _current;

  String get currentBaseUrl => EnvironmentUrls.forEnvironment(_current);

  /// Loads the persisted environment, if any. Called once from
  /// `Bootstrap.initialize()`, before `runApp()`.
  Future<void> load() async {
    final stored = await StorageService.instance.getString(
      StorageConstants.environmentKey,
    );
    if (stored != null) {
      _current = Environment.values.firstWhere(
        (environment) => environment.name == stored,
        orElse: () => Environment.prod,
      );
    }
  }

  /// Switches the active environment and persists only its identifier
  /// (e.g. `'stage'`), never a URL. The next Network request reads
  /// [currentBaseUrl] fresh, so no restart is required.
  Future<void> setEnvironment(Environment environment) async {
    _current = environment;
    await StorageService.instance.setString(
      StorageConstants.environmentKey,
      environment.name,
    );
    notifyListeners();
  }
}
''');
  }

  static Template environmentTestTemplate(Storage storage) {
    return Template(content: '''import 'package:flutter_test/flutter_test.dart';
${StorageTestSetup.imports(storage)}

import 'package:{{projectName}}/core/constants/constants.dart';
import 'package:{{projectName}}/core/environment/environment.dart';
import 'package:{{projectName}}/core/environment/environment_manager.dart';
import 'package:{{projectName}}/core/environment/environment_urls.dart';
import 'package:{{projectName}}/services/storage/storage_service.dart';

${StorageTestSetup.helperClass(storage)}void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

${StorageTestSetup.setUpAndTearDown(storage)}

  tearDown(() async {
    await EnvironmentManager.instance.setEnvironment(Environment.prod);
  });

  test('defaults to Production', () {
    expect(EnvironmentManager.instance.currentEnvironment, Environment.prod);
  });

  test('EnvironmentUrls maps every Environment to its ApiConstants URL', () {
    expect(
      EnvironmentUrls.forEnvironment(Environment.prod),
      ApiConstants.prodUrl,
    );
    expect(
      EnvironmentUrls.forEnvironment(Environment.stage),
      ApiConstants.stageUrl,
    );
    expect(
      EnvironmentUrls.forEnvironment(Environment.dev),
      ApiConstants.devUrl,
    );
  });

  test('currentBaseUrl reflects the current environment', () async {
    await EnvironmentManager.instance.setEnvironment(Environment.stage);

    expect(EnvironmentManager.instance.currentBaseUrl, ApiConstants.stageUrl);
  });

  test('setEnvironment switches the current environment', () async {
    await EnvironmentManager.instance.setEnvironment(Environment.dev);

    expect(EnvironmentManager.instance.currentEnvironment, Environment.dev);
  });

  test(
    'setEnvironment notifies listeners so the app can rebuild live',
    () async {
      var notifications = 0;
      EnvironmentManager.instance.addListener(() => notifications++);

      await EnvironmentManager.instance.setEnvironment(Environment.stage);

      expect(notifications, greaterThan(0));
    },
  );

  test('setEnvironment persists the identifier, never a URL, through '
      'StorageService', () async {
    await EnvironmentManager.instance.setEnvironment(Environment.stage);

    expect(
      await StorageService.instance.getString(StorageConstants.environmentKey),
      'stage',
    );
  });

  test('load() reads a persisted environment identifier', () async {
    await StorageService.instance.setString(
      StorageConstants.environmentKey,
      'stage',
    );

    await EnvironmentManager.instance.load();

    expect(EnvironmentManager.instance.currentEnvironment, Environment.stage);
  });

  test('load() falls back to Production when nothing is persisted', () async {
    await EnvironmentManager.instance.load();

    expect(EnvironmentManager.instance.currentEnvironment, Environment.prod);
  });
}
''');
  }
}
