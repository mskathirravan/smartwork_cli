import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// V1 Final Freeze: `smartwork service add/remove` — [ServiceLifecycle]
/// is the sole owner of changing a generated project's selected
/// Production Services after `smartwork init`, deliberately independent
/// of [FeatureLifecycle]/`FeatureGenerator`/`lib/features/`.
void main() {
  group('ServiceLifecycle', () {
    late Directory tempDir;
    late String projectPath;

    setUp(() async {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_service_lifecycle_');
      projectPath = tempDir.path;

      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        services: {Service.secureSession.id},
        initialFeatures: ['home'],
      );
      await ProjectGenerator(outputPath: projectPath, config: config)
          .generate();
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    group('addService', () {
      test(
          'generates the service file and test, and adds it to '
          'ProjectConfig.services', () async {
        await ServiceLifecycle().addService(
          projectPath: projectPath,
          serviceId: Service.analytics.id,
        );

        expect(
          File('$projectPath/lib/services/analytics/analytics_service.dart')
              .existsSync(),
          isTrue,
        );
        expect(
          File('$projectPath/test/services/analytics/'
                  'analytics_service_test.dart')
              .existsSync(),
          isTrue,
        );

        final config = await ProjectConfigFile(projectPath: projectPath).read();
        expect(config.services, contains(Service.analytics.id));
        expect(config.services, contains(Service.secureSession.id));
      });

      test('regenerates Bootstrap to also initialize the new service',
          () async {
        await ServiceLifecycle().addService(
          projectPath: projectPath,
          serviceId: Service.analytics.id,
        );

        final bootstrap =
            File('$projectPath/lib/services/bootstrap/bootstrap.dart')
                .readAsStringSync();
        expect(bootstrap, contains('AnalyticsService.instance.initialize()'));
        // The service already selected before this call must still be
        // initialized too — this is a full regeneration, not a append.
        expect(
          bootstrap,
          contains('SecureSessionManager.instance.initialize()'),
        );
      });

      test(
          'does not call initialize() for a service with no '
          'initialize() at all (DeviceInfoService)', () async {
        await ServiceLifecycle().addService(
          projectPath: projectPath,
          serviceId: Service.deviceInfo.id,
        );

        final bootstrap =
            File('$projectPath/lib/services/bootstrap/bootstrap.dart')
                .readAsStringSync();
        expect(bootstrap, isNot(contains('DeviceInfoService.instance.')));

        final config = await ProjectConfigFile(projectPath: projectPath).read();
        expect(config.services, contains(Service.deviceInfo.id));
      });

      test('regenerates the services.dart barrel to export the new service',
          () async {
        await ServiceLifecycle().addService(
          projectPath: projectPath,
          serviceId: Service.analytics.id,
        );

        final barrel =
            File('$projectPath/lib/services/services.dart').readAsStringSync();
        expect(barrel, contains("export 'analytics/analytics_service.dart';"));
      });

      test('never touches routing, README, or any other feature', () async {
        final routerBefore =
            File('$projectPath/lib/services/routing/app_router.dart')
                .readAsStringSync();
        final readmeBefore = File('$projectPath/README.md').existsSync()
            ? File('$projectPath/README.md').readAsStringSync()
            : null;

        await ServiceLifecycle().addService(
          projectPath: projectPath,
          serviceId: Service.analytics.id,
        );

        expect(
          File('$projectPath/lib/services/routing/app_router.dart')
              .readAsStringSync(),
          routerBefore,
        );
        if (readmeBefore != null) {
          expect(
              File('$projectPath/README.md').readAsStringSync(), readmeBefore);
        }
        expect(
          Directory('$projectPath/lib/features/home').existsSync(),
          isTrue,
        );
      });

      test(
          'throws ServiceAlreadySelectedException without changing '
          'anything when the service is already selected', () async {
        final configBefore =
            await ProjectConfigFile(projectPath: projectPath).read();

        await expectLater(
          ServiceLifecycle().addService(
            projectPath: projectPath,
            serviceId: Service.secureSession.id,
          ),
          throwsA(isA<ServiceAlreadySelectedException>()),
        );

        final configAfter =
            await ProjectConfigFile(projectPath: projectPath).read();
        expect(configAfter.services, configBefore.services);
      });

      test(
          'throws UnknownServiceException for a name that is not a real '
          'Service, without changing anything', () async {
        final configBefore =
            await ProjectConfigFile(projectPath: projectPath).read();

        await expectLater(
          ServiceLifecycle().addService(
            projectPath: projectPath,
            serviceId: 'not_a_real_service',
          ),
          throwsA(isA<UnknownServiceException>()),
        );

        final configAfter =
            await ProjectConfigFile(projectPath: projectPath).read();
        expect(configAfter.services, configBefore.services);
      });

      test(
          'rejects bootstrap/routing/network/storage/theme as unknown '
          'services — they have no Service enum value, so they can '
          'never be added or removed through this lifecycle', () async {
        for (final infraName in [
          'bootstrap',
          'routing',
          'network',
          'storage',
          'theme',
        ]) {
          await expectLater(
            ServiceLifecycle().addService(
              projectPath: projectPath,
              serviceId: infraName,
            ),
            throwsA(isA<UnknownServiceException>()),
            reason: '$infraName must be rejected as an unknown service',
          );
        }
      });

      test(
          'adding secureSession to a project that was NOT generated with '
          'it selected regenerates storage_constants.dart with the keys '
          'SecureSessionManager references — a real, previously '
          'undetected flutter analyze-failing gap found during the V1.1 '
          'pre-freeze E2E audit', () async {
        // A dedicated project generated WITHOUT secureSession (the
        // shared setUp above always includes it) so this exercises the
        // genuinely-missing regeneration path.
        final noSecureSessionDir = Directory.systemTemp
            .createTempSync('smartwork_service_lifecycle_no_ss_');
        addTearDown(() => noSecureSessionDir.deleteSync(recursive: true));
        final noSecureSessionPath = noSecureSessionDir.path;
        await ProjectGenerator(
          outputPath: noSecureSessionPath,
          config: ProjectConfig(
            projectName: 'demo_app',
            architecture: Architecture.cleanArchitecture,
            stateManagement: StateManagement.bloc,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: ['home'],
          ),
        ).generate();

        final storageConstantsFile = File(
            '$noSecureSessionPath/lib/core/constants/storage_constants.dart');
        expect(storageConstantsFile.readAsStringSync(),
            isNot(contains('secureAccessTokenKey')),
            reason: 'sanity check: the base project must not start with '
                'the secure session keys');

        await ServiceLifecycle().addService(
          projectPath: noSecureSessionPath,
          serviceId: Service.secureSession.id,
        );

        final storageConstants = storageConstantsFile.readAsStringSync();
        expect(storageConstants, contains('secureAccessTokenKey'));
        expect(storageConstants, contains('secureRefreshTokenKey'));
      });
    });

    group('removeService', () {
      test(
          'deletes the service file and test, and removes it from '
          'ProjectConfig.services', () async {
        await ServiceLifecycle().removeService(
          projectPath: projectPath,
          serviceId: Service.secureSession.id,
        );

        expect(
          File('$projectPath/lib/services/secure_session/'
                  'secure_session_manager.dart')
              .existsSync(),
          isFalse,
        );
        expect(
          Directory('$projectPath/lib/services/secure_session').existsSync(),
          isFalse,
          reason: 'the now-empty service folder should be removed too',
        );
        expect(
          File('$projectPath/test/services/secure_session/'
                  'secure_session_manager_test.dart')
              .existsSync(),
          isFalse,
        );

        final config = await ProjectConfigFile(projectPath: projectPath).read();
        expect(config.services, isNot(contains(Service.secureSession.id)));
      });

      test(
          'regenerates Bootstrap to no longer initialize the removed '
          'service', () async {
        await ServiceLifecycle().removeService(
          projectPath: projectPath,
          serviceId: Service.secureSession.id,
        );

        final bootstrap =
            File('$projectPath/lib/services/bootstrap/bootstrap.dart')
                .readAsStringSync();
        expect(
          bootstrap,
          isNot(contains('SecureSessionManager')),
        );
      });

      test('regenerates the services.dart barrel to no longer export it',
          () async {
        await ServiceLifecycle().removeService(
          projectPath: projectPath,
          serviceId: Service.secureSession.id,
        );

        final barrel =
            File('$projectPath/lib/services/services.dart').readAsStringSync();
        expect(barrel, isNot(contains('secure_session')));
      });

      test(
          'removes only the targeted service — every other selected '
          'service, and the always-present Network/Storage/Theme, '
          'survive untouched', () async {
        await ServiceLifecycle().addService(
          projectPath: projectPath,
          serviceId: Service.analytics.id,
        );

        await ServiceLifecycle().removeService(
          projectPath: projectPath,
          serviceId: Service.secureSession.id,
        );

        expect(
          File('$projectPath/lib/services/analytics/analytics_service.dart')
              .existsSync(),
          isTrue,
          reason: 'analytics was never asked to be removed',
        );
        expect(
          File('$projectPath/lib/services/network/network_service.dart')
              .existsSync(),
          isTrue,
        );
        expect(
          File('$projectPath/lib/services/storage/storage_service.dart')
              .existsSync(),
          isTrue,
        );
        expect(
          File('$projectPath/lib/services/theme/theme_service.dart')
              .existsSync(),
          isTrue,
        );
        expect(
          Directory('$projectPath/lib/services/routing').existsSync(),
          isTrue,
        );
      });

      test('never touches routing, README, or any feature', () async {
        final routerBefore =
            File('$projectPath/lib/services/routing/app_router.dart')
                .readAsStringSync();

        await ServiceLifecycle().removeService(
          projectPath: projectPath,
          serviceId: Service.secureSession.id,
        );

        expect(
          File('$projectPath/lib/services/routing/app_router.dart')
              .readAsStringSync(),
          routerBefore,
        );
        expect(
          Directory('$projectPath/lib/features/home').existsSync(),
          isTrue,
        );
      });

      test(
          'throws ServiceNotSelectedException without changing '
          'anything when the service is not currently selected', () async {
        final configBefore =
            await ProjectConfigFile(projectPath: projectPath).read();

        await expectLater(
          ServiceLifecycle().removeService(
            projectPath: projectPath,
            serviceId: Service.analytics.id,
          ),
          throwsA(isA<ServiceNotSelectedException>()),
        );

        final configAfter =
            await ProjectConfigFile(projectPath: projectPath).read();
        expect(configAfter.services, configBefore.services);
        expect(
          File('$projectPath/lib/services/secure_session/'
                  'secure_session_manager.dart')
              .existsSync(),
          isTrue,
          reason: 'a failed remove must not touch an unrelated service',
        );
      });

      test(
          'rejects bootstrap/routing/network/storage/theme as unknown '
          'services, never deleting their generated infrastructure '
          'files', () async {
        for (final infraName in [
          'bootstrap',
          'routing',
          'network',
          'storage',
          'theme',
        ]) {
          await expectLater(
            ServiceLifecycle().removeService(
              projectPath: projectPath,
              serviceId: infraName,
            ),
            throwsA(isA<UnknownServiceException>()),
            reason: '$infraName must be rejected as an unknown service',
          );
        }

        for (final infraDir in [
          'bootstrap',
          'routing',
          'network',
          'storage',
          'theme',
        ]) {
          expect(
            Directory('$projectPath/lib/services/$infraDir').existsSync(),
            isTrue,
            reason: 'lib/services/$infraDir must survive every rejected '
                'removeService call',
          );
        }
      });

      test(
          'removing secureSession regenerates storage_constants.dart '
          'without the keys SecureSessionManager no longer needs — the '
          'symmetric case of the add-side regeneration fix', () async {
        final storageConstantsFile =
            File('$projectPath/lib/core/constants/storage_constants.dart');
        expect(storageConstantsFile.readAsStringSync(),
            contains('secureAccessTokenKey'),
            reason: 'sanity check: the shared setUp fixture starts with '
                'secureSession selected');

        await ServiceLifecycle().removeService(
          projectPath: projectPath,
          serviceId: Service.secureSession.id,
        );

        final storageConstants = storageConstantsFile.readAsStringSync();
        expect(storageConstants, isNot(contains('secureAccessTokenKey')));
        expect(storageConstants, isNot(contains('secureRefreshTokenKey')));
      });
    });
  });
}
