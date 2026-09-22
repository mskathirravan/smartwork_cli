import '../../models/project_config.dart';
import '../../models/service_definition.dart';
import '../template.dart';
import '../testing/storage_test_setup.dart';

class BootstrapTemplates {
  static Template bootstrapTemplate(List<Service> services) {
    final initializedServices = services.where((s) => s.hasInitialize);
    final storageThemeImport = initializedServices.isEmpty
        ? "import '../storage/storage_service.dart';\n"
            "import '../theme/theme_service.dart';\n"
        : "import '../services.dart';\n";
    final serviceCalls = initializedServices.isEmpty
        ? '    // Future capabilities — Analytics, Notifications, ... — '
            'register\n    // their own initialization here as those '
            'milestones add them.\n'
        : initializedServices
            .map((s) => '    await ${s.className}.instance.initialize();\n')
            .join();

    return Template(
        content: '''import '../../core/environment/environment_manager.dart';
$storageThemeImport
class Bootstrap {
  Bootstrap._();

  /// Initializes application-level capabilities. Called once from
  /// `main()`, before `runApp()`. Contains no business logic and no
  /// feature-specific initialization — only project-level capabilities
  /// belong here.
  static Future<void> initialize() async {
    await StorageService.instance.initialize();
    await EnvironmentManager.instance.load();
    await ThemeService.instance.load();
$serviceCalls  }
}
''');
  }

  static Template bootstrapTestTemplate(
    Storage storage,
    List<Service> services,
  ) {
    final initializedServices = services.where((s) => s.hasInitialize).toList();
    final bootstrapThemeImport = initializedServices.isEmpty
        ? "import 'package:{{projectName}}/services/bootstrap/bootstrap.dart';\n"
            "import 'package:{{projectName}}/services/storage/storage_service.dart';\n"
            "import 'package:{{projectName}}/services/theme/theme_service.dart';\n"
        : "import 'package:{{projectName}}/services/services.dart';\n";
    final serviceAssertions =
        initializedServices.map(_serviceInitAssertion).join();
    final needsForceUpdate = initializedServices.contains(Service.forceUpdate);
    final packageInfoImport = needsForceUpdate
        ? "import 'package:package_info_plus/package_info_plus.dart';\n"
        : '';
    final packageInfoSetup = needsForceUpdate
        ? '''  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: '{{projectName}}',
      packageName: 'com.example.{{projectName}}',
      version: '1.2.3',
      buildNumber: '1',
      buildSignature: '',
    );
  });

'''
        : '';

    return Template(content: '''import 'package:flutter_test/flutter_test.dart';
$packageInfoImport${StorageTestSetup.imports(storage)}

import 'package:{{projectName}}/core/environment/environment.dart';
import 'package:{{projectName}}/core/environment/environment_manager.dart';
$bootstrapThemeImport
${StorageTestSetup.helperClass(storage)}void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

$packageInfoSetup${StorageTestSetup.setUpAndTearDown(storage)}

  test('Bootstrap.initialize() completes without throwing', () async {
    await Bootstrap.initialize();
  });

  test('Bootstrap.initialize() loads the persisted environment', () async {
    await Bootstrap.initialize();

    expect(EnvironmentManager.instance.currentEnvironment, Environment.prod);
  });

  test('Bootstrap.initialize() loads the persisted theme', () async {
    await Bootstrap.initialize();

    expect(ThemeService.instance.currentThemeMode, isNotNull);
  });
$serviceAssertions}
''');
  }

  static String _serviceInitAssertion(Service service) {
    return switch (service) {
      Service.secureSession => '''
  test('Bootstrap.initialize() initializes SecureSessionManager', () async {
    await Bootstrap.initialize();

    expect(SecureSessionManager.instance.hasSession, isFalse);
  });
''',
      Service.connectivity => '''
  test('Bootstrap.initialize() starts ConnectivityMonitor', () async {
    await Bootstrap.initialize();

    ConnectivityMonitor.instance.reportConnectivity(false);

    expect(ConnectivityMonitor.instance.isConnected, isFalse);
  });
''',
      Service.accessibility => '''
  test('Bootstrap.initialize() initializes AccessibilityService', () async {
    await Bootstrap.initialize();

    expect(AccessibilityService.instance.isInitialized, isTrue);
  });
''',
      Service.logger ||
      Service.deviceInfo ||
      Service.appReview ||
      Service.eventBus =>
        throw StateError(
          '${service.className} has no initialize() — see '
          'ServiceDefinition.hasInitialize',
        ),
      Service.notification => '''
  test('Bootstrap.initialize() initializes NotificationService', () async {
    await Bootstrap.initialize();

    expect(NotificationService.instance.isInitialized, isTrue);
  });
''',
      Service.deeplink => '''
  test('Bootstrap.initialize() initializes DeeplinkService', () async {
    await Bootstrap.initialize();

    expect(DeeplinkService.instance.isInitialized, isTrue);
  });
''',
      Service.analytics => '''
  test('Bootstrap.initialize() initializes AnalyticsService', () async {
    await Bootstrap.initialize();

    expect(AnalyticsService.instance.isInitialized, isTrue);
  });
''',
      Service.crashReporting => '''
  test('Bootstrap.initialize() initializes CrashReportingService', () async {
    await Bootstrap.initialize();

    expect(CrashReportingService.instance.isInitialized, isTrue);
  });
''',
      Service.forceUpdate => '''
  test('Bootstrap.initialize() initializes ForceUpdateService', () async {
    await Bootstrap.initialize();

    expect(ForceUpdateService.instance.currentVersion, isNotEmpty);
  });
''',
      Service.remoteConfig => '''
  test('Bootstrap.initialize() initializes RemoteConfigService', () async {
    await Bootstrap.initialize();

    expect(RemoteConfigService.instance.isInitialized, isTrue);
  });
''',
    };
  }
}
