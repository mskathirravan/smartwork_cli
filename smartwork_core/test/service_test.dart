import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// Production Services: one authoritative [Service] definition
/// (identifier, display name, category, generated filename/class name),
/// [ServiceSelection] parsing (multi-select, empty-allowed, duplicate-
/// normalizing), [ServiceChanges] (added/removed/unchanged), real
/// generation (`ServiceGenerator`), and `ProjectConfig.services`
/// persistence.
void main() {
  group('Service', () {
    test('has exactly the thirteen expected values, in menu/display order', () {
      expect(Service.values, [
        Service.secureSession,
        Service.connectivity,
        Service.deviceInfo,
        Service.accessibility,
        Service.logger,
        Service.crashReporting,
        Service.notification,
        Service.deeplink,
        Service.analytics,
        Service.forceUpdate,
        Service.appReview,
        Service.eventBus,
        Service.remoteConfig,
      ]);
    });

    test('id matches the stable configuration identifier for each service', () {
      expect(Service.secureSession.id, 'secureSession');
      expect(Service.connectivity.id, 'connectivity');
      expect(Service.deviceInfo.id, 'deviceInfo');
      expect(Service.accessibility.id, 'accessibility');
      expect(Service.logger.id, 'logger');
      expect(Service.crashReporting.id, 'crashReporting');
      expect(Service.notification.id, 'notification');
      expect(Service.deeplink.id, 'deeplink');
      expect(Service.analytics.id, 'analytics');
      expect(Service.forceUpdate.id, 'forceUpdate');
      expect(Service.appReview.id, 'appReview');
      expect(Service.eventBus.id, 'eventBus');
      expect(Service.remoteConfig.id, 'remoteConfig');
    });

    test('displayName is human-readable for each service', () {
      expect(Service.secureSession.displayName, 'Secure Session');
      expect(Service.connectivity.displayName, 'Connectivity Monitor');
      expect(Service.deviceInfo.displayName, 'Device Info');
      expect(Service.accessibility.displayName, 'Accessibility');
      expect(Service.logger.displayName, 'Debug Logger');
      expect(Service.crashReporting.displayName, 'Crash Reporting');
      expect(Service.notification.displayName, 'Notifications');
      expect(Service.deeplink.displayName, 'Deep Linking');
      expect(Service.analytics.displayName, 'Analytics');
      expect(Service.forceUpdate.displayName, 'Force Update');
      expect(Service.appReview.displayName, 'App Review');
      expect(Service.eventBus.displayName, 'Event Bus');
      expect(Service.remoteConfig.displayName, 'Remote Config');
    });

    test('category groups services as the CLI prompt requires', () {
      expect(Service.secureSession.category, ServiceCategory.security);
      expect(Service.connectivity.category, ServiceCategory.deviceRuntime);
      expect(Service.deviceInfo.category, ServiceCategory.deviceRuntime);
      expect(Service.accessibility.category, ServiceCategory.deviceRuntime);
      expect(Service.logger.category, ServiceCategory.diagnostics);
      expect(Service.crashReporting.category, ServiceCategory.diagnostics);
      expect(Service.notification.category,
          ServiceCategory.applicationIntegration);
      expect(Service.deeplink.category, ServiceCategory.applicationIntegration);
      expect(
          Service.analytics.category, ServiceCategory.applicationIntegration);
      expect(
          Service.forceUpdate.category, ServiceCategory.applicationIntegration);
      expect(
          Service.appReview.category, ServiceCategory.applicationIntegration);
      expect(Service.eventBus.category, ServiceCategory.applicationIntegration);
      expect(Service.remoteConfig.category,
          ServiceCategory.applicationIntegration);
    });

    test('ServiceCategory.displayName matches the required section labels', () {
      expect(ServiceCategory.security.displayName, 'Security');
      expect(ServiceCategory.deviceRuntime.displayName, 'Device / Runtime');
      expect(ServiceCategory.diagnostics.displayName, 'Diagnostics');
      expect(ServiceCategory.applicationIntegration.displayName,
          'Application Integration');
    });

    test('fileName matches the exact required lib/services/ layout', () {
      expect(Service.secureSession.fileName, 'secure_session_manager.dart');
      expect(Service.connectivity.fileName, 'connectivity_monitor.dart');
      expect(Service.deviceInfo.fileName, 'device_info_service.dart');
      expect(Service.accessibility.fileName, 'accessibility_service.dart');
      expect(Service.logger.fileName, 'debug_logger.dart');
      expect(Service.crashReporting.fileName, 'crash_reporting_service.dart');
      expect(Service.notification.fileName, 'notification_service.dart');
      expect(Service.deeplink.fileName, 'deeplink_service.dart');
      expect(Service.analytics.fileName, 'analytics_service.dart');
      expect(Service.forceUpdate.fileName, 'force_update_service.dart');
      expect(Service.appReview.fileName, 'app_review_service.dart');
      expect(Service.eventBus.fileName, 'event_bus_service.dart');
      expect(Service.remoteConfig.fileName, 'remote_config_service.dart');
    });

    test('className matches the exact required generated class names', () {
      expect(Service.secureSession.className, 'SecureSessionManager');
      expect(Service.connectivity.className, 'ConnectivityMonitor');
      expect(Service.deviceInfo.className, 'DeviceInfoService');
      expect(Service.accessibility.className, 'AccessibilityService');
      expect(Service.logger.className, 'DebugLogger');
      expect(Service.crashReporting.className, 'CrashReportingService');
      expect(Service.notification.className, 'NotificationService');
      expect(Service.deeplink.className, 'DeeplinkService');
      expect(Service.analytics.className, 'AnalyticsService');
      expect(Service.forceUpdate.className, 'ForceUpdateService');
      expect(Service.appReview.className, 'AppReviewService');
      expect(Service.eventBus.className, 'EventBusService');
      expect(Service.remoteConfig.className, 'RemoteConfigService');
    });

    test(
        'hasInitialize is false only for the four stateless/self-'
        'contained services', () {
      expect(Service.secureSession.hasInitialize, isTrue);
      expect(Service.connectivity.hasInitialize, isTrue);
      expect(Service.deviceInfo.hasInitialize, isFalse);
      expect(Service.accessibility.hasInitialize, isTrue);
      expect(Service.logger.hasInitialize, isFalse);
      expect(Service.crashReporting.hasInitialize, isTrue);
      expect(Service.notification.hasInitialize, isTrue);
      expect(Service.deeplink.hasInitialize, isTrue);
      expect(Service.analytics.hasInitialize, isTrue);
      expect(Service.forceUpdate.hasInitialize, isTrue);
      expect(Service.appReview.hasInitialize, isFalse);
      expect(Service.eventBus.hasInitialize, isFalse);
      expect(Service.remoteConfig.hasInitialize, isTrue);
    });

    test('every purpose description is non-empty and provider-neutral', () {
      for (final service in Service.values) {
        expect(service.purpose, isNotEmpty);
        for (final provider in [
          'Firebase',
          'Sentry',
          'OneSignal',
          'Branch',
          'Amplitude',
          'Mixpanel',
        ]) {
          expect(service.purpose, isNot(contains(provider)));
        }
      }
    });
  });

  group('ProjectConfig.services', () {
    ProjectConfig baseConfig({Set<String>? services}) {
      return ProjectConfig(
        projectName: 'demo_app',
        services: services,
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );
    }

    test('is empty by default', () {
      expect(baseConfig().services, isEmpty);
    });

    test('accepts a single service', () {
      final config = baseConfig(services: {Service.analytics.id});
      expect(config.services, {'analytics'});
    });

    test('accepts multiple services', () {
      final config = baseConfig(
        services: {Service.secureSession.id, Service.analytics.id},
      );
      expect(config.services, {'secureSession', 'analytics'});
    });

    test('accepts all thirteen services', () {
      final config =
          baseConfig(services: Service.values.map((s) => s.id).toSet());
      expect(config.orderedServices, Service.values);
    });

    test(
        'orderedServices is always in Service.values declaration order, '
        'regardless of selection order', () {
      final config = baseConfig(services: {
        Service.analytics.id,
        Service.secureSession.id,
        Service.logger.id,
      });

      expect(config.orderedServices,
          [Service.secureSession, Service.logger, Service.analytics]);
    });

    test(
        'orderedServices silently excludes an unknown id (validation, '
        'not this getter, reports it)', () {
      final config = baseConfig(services: {'notARealService'});
      expect(config.orderedServices, isEmpty);
    });

    test(
        'toYaml serializes services as a deterministically ordered list '
        'of plain ids', () {
      final yaml = baseConfig(services: {
        Service.analytics.id,
        Service.secureSession.id,
      }).toYaml();

      expect(yaml['services'], ['secureSession', 'analytics']);
    });

    test('toYaml serializes an empty selection as an empty list', () {
      final yaml = baseConfig().toYaml();
      expect(yaml['services'], isEmpty);
    });

    test('round-trips every single service through toYaml/fromYaml', () {
      for (final service in Service.values) {
        final config = baseConfig(services: {service.id});
        final restored = ProjectConfig.fromYaml(config.toYaml());
        expect(restored.services, {service.id});
      }
    });

    test('round-trips a multi-service selection through toYaml/fromYaml', () {
      final config = baseConfig(
        services: {Service.connectivity.id, Service.logger.id},
      );
      final restored = ProjectConfig.fromYaml(config.toYaml());
      expect(restored.services, {'connectivity', 'logger'});
    });

    test(
        'fromYaml defaults to no services when the key is absent — no '
        'invented selection', () {
      final yaml = baseConfig(services: {Service.analytics.id}).toYaml()
        ..remove('services');
      final restored = ProjectConfig.fromYaml(yaml);
      expect(restored.services, isEmpty);
    });
  });

  group('ConfigValidator: services', () {
    ProjectConfig configWith(Set<String> services) {
      return ProjectConfig(
        projectName: 'demo_app',
        services: services,
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );
    }

    test('accepts an empty service selection (services are optional)', () {
      final errors = ConfigValidator.validate(configWith({}));
      expect(
        errors.map((e) => e.toString()),
        isNot(contains(contains('service'))),
      );
    });

    test('accepts every known service', () {
      final errors = ConfigValidator.validate(
        configWith(Service.values.map((s) => s.id).toSet()),
      );
      expect(errors, isEmpty);
    });

    test('rejects an unknown service id', () {
      final errors = ConfigValidator.validate(configWith({'notAService'}));
      expect(errors, isNotEmpty);
      expect(
          errors.map((e) => e.toString()), contains(contains('notAService')));
    });
  });

  group('ServiceSelection.parse', () {
    test('empty input means no services — never an error', () {
      expect(ServiceSelection.parse(''), isEmpty);
      expect(ServiceSelection.parse('   '), isEmpty);
    });

    test('parses a single selection', () {
      expect(ServiceSelection.parse('1'), {Service.secureSession});
    });

    test('parses multiple selections', () {
      expect(
        ServiceSelection.parse('1,2,5,9'),
        {
          Service.secureSession,
          Service.connectivity,
          Service.logger,
          Service.analytics,
        },
      );
    });

    test('parses all thirteen selections', () {
      expect(ServiceSelection.parse('1,2,3,4,5,6,7,8,9,10,11,12,13'),
          unorderedEquals(Service.values));
    });

    test("'all' selects every service without listing indices", () {
      expect(ServiceSelection.parse('all'), Service.values.toSet());
    });

    test("'all' is case-insensitive and tolerates surrounding whitespace", () {
      expect(ServiceSelection.parse('ALL'), Service.values.toSet());
      expect(ServiceSelection.parse('  All  '), Service.values.toSet());
    });

    test('tolerates surrounding whitespace around tokens', () {
      expect(
        ServiceSelection.parse('1,  2,   5,9'),
        {
          Service.secureSession,
          Service.connectivity,
          Service.logger,
          Service.analytics,
        },
      );
    });

    test('normalizes a duplicate selection rather than rejecting it', () {
      expect(
        ServiceSelection.parse('1,1,2,2,5'),
        {Service.secureSession, Service.connectivity, Service.logger},
      );
    });

    test('rejects an invalid index', () {
      expect(
        () => ServiceSelection.parse('1,2,99'),
        throwsA(isA<InvalidServiceSelectionException>()),
      );
    });

    test('rejects a non-numeric token', () {
      expect(
        () => ServiceSelection.parse('1,x'),
        throwsA(isA<InvalidServiceSelectionException>()),
      );
    });

    test('rejects mixed valid/invalid values, naming the invalid one', () {
      try {
        ServiceSelection.parse('1,2,99');
        fail('expected an exception');
      } on InvalidServiceSelectionException catch (e) {
        expect(e.toString(), contains('99'));
      }
    });

    test('exception messages are printable, non-empty strings', () {
      try {
        ServiceSelection.parse('0');
        fail('expected an exception');
      } on InvalidServiceSelectionException catch (e) {
        expect(e.toString(), isNotEmpty);
      }
    });
  });

  group('ServiceChanges.compute', () {
    test('added is everything in desired but not current', () {
      final changes = ServiceChanges.compute(
        current: {'secureSession', 'connectivity'},
        desired: {'secureSession', 'connectivity', 'analytics'},
      );

      expect(changes.added, {'analytics'});
      expect(changes.removed, isEmpty);
      expect(changes.unchanged, {'secureSession', 'connectivity'});
      expect(changes.hasChanges, isTrue);
    });

    test('removed is everything in current but not desired', () {
      final changes = ServiceChanges.compute(
        current: {'secureSession', 'connectivity', 'analytics'},
        desired: {'secureSession', 'logger'},
      );

      expect(changes.added, {'logger'});
      expect(changes.removed, {'connectivity', 'analytics'});
      expect(changes.unchanged, {'secureSession'});
    });

    test('add + remove simultaneously', () {
      final changes = ServiceChanges.compute(
        current: {'secureSession', 'connectivity', 'analytics'},
        desired: {'connectivity', 'logger', 'crashReporting'},
      );

      expect(changes.added, {'logger', 'crashReporting'});
      expect(changes.removed, {'secureSession', 'analytics'});
      expect(changes.unchanged, {'connectivity'});
    });

    test('an identical selection has no changes', () {
      final changes = ServiceChanges.compute(
        current: {'secureSession', 'connectivity'},
        desired: {'connectivity', 'secureSession'},
      );

      expect(changes.added, isEmpty);
      expect(changes.removed, isEmpty);
      expect(changes.hasChanges, isFalse);
    });

    test('removing all services', () {
      final changes = ServiceChanges.compute(
        current: {'secureSession', 'connectivity', 'logger', 'analytics'},
        desired: {},
      );

      expect(changes.added, isEmpty);
      expect(changes.removed,
          {'secureSession', 'connectivity', 'logger', 'analytics'});
      expect(changes.orderedDesired, isEmpty);
    });

    test('adding all services from none', () {
      final changes = ServiceChanges.compute(
        current: {},
        desired: Service.values.map((s) => s.id).toSet(),
      );

      expect(changes.orderedAdded, Service.values);
      expect(changes.removed, isEmpty);
    });

    test('ordered getters follow Service.values declaration order', () {
      final changes = ServiceChanges.compute(
        current: {'analytics', 'secureSession'},
        desired: {'logger', 'connectivity'},
      );

      expect(
          changes.orderedCurrent, [Service.secureSession, Service.analytics]);
      expect(changes.orderedDesired, [Service.connectivity, Service.logger]);
      expect(changes.orderedAdded, [Service.connectivity, Service.logger]);
      expect(
          changes.orderedRemoved, [Service.secureSession, Service.analytics]);
    });
  });

  group('ServiceGenerator', () {
    late Directory tempDir;
    late ProjectPaths paths;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_service_gen_');
      paths = ProjectPaths(projectRoot: tempDir.path);
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'always writes the core project-level services — bootstrap, '
        'network, storage, theme, plus the barrel — even when no '
        'optional services are selected, and no optional service folder '
        'at all', () async {
      await ServiceGenerator().generate(
        services: {},
        projectName: 'demo_app',
        paths: paths,
        fileWriter: FileWriter(),
        network: Network.http,
        storage: Storage.sharedPreferences,
      );

      expect(File(paths.servicesBootstrapFile).existsSync(), isTrue);
      expect(File(paths.servicesNetworkServiceFile).existsSync(), isTrue);
      expect(File(paths.servicesStorageServiceFile).existsSync(), isTrue);
      expect(File(paths.servicesThemeServiceFile).existsSync(), isTrue);
      expect(File(paths.servicesBarrelFile).existsSync(), isTrue);

      final topLevel = Directory(paths.services)
          .listSync()
          .map((e) => e.path.split('/').last)
          .toSet();
      expect(topLevel,
          {'bootstrap', 'network', 'storage', 'theme', 'services.dart'});
    });

    test(
        'writes exactly the selected optional service folders, never an '
        'unselected one', () async {
      await ServiceGenerator().generate(
        services: {Service.secureSession.id, Service.analytics.id},
        projectName: 'demo_app',
        paths: paths,
        fileWriter: FileWriter(),
        network: Network.http,
        storage: Storage.sharedPreferences,
      );

      expect(
        File(paths.serviceFolderFile(Service.secureSession.folderName,
                Service.secureSession.fileName))
            .existsSync(),
        isTrue,
      );
      expect(
        File(paths.serviceFolderFile(
                Service.analytics.folderName, Service.analytics.fileName))
            .existsSync(),
        isTrue,
      );
      expect(
        Directory('${paths.services}/${Service.connectivity.folderName}')
            .existsSync(),
        isFalse,
        reason: 'connectivity was never selected',
      );
    });

    test(
        'generated file contains the expected class and is '
        'provider-neutral', () async {
      await ServiceGenerator().generate(
        services: {Service.crashReporting.id},
        projectName: 'demo_app',
        paths: paths,
        fileWriter: FileWriter(),
        network: Network.http,
        storage: Storage.sharedPreferences,
      );

      final content = File(paths.serviceFolderFile(
              Service.crashReporting.folderName,
              Service.crashReporting.fileName))
          .readAsStringSync();

      expect(content, contains('class CrashReportingService'));
      expect(content, contains('static final CrashReportingService instance'));
      expect(content, contains('Future<void> initialize()'));
      expect(content, isNot(contains('Firebase')));
      expect(content, isNot(contains('Sentry')));
    });

    test(
        'every generated source and test line stays within the 80-column '
        'limit dart format enforces, even for the longest service names '
        '(regression: SecureSessionManager\'s singleton-identity '
        'assertion once overflowed 80 columns)', () async {
      await ServiceGenerator().generate(
        services: Service.values.map((s) => s.id).toSet(),
        projectName: 'demo_app',
        paths: paths,
        fileWriter: FileWriter(),
        network: Network.http,
        storage: Storage.sharedPreferences,
      );
      await ServiceGenerator().generateTests(
        services: Service.values.map((s) => s.id).toSet(),
        projectName: 'demo_app',
        paths: paths,
        fileWriter: FileWriter(),
        network: Network.http,
        storage: Storage.sharedPreferences,
      );

      final allFiles = [
        ...Directory(paths.services)
            .listSync(recursive: true)
            .whereType<File>(),
        ...Directory(paths.testServices)
            .listSync(recursive: true)
            .whereType<File>(),
      ];

      for (final file in allFiles) {
        final lines = file.readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          expect(lines[i].length, lessThanOrEqualTo(80),
              reason: '${file.path} line ${i + 1} exceeds 80 columns: '
                  '"${lines[i]}"');
        }
      }
    });

    test(
        'every generated source and test is byte-for-byte what real '
        '`dart format` would produce — never merely ≤80 columns '
        '(regression: AccessibilityService\'s StreamController field and '
        'a test\'s onChanged subscription both sat at exactly 80 columns '
        'unwrapped, which dart format accepts as-is, while the template '
        'had pre-wrapped them onto a second line — a form dart format '
        'collapses back down, so `smartwork doctor`\'s Format check '
        'would have failed on every real generated project). Formatted '
        'with no pubspec.yaml in scope, matching real `flutter create` '
        'output (sdk: ^3.13.0 on this machine — always well above dart '
        'format\'s style-switching threshold, same as no package context '
        'at all); PubspecGenerator\'s own `sdk: ^3.0.0` fallback is dead '
        'code for the real init flow (flutter create always writes a '
        'pubspec.yaml first, so PubspecGenerator.generate()\'s fresh-'
        'pubspec path — the only place that fallback is used — never '
        'runs there), so it must never be used to decide what a real '
        'generated project would format like', () async {
      await ServiceGenerator().generate(
        services: Service.values.map((s) => s.id).toSet(),
        projectName: 'demo_app',
        paths: paths,
        fileWriter: FileWriter(),
        network: Network.http,
        storage: Storage.sharedPreferences,
      );
      await ServiceGenerator().generateTests(
        services: Service.values.map((s) => s.id).toSet(),
        projectName: 'demo_app',
        paths: paths,
        fileWriter: FileWriter(),
        network: Network.http,
        storage: Storage.sharedPreferences,
      );

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['format', '--set-exit-if-changed', paths.services, paths.testServices],
      );

      expect(result.exitCode, 0,
          reason: 'dart format would reformat at least one generated '
              'file:\n${result.stdout}');
    });

    test(
        'SecureSessionManager\'s generated test never leaves a double '
        'blank line when Storage.other contributes no StorageTestSetup '
        'imports/priming (regression: V1.1 Core Final Audit — '
        'serviceTestSource bypassed TemplateEngine\'s blank-line '
        'normalization, the only one of the eight services whose test '
        'conditionally includes storage-specific setup, so only '
        'Storage.other ever triggered dart format --set-exit-if-changed '
        'to fail on it)', () {
      final source = ServiceTemplates.serviceTestSource(
        Service.secureSession,
        'demo_app',
        storage: Storage.other,
      );

      expect(source, isNot(contains('\n\n\n')));
    });

    test(
        'SecureSessionManager\'s generated test still collapses no real '
        'content for SharedPreferences/Hive, which do contribute '
        'StorageTestSetup imports/priming', () {
      for (final storage in [Storage.sharedPreferences, Storage.hive]) {
        final source = ServiceTemplates.serviceTestSource(
          Service.secureSession,
          'demo_app',
          storage: storage,
        );

        expect(source, isNot(contains('\n\n\n')));
        expect(source, contains('StorageService'));
      }
    });

    test(
        'the barrel exports the always-present core services first, then '
        'only the selected optional services, in declaration order', () async {
      await ServiceGenerator().generate(
        services: {Service.analytics.id, Service.secureSession.id},
        projectName: 'demo_app',
        paths: paths,
        fileWriter: FileWriter(),
        network: Network.http,
        storage: Storage.sharedPreferences,
      );

      final barrel = File(paths.servicesBarrelFile).readAsStringSync();
      final lines =
          barrel.split('\n').where((l) => l.trim().isNotEmpty).toList();

      expect(lines, [
        "export 'bootstrap/bootstrap.dart';",
        "export 'network/network_service.dart';",
        "export 'routing/app_router.dart';",
        "export 'storage/storage_service.dart';",
        "export 'theme/theme_service.dart';",
        "export 'secure_session/secure_session_manager.dart';",
        "export 'analytics/analytics_service.dart';",
      ]);
    });

    test(
        'generateTests always writes the core services\' own tests, plus '
        'one test file per selected optional service', () async {
      await ServiceGenerator().generateTests(
        services: {Service.logger.id},
        projectName: 'demo_app',
        paths: paths,
        fileWriter: FileWriter(),
        network: Network.http,
        storage: Storage.sharedPreferences,
      );

      expect(File(paths.testServicesBootstrapFile).existsSync(), isTrue);
      expect(
        File(paths.testServiceFolderFile(
                Service.logger.folderName, 'debug_logger_test.dart'))
            .existsSync(),
        isTrue,
      );
      expect(
        Directory('${paths.testServices}/${Service.deviceInfo.folderName}')
            .existsSync(),
        isFalse,
        reason: 'deviceInfo was never selected',
      );
    });

    test(
        'every selected service\'s own generated test imports the real '
        'package:<projectName>/services/<folderName>/<fileName> path '
        'its own service source is written to — regression: several '
        'services\' generated test once imported a flat, non-existent '
        'services/<fileName> path with no folder segment at all', () async {
      final allServices = Service.values.map((s) => s.id).toSet();
      await ServiceGenerator().generate(
        services: allServices,
        projectName: 'demo_app',
        paths: paths,
        fileWriter: FileWriter(),
        network: Network.http,
        storage: Storage.sharedPreferences,
      );
      await ServiceGenerator().generateTests(
        services: allServices,
        projectName: 'demo_app',
        paths: paths,
        fileWriter: FileWriter(),
        network: Network.http,
        storage: Storage.sharedPreferences,
      );

      for (final service in Service.values) {
        final testFileName =
            '${service.fileName.replaceAll('.dart', '')}_test.dart';
        final testContent =
            File(paths.testServiceFolderFile(service.folderName, testFileName))
                .readAsStringSync();
        final expectedImport =
            "import 'package:demo_app/services/${service.folderName}/"
            "${service.fileName}';";
        expect(
          testContent,
          contains(expectedImport),
          reason: '${service.className}\'s own generated test must import '
              'its real generated source file',
        );
      }
    });
  });

  group('EventBusService (V1.1-4)', () {
    // Core never executes the generated Dart source directly (it is
    // embedded as a template string) — the same "content-only" testing
    // convention V1.1-3 established for ForceUpdateService/
    // AppReviewService. Real subscribe/publish/unsubscribe *behavior*
    // is validated for real by the generated test file itself, which
    // genuinely executes under `flutter test` in a real generated
    // project (see the Real Flutter E2E validation for this milestone).
    late String source;
    late String testSource;

    setUpAll(() {
      source = ServiceTemplates.serviceSource(Service.eventBus);
      testSource = ServiceTemplates.serviceTestSource(
        Service.eventBus,
        'demo_app',
        storage: Storage.sharedPreferences,
      );
    });

    test('generated source declares the expected class and singleton', () {
      expect(source, contains('class EventBusService'));
      expect(source, contains('EventBusService._();'));
      expect(source, contains('static final EventBusService instance'));
    });

    test(
        'generated source declares the typed subscribe/unsubscribe/'
        'publish API', () {
      expect(
          source,
          contains('void subscribe<T>(void Function(T event) '
              'handler)'));
      expect(
          source,
          contains('void unsubscribe<T>(void Function(T event) '
              'handler)'));
      expect(source, contains('void publish<T>(T event)'));
    });

    test(
        'has no initialize() — matches ServiceDefinition.hasInitialize '
        'being false', () {
      expect(Service.eventBus.hasInitialize, isFalse);
      expect(source, isNot(contains('Future<void> initialize()')));
      expect(source, isNot(contains('await ')));
    });

    test(
        'introduces no base event class — developer event types are '
        'plain Dart classes', () {
      expect(source, isNot(contains('abstract class')));
      expect(source, isNot(contains('extends ')));
    });

    test(
        'imports only dart:async — no architecture, state-management, '
        'network, storage, or external package dependency', () {
      final imports = source
          .split('\n')
          .where((line) => line.trim().startsWith('import '))
          .toList();

      expect(imports, ["import 'dart:async';"]);
      for (final forbidden in [
        'package:flutter_bloc',
        'package:get/',
        'package:riverpod',
        'package:http',
        'package:dio',
        'package:shared_preferences',
        'package:hive_flutter',
        '../storage/',
        '../network/',
        '../../core/',
        '../../features/',
      ]) {
        expect(source, isNot(contains(forbidden)),
            reason: 'EventBusService must not depend on $forbidden');
      }
    });

    test(
        'generated source is identical across repeated calls — it takes '
        'no ProjectConfig-derived parameter at all, so it cannot vary '
        'by architecture/state-management/network/storage', () {
      // serviceSource(Service.eventBus) has no config parameter, so
      // this is true by construction — asserted explicitly so a future
      // refactor that accidentally threads config through would be
      // caught immediately.
      expect(ServiceTemplates.serviceSource(Service.eventBus), source);
      expect(ServiceTemplates.serviceSource(Service.eventBus), source);
    });

    test(
        'generated test source exercises every required semantic '
        'scenario', () {
      for (final scenario in [
        'instance is a singleton',
        'publish() with no subscribers does not throw',
        'subscribe() then publish() invokes the handler with the event',
        'every subscriber for the same type is invoked',
        'a subscriber to one type never receives a different type',
        'unsubscribe() stops the handler from receiving further events',
        'subscribing the same handler twice invokes it twice per publish',
        'a throwing handler does not prevent other subscribers from '
            'being',
      ]) {
        expect(testSource, contains(scenario),
            reason: 'missing required scenario: "$scenario"');
      }
    });

    test(
        'generated test source never references CrashReportingService or '
        'an error-reporting package — exception handling is the '
        'application\'s own decision', () {
      expect(testSource, isNot(contains('CrashReportingService')));
      expect(testSource, isNot(contains('package:sentry')));
      expect(testSource, isNot(contains('package:firebase')));
    });

    test(
        'ServiceDefinition metadata places Event Bus under Application '
        'Integration, matching Notifications/Deep Linking/Analytics/'
        'Force Update/App Review', () {
      expect(Service.eventBus.category, ServiceCategory.applicationIntegration);
      expect(Service.eventBus.folderName, 'event_bus');
      expect(Service.eventBus.fileName, 'event_bus_service.dart');
    });
  });

  group('RemoteConfigService', () {
    late String source;
    late String testSource;

    setUpAll(() {
      source = ServiceTemplates.serviceSource(Service.remoteConfig);
      testSource = ServiceTemplates.serviceTestSource(
        Service.remoteConfig,
        'demo_app',
        storage: Storage.sharedPreferences,
      );
    });

    test('generated source declares the expected class and singleton', () {
      expect(source, contains('class RemoteConfigService'));
      expect(source, contains('RemoteConfigService._();'));
      expect(source, contains('static final RemoteConfigService instance'));
    });

    test(
        'generated source declares setDefaults/fetchAndActivate and a '
        'typed getter per supported value type, each with a default '
        'fallback', () {
      expect(
          source,
          contains('void setDefaults(Map<String, Object> '
              'defaults)'));
      expect(source, contains('Future<bool> fetchAndActivate()'));
      expect(
          source,
          contains('String getString(String key, '
              '{String defaultValue = \'\'})'));
      expect(
          source,
          contains('bool getBool(String key, '
              '{bool defaultValue = false})'));
      expect(
          source,
          contains('int getInt(String key, '
              '{int defaultValue = 0})'));
      expect(
          source,
          contains('double getDouble(String key, '
              '{double defaultValue = 0.0})'));
    });

    test(
        'has initialize() — matches ServiceDefinition.hasInitialize being '
        'true', () {
      expect(Service.remoteConfig.hasInitialize, isTrue);
      expect(source, contains('Future<void> initialize() async'));
    });

    test(
        'imports nothing at all — a pure in-memory, provider-neutral '
        'implementation with no external package, architecture, or '
        'state-management dependency', () {
      final imports = source
          .split('\n')
          .where((line) => line.trim().startsWith('import '))
          .toList();

      expect(imports, isEmpty);
      for (final forbidden in [
        'package:flutter_bloc',
        'package:get/',
        'package:riverpod',
        'package:http',
        'package:dio',
        'Firebase',
        'LaunchDarkly',
        '../../core/',
        '../../features/',
      ]) {
        expect(source, isNot(contains(forbidden)),
            reason: 'RemoteConfigService must not depend on $forbidden');
      }
    });

    test(
        'generated source is identical across repeated calls — it takes '
        'no ProjectConfig-derived parameter at all, so it cannot vary '
        'by architecture/state-management/network/storage', () {
      expect(ServiceTemplates.serviceSource(Service.remoteConfig), source);
      expect(ServiceTemplates.serviceSource(Service.remoteConfig), source);
    });

    test(
        'generated test source exercises every required semantic '
        'scenario', () {
      for (final scenario in [
        'instance is a singleton',
        'initialize() is idempotent',
        'getters return their default when no value was ever fetched',
        'setDefaults() makes its values readable before '
            'fetchAndActivate()',
        'fetchAndActivate() activates the current defaults and returns '
            'true',
        'a getter returns the default when the stored value is a '
            'different',
      ]) {
        expect(testSource, contains(scenario),
            reason: 'missing required scenario: "$scenario"');
      }
    });

    test(
        'ServiceDefinition metadata places Remote Config under '
        'Application Integration, matching Notifications/Deep Linking/'
        'Analytics/Force Update/App Review/Event Bus', () {
      expect(Service.remoteConfig.category,
          ServiceCategory.applicationIntegration);
      expect(Service.remoteConfig.folderName, 'remote_config');
      expect(Service.remoteConfig.fileName, 'remote_config_service.dart');
    });
  });

  group('ProjectGenerator + services (Bootstrap wiring, regeneration)', () {
    late Directory tempDir;

    ProjectConfig configWith(Set<String> services) {
      return ProjectConfig(
        projectName: 'demo_app',
        services: services,
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );
    }

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_service_bootstrap_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
        'bootstrap.dart initializes only the selected services that have '
        'a real initialize(), in deterministic Service.values order — '
        'Service.logger/deviceInfo have none, so Bootstrap never calls '
        'or mentions them (see ServiceDefinition.hasInitialize)', () async {
      final config = configWith(
        {Service.analytics.id, Service.secureSession.id, Service.logger.id},
      );
      await ProjectGenerator(outputPath: tempDir.path, config: config)
          .generate();

      final bootstrap =
          File(ProjectPaths(projectRoot: tempDir.path).servicesBootstrapFile)
              .readAsStringSync();

      expect(bootstrap, contains("import '../services.dart';"));
      final secureIdx =
          bootstrap.indexOf('SecureSessionManager.instance.initialize()');
      final analyticsIdx =
          bootstrap.indexOf('AnalyticsService.instance.initialize()');

      expect(secureIdx, greaterThan(-1));
      expect(analyticsIdx, greaterThan(-1));
      // Service.values order is secureSession, ..., analytics.
      expect(secureIdx, lessThan(analyticsIdx));

      // Service.logger has no initialize() at all — selected, but never
      // mentioned in bootstrap.dart.
      expect(bootstrap, isNot(contains('DebugLogger')));

      // Unselected services are never mentioned at all.
      expect(bootstrap, isNot(contains('ConnectivityMonitor')));
      expect(bootstrap, isNot(contains('CrashReportingService')));
    });

    test(
        'bootstrap.dart has no services.dart import/calls when no '
        'optional services are selected — only the always-present '
        'Storage/Environment/Theme initialization', () async {
      await ProjectGenerator(outputPath: tempDir.path, config: configWith({}))
          .generate();

      final bootstrap =
          File(ProjectPaths(projectRoot: tempDir.path).servicesBootstrapFile)
              .readAsStringSync();

      expect(bootstrap, isNot(contains("import '../services.dart';")));
      expect(bootstrap, contains('StorageService.instance.initialize()'));
      expect(bootstrap, contains('EnvironmentManager.instance.load()'));
      expect(bootstrap, contains('ThemeService.instance.load()'));
      expect(bootstrap, contains('Future capabilities'));
    });

    test(
        'bootstrap.dart has no services.dart import or initialize() '
        'calls when only non-initializing services (logger, deviceInfo) '
        'are selected — even though lib/services/ is still generated '
        'for them', () async {
      final config = configWith({Service.logger.id, Service.deviceInfo.id});
      await ProjectGenerator(outputPath: tempDir.path, config: config)
          .generate();

      final paths = ProjectPaths(projectRoot: tempDir.path);
      final bootstrap = File(paths.servicesBootstrapFile).readAsStringSync();

      expect(bootstrap, isNot(contains("import '../services.dart';")));
      expect(bootstrap, isNot(contains('DebugLogger')));
      expect(bootstrap, isNot(contains('DeviceInfoService')));
      expect(
        File(paths.serviceFolderFile(
                Service.logger.folderName, Service.logger.fileName))
            .existsSync(),
        isTrue,
        reason: 'the service is still generated for direct use by '
            'application code — only Bootstrap skips it',
      );
      expect(
        File(paths.serviceFolderFile(
                Service.deviceInfo.folderName, Service.deviceInfo.fileName))
            .existsSync(),
        isTrue,
      );
    });

    test(
        'generates lib/services/ and test/services/ for the selected '
        'services', () async {
      await ProjectGenerator(
        outputPath: tempDir.path,
        config: configWith({Service.deeplink.id}),
      ).generate();

      final paths = ProjectPaths(projectRoot: tempDir.path);
      expect(
        File(paths.serviceFolderFile(
                Service.deeplink.folderName, Service.deeplink.fileName))
            .existsSync(),
        isTrue,
      );
      expect(File(paths.servicesBarrelFile).existsSync(), isTrue);
      expect(
        File(paths.testServiceFolderFile(
                Service.deeplink.folderName, 'deeplink_service_test.dart'))
            .existsSync(),
        isTrue,
      );
    });

    test(
        'regeneration removes stale service files no longer selected — '
        'no stale files remain', () async {
      final paths = ProjectPaths(projectRoot: tempDir.path);

      final first = ProjectGenerator(
        outputPath: tempDir.path,
        config: configWith({
          Service.secureSession.id,
          Service.connectivity.id,
          Service.analytics.id
        }),
      );
      await first.generate();
      expect(
        File(paths.serviceFolderFile(
                Service.connectivity.folderName, Service.connectivity.fileName))
            .existsSync(),
        isTrue,
      );

      final second = ProjectGenerator(
        outputPath: tempDir.path,
        config: configWith({
          Service.connectivity.id,
          Service.logger.id,
          Service.crashReporting.id
        }),
      );
      await second.clearGeneratedContent();
      await second.generate();

      final remainingFolders = Directory(paths.services)
          .listSync()
          .whereType<Directory>()
          .map((e) => e.path.split('/').last)
          .toSet();
      expect(
        remainingFolders,
        {
          'bootstrap',
          'network',
          'routing',
          'storage',
          'theme',
          Service.connectivity.folderName,
          Service.logger.folderName,
          Service.crashReporting.folderName,
        },
      );
      expect(
        File(paths.serviceFolderFile(Service.secureSession.folderName,
                Service.secureSession.fileName))
            .existsSync(),
        isFalse,
        reason: 'secureSession was deselected and must not survive '
            'regeneration',
      );
      expect(
        File(paths.serviceFolderFile(
                Service.analytics.folderName, Service.analytics.fileName))
            .existsSync(),
        isFalse,
      );
    });

    test(
        'clearGeneratedContent + regenerate with an empty selection '
        'leaves only the always-present core services — the selected '
        'optional service folder is gone', () async {
      final paths = ProjectPaths(projectRoot: tempDir.path);
      await ProjectGenerator(
        outputPath: tempDir.path,
        config: configWith({Service.analytics.id}),
      ).generate();
      expect(
        Directory('${paths.services}/${Service.analytics.folderName}')
            .existsSync(),
        isTrue,
      );

      final second =
          ProjectGenerator(outputPath: tempDir.path, config: configWith({}));
      await second.clearGeneratedContent();
      await second.generate();

      expect(Directory(paths.services).existsSync(), isTrue,
          reason: 'bootstrap/network/storage/theme/routing are always '
              'present, regardless of Production Service selection');
      expect(
        Directory('${paths.services}/${Service.analytics.folderName}')
            .existsSync(),
        isFalse,
        reason: 'analytics was deselected and must not survive '
            'regeneration',
      );
    });
  });
}
