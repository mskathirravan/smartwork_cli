import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureContentGenerator', () {
    late Directory tempDir;
    late ProjectPaths paths;
    late FileWriter fileWriter;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_content_test_');
      paths = _paths(tempDir.path);
      fileWriter = FileWriter();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    group('Clean Architecture + BLoC (reference vertical slice)', () {
      test('generates a coherent, wired domain/data/presentation skeleton',
          () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        final featurePath = paths.featurePath('auth');
        for (final relativeFile in [
          'domain/entities/auth.dart',
          'domain/repositories/auth_repository.dart',
          'domain/usecases/auth_usecase.dart',
          'data/models/auth_model.dart',
          'data/datasources/auth_data_source.dart',
          'data/repositories/auth_repository_impl.dart',
          'presentation/pages/auth_page.dart',
          'state/auth_bloc.dart',
          'state/auth_event.dart',
          'state/auth_state.dart',
        ]) {
          expect(
            File(path.join(featurePath, relativeFile)).existsSync(),
            isTrue,
            reason: '$relativeFile should exist',
          );
        }

        // WHAT (blueprint) is consistently realized: every generated file
        // resolves its placeholders and cross-references the entity.
        final repositoryImpl = File(
          path.join(featurePath, 'data/repositories/auth_repository_impl.dart'),
        ).readAsStringSync();
        expect(repositoryImpl,
            contains('class AuthRepositoryImpl implements AuthRepository'));
        expect(repositoryImpl,
            contains("import '../../domain/entities/auth.dart';"));
        expect(repositoryImpl, isNot(contains('{{')));

        final useCase = File(
          path.join(featurePath, 'domain/usecases/auth_usecase.dart'),
        ).readAsStringSync();
        expect(useCase, contains('class GetAuthUseCase'));
        expect(useCase, contains('final AuthRepository repository;'));
      });

      test('respects a custom, partial component selection', () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(
            name: 'auth',
            components: {FeatureComponent.entity, FeatureComponent.page},
          ),
          config,
          paths,
          fileWriter,
        );

        final featurePath = paths.featurePath('auth');
        expect(
          File(path.join(featurePath, 'domain/entities/auth.dart'))
              .existsSync(),
          isTrue,
        );
        expect(
          File(path.join(featurePath, 'presentation/pages/auth_page.dart'))
              .existsSync(),
          isTrue,
        );
        // Not selected: repository, useCase, dataSource.
        expect(
          File(path.join(
                  featurePath, 'domain/repositories/auth_repository.dart'))
              .existsSync(),
          isFalse,
        );
        expect(
          File(path.join(featurePath, 'domain/usecases/auth_usecase.dart'))
              .existsSync(),
          isFalse,
        );
        expect(
          File(path.join(featurePath, 'data/datasources/auth_data_source.dart'))
              .existsSync(),
          isFalse,
        );
      });
    });

    group('same intent, translated per architecture (Phase 7)', () {
      test('Clean + Cubit: blueprint content plus Cubit state files', () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.cubit,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        final featurePath = paths.featurePath('auth');
        expect(
          File(path.join(featurePath, 'domain/entities/auth.dart'))
              .existsSync(),
          isTrue,
        );
        expect(
          File(path.join(featurePath, 'state/auth_cubit.dart')).existsSync(),
          isTrue,
        );
      });

      test('Clean + GetX: blueprint content plus GetX controller', () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.getx,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        final featurePath = paths.featurePath('auth');
        expect(
          File(path.join(featurePath, 'domain/entities/auth.dart'))
              .existsSync(),
          isTrue,
        );
        final controller = File(
          path.join(featurePath, 'presentation/getx/auth_controller.dart'),
        ).readAsStringSync();
        expect(controller,
            contains('class AuthController extends GetxController'));
        expect(controller, isNot(contains('{{')));
      });

      test('Clean + Riverpod: blueprint content plus provider files', () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.riverpod,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        final featurePath = paths.featurePath('auth');
        expect(
          File(path.join(featurePath, 'domain/entities/auth.dart'))
              .existsSync(),
          isTrue,
        );
        expect(
          File(path.join(
            featurePath,
            'presentation/providers/auth_provider.dart',
          )).existsSync(),
          isTrue,
        );
      });

      test(
          'MVVM + BLoC: entity/repository/useCase/dataSource collapse into '
          'models/ + services/', () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.mvvm,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        final featurePath = paths.featurePath('auth');
        expect(
          File(path.join(featurePath, 'models/auth_model.dart')).existsSync(),
          isTrue,
        );
        expect(
          File(path.join(featurePath, 'services/auth_service.dart'))
              .existsSync(),
          isTrue,
        );
        expect(
          File(path.join(featurePath, 'views/auth_page.dart')).existsSync(),
          isTrue,
        );
        // MVVM has no domain layer — Clean-specific paths must not appear.
        expect(
          Directory(path.join(featurePath, 'domain')).existsSync(),
          isFalse,
        );
        expect(
          File(path.join(featurePath, 'state/auth_bloc.dart')).existsSync(),
          isTrue,
        );
      });

      test(
          'MVP + BLoC: entity/repository/useCase/dataSource collapse into '
          'models/ + services/', () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.mvp,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth'),
          config,
          paths,
          fileWriter,
        );

        final featurePath = paths.featurePath('auth');
        expect(
          File(path.join(featurePath, 'models/auth_model.dart')).existsSync(),
          isTrue,
        );
        expect(
          File(path.join(featurePath, 'services/auth_service.dart'))
              .existsSync(),
          isTrue,
        );
        expect(
          File(path.join(featurePath, 'views/auth_page.dart')).existsSync(),
          isTrue,
        );
        expect(
          Directory(path.join(featurePath, 'domain')).existsSync(),
          isFalse,
        );
        expect(
          File(path.join(featurePath, 'state/auth_bloc.dart')).existsSync(),
          isTrue,
        );
      });
    });

    group('all 12 architecture x state-management combinations', () {
      for (final architecture in Architecture.values) {
        for (final stateManagement in StateManagement.values) {
          test(
              '$architecture + $stateManagement: blueprint content is '
              'generated and no placeholders remain unresolved', () async {
            final combinationDir = Directory.systemTemp
                .createTempSync('smartwork_content_matrix_');
            addTearDown(() => combinationDir.deleteSync(recursive: true));
            final combinationPaths = _paths(combinationDir.path);

            final config = ProjectConfig(
              projectName: 'demo_app',
              architecture: architecture,
              stateManagement: stateManagement,
              network: Network.http,
              storage: Storage.sharedPreferences,
              initialFeatures: ['home'],
            );

            await FeatureGenerator().generate(
              FeatureConfig(name: 'auth'),
              config,
              combinationPaths,
              fileWriter,
            );

            final featurePath = combinationPaths.featurePath('auth');
            final dartFiles = Directory(featurePath)
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart'));

            expect(dartFiles, isNotEmpty,
                reason: 'at least the blueprint content should generate '
                    '.dart files');

            for (final file in dartFiles) {
              final content = file.readAsStringSync();
              expect(
                content,
                isNot(contains('{{')),
                reason: '${file.path} has an unresolved placeholder',
              );
            }

            // The architecture-neutral part of the blueprint (page) is
            // realized in every architecture, regardless of the folder it
            // lands in.
            final hasPageFile = Directory(featurePath)
                .listSync(recursive: true)
                .whereType<File>()
                .any((f) => f.path.endsWith('_page.dart'));
            expect(hasPageFile, isTrue,
                reason: 'FeatureComponent.page should always produce a '
                    'page file');

            // MVVM/MVP: the presentation companion (ViewModel/Presenter)
            // must exist, sit in its own established folder, and must not
            // collide with whatever state-management also wrote (BLoC/
            // Cubit/Riverpod keep their own separate files; GetX writes
            // nothing extra for these architectures).
            if (architecture == Architecture.mvvm) {
              final viewModelFile = File(
                  path.join(featurePath, 'viewmodels/auth_view_model.dart'));
              expect(viewModelFile.existsSync(), isTrue,
                  reason: 'MVVM should generate a ViewModel');
              expect(viewModelFile.readAsStringSync(),
                  contains('class AuthViewModel'));
            }
            if (architecture == Architecture.mvp) {
              final presenterFile = File(
                  path.join(featurePath, 'presenters/auth_presenter.dart'));
              expect(presenterFile.existsSync(), isTrue,
                  reason: 'MVP should generate a Presenter');
              expect(presenterFile.readAsStringSync(),
                  contains('class AuthPresenter'));
            }
            if (architecture == Architecture.mvvm ||
                architecture == Architecture.mvp) {
              switch (stateManagement) {
                case StateManagement.bloc:
                  expect(
                    File(path.join(featurePath, 'state/auth_bloc.dart'))
                        .existsSync(),
                    isTrue,
                    reason: 'BLoC keeps writing its own separate state '
                        'file independent of ViewModel/Presenter',
                  );
                case StateManagement.cubit:
                  expect(
                    File(path.join(featurePath, 'state/auth_cubit.dart'))
                        .existsSync(),
                    isTrue,
                  );
                case StateManagement.riverpod:
                  expect(
                    File(path.join(featurePath, 'providers/auth_provider.dart'))
                        .existsSync(),
                    isTrue,
                    reason: 'Riverpod provider must resolve against the '
                        'now-real ViewModel/Presenter class',
                  );
                case StateManagement.getx:
                  expect(
                    Directory(path.join(featurePath, 'presentation'))
                        .existsSync(),
                    isFalse,
                    reason: 'GetX still generates nothing extra for MVVM/'
                        'MVP — its reactivity belongs inside the '
                        'ViewModel/Presenter itself',
                  );
              }
            }
          });
        }
      }
    });

    group('partial-selection dependency resolution', () {
      // A single requested component, across every architecture: resolution
      // must fill in whatever its generated files reference so nothing is
      // ever missing, without pulling in unrelated components.
      const partialSelections = {
        'repository only': FeatureComponent.repository,
        'useCase only': FeatureComponent.useCase,
        'dataSource only': FeatureComponent.dataSource,
        'page only': FeatureComponent.page,
        'widgets only': FeatureComponent.widgets,
        'tests only': FeatureComponent.tests,
      };

      for (final entry in partialSelections.entries) {
        for (final architecture in Architecture.values) {
          test(
              '$architecture + "${entry.key}": every referenced file '
              'exists and no placeholders remain unresolved', () async {
            final dir =
                Directory.systemTemp.createTempSync('smartwork_partial_');
            addTearDown(() => dir.deleteSync(recursive: true));
            final partialPaths = _paths(dir.path);

            final config = ProjectConfig(
              projectName: 'demo_app',
              architecture: architecture,
              stateManagement: StateManagement.bloc,
              network: Network.http,
              storage: Storage.sharedPreferences,
              initialFeatures: ['home'],
            );

            await FeatureGenerator().generate(
              FeatureConfig(name: 'auth', components: {entry.value}),
              config,
              partialPaths,
              fileWriter,
            );

            _verifyNoDanglingImportsOrPlaceholders(
                partialPaths.featurePath('auth'));
          });
        }
      }

      test('resolution never pulls in an unrelated component', () async {
        // repository must not drag in `page`, and vice versa.
        final dir = Directory.systemTemp.createTempSync('smartwork_partial_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final partialPaths = _paths(dir.path);

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(
            name: 'auth',
            components: {FeatureComponent.repository},
          ),
          config,
          partialPaths,
          fileWriter,
        );

        final featurePath = partialPaths.featurePath('auth');
        expect(
          File(path.join(featurePath, 'presentation/pages/auth_page.dart'))
              .existsSync(),
          isFalse,
          reason: 'repository does not depend on page; it must not be '
              'generated',
        );
        expect(
          File(path.join(featurePath, 'domain/usecases/auth_usecase.dart'))
              .existsSync(),
          isFalse,
          reason: 'repository does not depend on useCase; it must not be '
              'generated',
        );
      });
    });

    group('MVVM/MVP + Riverpod cross-axis dependency (regression)', () {
      // RiverpodTemplates' MVVM/MVP provider templates always import the
      // ViewModel/Presenter file, regardless of the blueprint. This must
      // hold for every possible component selection, including empty —
      // the exact case that was previously broken.
      const scenarios = {
        'empty components': <FeatureComponent>{},
        'page': {FeatureComponent.page},
        'entity': {FeatureComponent.entity},
        'repository': {FeatureComponent.repository},
        'useCase': {FeatureComponent.useCase},
        'dataSource': {FeatureComponent.dataSource},
      };

      for (final architecture in [Architecture.mvvm, Architecture.mvp]) {
        final companionRelativePath = architecture == Architecture.mvvm
            ? 'viewmodels/auth_view_model.dart'
            : 'presenters/auth_presenter.dart';
        final companionClassName = architecture == Architecture.mvvm
            ? 'AuthViewModel'
            : 'AuthPresenter';

        for (final scenario in scenarios.entries) {
          test(
              '$architecture + Riverpod + ${scenario.key}: provider import '
              'resolves, no dangling references, deterministic', () async {
            final dir =
                Directory.systemTemp.createTempSync('smartwork_riverpod_');
            addTearDown(() => dir.deleteSync(recursive: true));
            final riverpodPaths = _paths(dir.path);

            final config = ProjectConfig(
              projectName: 'demo_app',
              architecture: architecture,
              stateManagement: StateManagement.riverpod,
              network: Network.http,
              storage: Storage.sharedPreferences,
              initialFeatures: ['home'],
            );

            final result = await FeatureGenerator().generate(
              FeatureConfig(name: 'auth', components: scenario.value),
              config,
              riverpodPaths,
              fileWriter,
            );

            final featurePath = riverpodPaths.featurePath('auth');

            // The required architecture artifact is never missing.
            final companionFile =
                File(path.join(featurePath, companionRelativePath));
            expect(companionFile.existsSync(), isTrue,
                reason: 'provider requires $companionRelativePath to exist');
            expect(companionFile.readAsStringSync(),
                contains('class $companionClassName'));

            // Every relative import resolves; no unresolved placeholders.
            _verifyNoDanglingImportsOrPlaceholders(featurePath);

            // Requesting `page` (or nothing beyond it) must not silently
            // pull in unrelated blueprint components.
            if (!scenario.value.contains(FeatureComponent.entity) &&
                !scenario.value.contains(FeatureComponent.repository) &&
                !scenario.value.contains(FeatureComponent.useCase) &&
                !scenario.value.contains(FeatureComponent.dataSource)) {
              expect(
                File(path.join(featurePath, 'models/auth_model.dart'))
                    .existsSync(),
                isFalse,
                reason: 'no data component was requested; a model must '
                    'not be generated',
              );
            }

            // Determinism: regenerating the same request in a fresh
            // directory produces the same counts.
            final dir2 =
                Directory.systemTemp.createTempSync('smartwork_riverpod_');
            addTearDown(() => dir2.deleteSync(recursive: true));
            final result2 = await FeatureGenerator().generate(
              FeatureConfig(name: 'auth', components: scenario.value),
              config,
              _paths(dir2.path),
              fileWriter,
            );
            expect(result2.fileCount, result.fileCount);
            expect(result2.directoryCount, result.directoryCount);
          });
        }
      }
    });

    group('widgets and tests components', () {
      // widgets/tests generation is entirely independent of state
      // management: no template either generates references it, and no
      // state-management generator references widgets/tests. So the
      // state-management axis is only exercised once here (Riverpod, since
      // it is the one axis with a real cross-axis dependency, to confirm
      // it still coexists correctly) rather than across all four options.
      const scenarios = {
        'widgets only': {FeatureComponent.widgets},
        'tests only': {FeatureComponent.tests},
        'widgets + tests': {FeatureComponent.widgets, FeatureComponent.tests},
        'page + widgets': {FeatureComponent.page, FeatureComponent.widgets},
        'page + tests': {FeatureComponent.page, FeatureComponent.tests},
        'page + widgets + tests': {
          FeatureComponent.page,
          FeatureComponent.widgets,
          FeatureComponent.tests,
        },
        'repository + tests': {
          FeatureComponent.repository,
          FeatureComponent.tests,
        },
        'useCase + tests': {FeatureComponent.useCase, FeatureComponent.tests},
      };

      for (final architecture in Architecture.values) {
        for (final scenario in scenarios.entries) {
          test(
              '$architecture + "${scenario.key}": expected files exist, '
              'no unexpected ones, imports resolve, deterministic', () async {
            final dir = Directory.systemTemp.createTempSync('smartwork_wt_');
            addTearDown(() => dir.deleteSync(recursive: true));
            final wtPaths = _paths(dir.path);

            final config = ProjectConfig(
              projectName: 'demo_app',
              architecture: architecture,
              stateManagement: StateManagement.bloc,
              network: Network.http,
              storage: Storage.sharedPreferences,
              initialFeatures: ['home'],
            );

            final result = await FeatureGenerator().generate(
              FeatureConfig(name: 'auth', components: scenario.value),
              config,
              wtPaths,
              fileWriter,
            );

            final featurePath = wtPaths.featurePath('auth');
            final widgetsSubpath =
                architecture == Architecture.cleanArchitecture
                    ? 'presentation/widgets/auth_widget.dart'
                    : 'views/widgets/auth_widget.dart';
            final testFile = File(
                path.join(wtPaths.test, 'features/auth/auth_page_test.dart'));

            // widgets: present iff requested.
            expect(
              File(path.join(featurePath, widgetsSubpath)).existsSync(),
              scenario.value.contains(FeatureComponent.widgets),
              reason: 'widgets file presence must match the request',
            );

            // tests: present iff requested (tests always resolves page in,
            // so this is unconditional on the scenario containing `tests`).
            expect(
              testFile.existsSync(),
              scenario.value.contains(FeatureComponent.tests),
              reason: 'test file presence must match the request',
            );

            if (scenario.value.contains(FeatureComponent.tests)) {
              final testContent = testFile.readAsStringSync();
              expect(testContent, isNot(contains('{{')));
              expect(testContent, contains("testWidgets('AuthPage"));
              expect(testContent, contains('AuthPage()'));

              // The test's package: import is outside what
              // _verifyNoDanglingImportsOrPlaceholders checks (relative
              // imports only) — verify it explicitly here. This is the
              // one deliberate exception to the Project Structure &
              // Import Cleanup milestone's relative-imports rule: a
              // relative import from test/ back into lib/ trips the
              // analyzer's avoid_relative_lib_imports (confirmed via a
              // real generated project), so package:demo_app/... stays.
              final packageImport = RegExp(r"import 'package:demo_app/(.+)';")
                  .firstMatch(testContent)!
                  .group(1)!;
              final targetInLib = File(path.join(wtPaths.lib, packageImport));
              expect(targetInLib.existsSync(), isTrue,
                  reason:
                      'test package import must resolve to a real lib/ file');
            }

            // No unresolved placeholders / dangling relative imports
            // anywhere the request could plausibly have touched.
            _verifyNoDanglingImportsOrPlaceholders(featurePath);

            // Determinism.
            final dir2 = Directory.systemTemp.createTempSync('smartwork_wt_');
            addTearDown(() => dir2.deleteSync(recursive: true));
            final result2 = await FeatureGenerator().generate(
              FeatureConfig(name: 'auth', components: scenario.value),
              config,
              _paths(dir2.path),
              fileWriter,
            );
            expect(result2.fileCount, result.fileCount);
            expect(result2.directoryCount, result.directoryCount);
          });
        }
      }

      test(
          'MVVM + Riverpod + tests: coexists correctly with the '
          'unconditional ViewModel and the Riverpod provider', () async {
        final dir = Directory.systemTemp.createTempSync('smartwork_wt_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final wtPaths = _paths(dir.path);

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.mvvm,
          stateManagement: StateManagement.riverpod,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth', components: {FeatureComponent.tests}),
          config,
          wtPaths,
          fileWriter,
        );

        final featurePath = wtPaths.featurePath('auth');
        expect(
          File(path.join(featurePath, 'viewmodels/auth_view_model.dart'))
              .existsSync(),
          isTrue,
        );
        expect(
          File(path.join(featurePath, 'providers/auth_provider.dart'))
              .existsSync(),
          isTrue,
        );
        expect(
          File(path.join(wtPaths.test, 'features/auth/auth_page_test.dart'))
              .existsSync(),
          isTrue,
        );
        _verifyNoDanglingImportsOrPlaceholders(featurePath);
      });

      test(
          'MVP + Riverpod + tests: coexists correctly with the '
          'unconditional Presenter and the Riverpod provider', () async {
        final dir = Directory.systemTemp.createTempSync('smartwork_wt_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final wtPaths = _paths(dir.path);

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.mvp,
          stateManagement: StateManagement.riverpod,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth', components: {FeatureComponent.tests}),
          config,
          wtPaths,
          fileWriter,
        );

        final featurePath = wtPaths.featurePath('auth');
        expect(
          File(path.join(featurePath, 'presenters/auth_presenter.dart'))
              .existsSync(),
          isTrue,
        );
        expect(
          File(path.join(featurePath, 'providers/auth_provider.dart'))
              .existsSync(),
          isTrue,
        );
        expect(
          File(path.join(wtPaths.test, 'features/auth/auth_page_test.dart'))
              .existsSync(),
          isTrue,
        );
        _verifyNoDanglingImportsOrPlaceholders(featurePath);
      });

      test('widgets does not pull in page or any other component', () async {
        final dir = Directory.systemTemp.createTempSync('smartwork_wt_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final wtPaths = _paths(dir.path);

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth', components: {FeatureComponent.widgets}),
          config,
          wtPaths,
          fileWriter,
        );

        final featurePath = wtPaths.featurePath('auth');
        expect(
          File(path.join(featurePath, 'presentation/pages/auth_page.dart'))
              .existsSync(),
          isFalse,
          reason: 'widgets does not depend on page',
        );
        expect(
          File(path.join(featurePath, 'domain/entities/auth.dart'))
              .existsSync(),
          isFalse,
        );
        expect(
          Directory(path.join(wtPaths.test, 'features')).existsSync(),
          isFalse,
          reason: 'widgets does not imply tests',
        );
      });
    });

    group('network integration', () {
      // Network no longer varies per-feature generated content at all:
      // every dataSource/service calls the project-level NetworkService
      // (lib/services/network/) uniformly, regardless of
      // ProjectConfig.network — never package:http/package:dio directly.
      // NetworkService itself is what actually varies by Http/Dio/Other
      // (see network_service_templates coverage). This loop confirms
      // that provider-uniformity actually holds, for every architecture
      // and every Network value, rather than assuming it.
      for (final architecture in Architecture.values) {
        Future<String> generateAndReadContent(Network network) async {
          final dir = Directory.systemTemp.createTempSync('smartwork_net_');
          addTearDown(() => dir.deleteSync(recursive: true));
          final netPaths = _paths(dir.path);

          final config = ProjectConfig(
            projectName: 'demo_app',
            architecture: architecture,
            stateManagement: StateManagement.bloc,
            network: network,
            storage: Storage.sharedPreferences,
            initialFeatures: ['home'],
          );

          await FeatureGenerator().generate(
            FeatureConfig(
              name: 'auth',
              components: {FeatureComponent.dataSource},
            ),
            config,
            netPaths,
            fileWriter,
          );

          final featurePath = netPaths.featurePath('auth');
          final file = architecture == Architecture.cleanArchitecture
              ? File(path.join(
                  featurePath,
                  'data/datasources/auth_network_data_source.dart',
                ))
              : File(path.join(featurePath, 'services/auth_service.dart'));
          _verifyNoDanglingImportsOrPlaceholders(featurePath);
          return file.readAsStringSync();
        }

        test(
            '$architecture: dataSource calls NetworkService uniformly, '
            'never package:http/dio directly', () async {
          final contentToCheck = await generateAndReadContent(Network.http);

          if (architecture == Architecture.cleanArchitecture) {
            expect(
              contentToCheck,
              contains('class AuthNetworkDataSource implements '
                  'AuthDataSource'),
            );
          }
          expect(contentToCheck,
              contains('services/network/network_service.dart'));
          expect(contentToCheck,
              contains("await NetworkService.instance.get('/auth')"));
          expect(contentToCheck, isNot(contains('package:http')));
          expect(contentToCheck, isNot(contains('package:dio')));
          expect(contentToCheck, isNot(contains('EnvironmentManager')),
              reason: 'NetworkService itself resolves the base URL — '
                  'feature code never touches EnvironmentManager directly');

          expect(
              contentToCheck, contains("import '../models/auth_model.dart';"));
          expect(contentToCheck, contains('return const AuthModel();'));
          expect(contentToCheck, isNot(contains('fromJson')));
          expect(contentToCheck, isNot(contains('toJson')));
          expect(contentToCheck, isNot(contains('TODO')),
              reason: 'the concrete Model return must not carry a '
                  'placeholder/TODO comment implying it is incomplete');
          expect(contentToCheck, isNot(contains('UnimplementedError')),
              reason: 'features never see Network.other\'s stub shape — '
                  'that lives entirely inside NetworkService');
        });

        test(
            '$architecture: dataSource content is byte-identical '
            'regardless of ProjectConfig.network (Http/Dio/Other)', () async {
          final http = await generateAndReadContent(Network.http);
          final dio = await generateAndReadContent(Network.dio);
          final other = await generateAndReadContent(Network.other);

          expect(dio, http);
          expect(other, http);
        });
      }

      test(
          '--components dataSource resolves entity but not repository, '
          'useCase, page, widgets, or tests', () async {
        final dir = Directory.systemTemp.createTempSync('smartwork_net_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final netPaths = _paths(dir.path);

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(
              name: 'auth', components: {FeatureComponent.dataSource}),
          config,
          netPaths,
          fileWriter,
        );

        final featurePath = netPaths.featurePath('auth');
        expect(
          File(path.join(featurePath, 'domain/entities/auth.dart'))
              .existsSync(),
          isTrue,
          reason: 'dataSource resolves entity',
        );
        for (final unexpected in [
          'domain/repositories/auth_repository.dart',
          'domain/usecases/auth_usecase.dart',
          'presentation/pages/auth_page.dart',
          'presentation/widgets/auth_widget.dart',
        ]) {
          expect(
            File(path.join(featurePath, unexpected)).existsSync(),
            isFalse,
            reason: '$unexpected was not requested and has no dependency '
                'reason to exist',
          );
        }
        expect(
          Directory(path.join(netPaths.test, 'features')).existsSync(),
          isFalse,
        );
      });

      // Network no longer varies service.dart's content (see above), so
      // a single config per architecture is enough to confirm the
      // service still coexists correctly with Riverpod's unconditional
      // ViewModel/Presenter + provider — no new state-management
      // dependency introduced.
      test(
          'MVVM + Riverpod + dataSource: NetworkService-backed service '
          'coexists with the unconditional ViewModel and Riverpod '
          'provider, no new state-management dependency introduced', () async {
        final dir = Directory.systemTemp.createTempSync('smartwork_net_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final netPaths = _paths(dir.path);

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.mvvm,
          stateManagement: StateManagement.riverpod,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(
              name: 'auth', components: {FeatureComponent.dataSource}),
          config,
          netPaths,
          fileWriter,
        );

        final featurePath = netPaths.featurePath('auth');
        final serviceContent =
            File(path.join(featurePath, 'services/auth_service.dart'))
                .readAsStringSync();
        expect(
            serviceContent, contains('services/network/network_service.dart'));
        expect(serviceContent, isNot(contains('package:http')));
        expect(serviceContent, isNot(contains('package:dio')));
        expect(
          File(path.join(featurePath, 'viewmodels/auth_view_model.dart'))
              .existsSync(),
          isTrue,
        );
        expect(
          File(path.join(featurePath, 'providers/auth_provider.dart'))
              .existsSync(),
          isTrue,
        );
        _verifyNoDanglingImportsOrPlaceholders(featurePath);
      });

      test(
          'MVP + Riverpod + dataSource: NetworkService-backed service '
          'coexists with the unconditional Presenter and Riverpod '
          'provider, no new state-management dependency introduced', () async {
        final dir = Directory.systemTemp.createTempSync('smartwork_net_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final netPaths = _paths(dir.path);

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.mvp,
          stateManagement: StateManagement.riverpod,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(
              name: 'auth', components: {FeatureComponent.dataSource}),
          config,
          netPaths,
          fileWriter,
        );

        final featurePath = netPaths.featurePath('auth');
        final serviceContent =
            File(path.join(featurePath, 'services/auth_service.dart'))
                .readAsStringSync();
        expect(
            serviceContent, contains('services/network/network_service.dart'));
        expect(serviceContent, isNot(contains('package:http')));
        expect(serviceContent, isNot(contains('package:dio')));
        expect(
          File(path.join(featurePath, 'presenters/auth_presenter.dart'))
              .existsSync(),
          isTrue,
        );
        expect(
          File(path.join(featurePath, 'providers/auth_provider.dart'))
              .existsSync(),
          isTrue,
        );
        _verifyNoDanglingImportsOrPlaceholders(featurePath);
      });

      test(
          'a feature without dataSource receives no network-specific '
          'files: network is not a project-wide "generate for every '
          'feature" switch', () async {
        final dir = Directory.systemTemp.createTempSync('smartwork_net_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final netPaths = _paths(dir.path);

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.dio,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth', components: {FeatureComponent.page}),
          config,
          netPaths,
          fileWriter,
        );

        final featurePath = netPaths.featurePath('auth');
        expect(
          File(path.join(
            featurePath,
            'data/datasources/auth_network_data_source.dart',
          )).existsSync(),
          isFalse,
        );
        expect(
          File(path.join(featurePath, 'data/datasources/auth_data_source.dart'))
              .existsSync(),
          isFalse,
        );
      });
    });

    group('storage integration', () {
      // Storage no longer varies per-feature generated content at all:
      // every local dataSource/service calls the project-level
      // StorageService (lib/services/storage/) uniformly, regardless of
      // ProjectConfig.storage — never package:shared_preferences/
      // package:hive_flutter directly. StorageService itself is what
      // actually varies by SharedPreferences/Hive/Other. This loop
      // confirms that provider-uniformity actually holds, for every
      // architecture and every Storage value, rather than assuming it.
      // Network and storage are independent project-level axes that are
      // always both configured, so both concrete realizations
      // (network/local) must coexist.
      for (final architecture in Architecture.values) {
        Future<String> generateAndReadContent(Storage storage) async {
          final dir = Directory.systemTemp.createTempSync('smartwork_storage_');
          addTearDown(() => dir.deleteSync(recursive: true));
          final storagePaths = _paths(dir.path);

          final config = ProjectConfig(
            projectName: 'demo_app',
            architecture: architecture,
            stateManagement: StateManagement.bloc,
            network: Network.http,
            storage: storage,
            initialFeatures: ['home'],
          );

          await FeatureGenerator().generate(
            FeatureConfig(
              name: 'auth',
              components: {FeatureComponent.dataSource},
            ),
            config,
            storagePaths,
            fileWriter,
          );

          final featurePath = storagePaths.featurePath('auth');
          final file = architecture == Architecture.cleanArchitecture
              ? File(path.join(
                  featurePath,
                  'data/datasources/auth_local_data_source.dart',
                ))
              : File(
                  path.join(featurePath, 'services/auth_local_service.dart'));
          _verifyNoDanglingImportsOrPlaceholders(featurePath);
          return file.readAsStringSync();
        }

        test(
            '$architecture: local dataSource calls StorageService '
            'uniformly, never package:shared_preferences/hive directly',
            () async {
          final contentToCheck =
              await generateAndReadContent(Storage.sharedPreferences);

          if (architecture == Architecture.cleanArchitecture) {
            expect(
              contentToCheck,
              contains('class AuthLocalDataSource implements '
                  'AuthDataSource'),
            );
          }
          expect(contentToCheck,
              contains('services/storage/storage_service.dart'));
          expect(contentToCheck,
              contains("await StorageService.instance.getString('auth')"));
          expect(contentToCheck, isNot(contains('package:shared_preferences')));
          expect(contentToCheck, isNot(contains('package:hive')));

          expect(
              contentToCheck, contains("import '../models/auth_model.dart';"));
          expect(contentToCheck, contains('return const AuthModel();'));
          expect(contentToCheck, isNot(contains('fromJson')));
          expect(contentToCheck, isNot(contains('toJson')));
          expect(contentToCheck, isNot(contains('TODO')),
              reason: 'the concrete Model return must not carry a '
                  'placeholder/TODO comment implying it is incomplete');
          expect(contentToCheck, isNot(contains('UnimplementedError')),
              reason: 'features never see Storage.other\'s stub shape — '
                  'that lives entirely inside StorageService');
        });

        test(
            '$architecture: local dataSource content is byte-identical '
            'regardless of ProjectConfig.storage (SharedPreferences/'
            'Hive/Other)', () async {
          final sharedPrefs =
              await generateAndReadContent(Storage.sharedPreferences);
          final hive = await generateAndReadContent(Storage.hive);
          final other = await generateAndReadContent(Storage.other);

          expect(hive, sharedPrefs);
          expect(other, sharedPrefs);
        });

        test(
            '$architecture: network and local data sources/services '
            'coexist as independent axes', () async {
          final dir = Directory.systemTemp.createTempSync('smartwork_storage_');
          addTearDown(() => dir.deleteSync(recursive: true));
          final storagePaths = _paths(dir.path);

          final config = ProjectConfig(
            projectName: 'demo_app',
            architecture: architecture,
            stateManagement: StateManagement.bloc,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: ['home'],
          );

          await FeatureGenerator().generate(
            FeatureConfig(
              name: 'auth',
              components: {FeatureComponent.dataSource},
            ),
            config,
            storagePaths,
            fileWriter,
          );

          final featurePath = storagePaths.featurePath('auth');
          if (architecture == Architecture.cleanArchitecture) {
            expect(
              File(path.join(featurePath,
                      'data/datasources/auth_local_data_source.dart'))
                  .existsSync(),
              isTrue,
            );
            expect(
              File(path.join(featurePath,
                      'data/datasources/auth_network_data_source.dart'))
                  .existsSync(),
              isTrue,
            );
          } else {
            expect(
              File(path.join(featurePath, 'services/auth_local_service.dart'))
                  .existsSync(),
              isTrue,
            );
            expect(
              File(path.join(featurePath, 'services/auth_service.dart'))
                  .existsSync(),
              isTrue,
            );
          }
        });
      }

      test(
          'a default (no explicit --components) feature resolves '
          'dataSource and generates the local storage file', () async {
        final dir = Directory.systemTemp.createTempSync('smartwork_storage_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final storagePaths = _paths(dir.path);

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.hive,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth'),
          config,
          storagePaths,
          fileWriter,
        );

        final featurePath = storagePaths.featurePath('auth');
        expect(
          File(path.join(
                  featurePath, 'data/datasources/auth_local_data_source.dart'))
              .existsSync(),
          isTrue,
          reason: 'standardComponents already includes dataSource',
        );
      });

      test(
          'a partial blueprint requesting only repository still resolves '
          'dataSource and generates the local storage file', () async {
        final dir = Directory.systemTemp.createTempSync('smartwork_storage_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final storagePaths = _paths(dir.path);

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(
              name: 'auth', components: {FeatureComponent.repository}),
          config,
          storagePaths,
          fileWriter,
        );

        final featurePath = storagePaths.featurePath('auth');
        expect(
          File(path.join(
                  featurePath, 'data/datasources/auth_local_data_source.dart'))
              .existsSync(),
          isTrue,
          reason: 'repository transitively resolves dataSource, which '
              'must also bring in the local storage realization',
        );
      });

      test(
          'a feature without dataSource receives no storage-specific '
          'files: storage is not a project-wide "generate for every '
          'feature" switch', () async {
        final dir = Directory.systemTemp.createTempSync('smartwork_storage_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final storagePaths = _paths(dir.path);

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.hive,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth', components: {FeatureComponent.page}),
          config,
          storagePaths,
          fileWriter,
        );

        final featurePath = storagePaths.featurePath('auth');
        expect(
          File(path.join(
                  featurePath, 'data/datasources/auth_local_data_source.dart'))
              .existsSync(),
          isFalse,
        );
      });

      // State-management independence: storage must not prevent, alter,
      // or collide with any state-management generator's own output.
      // State-management generators remain entirely storage-blind (no
      // change was made to any of BLoC/Cubit/GetX/Riverpod).
      for (final stateManagement in StateManagement.values) {
        test(
            '$stateManagement + storage: local data source coexists '
            'without breaking state-management generation', () async {
          final dir = Directory.systemTemp.createTempSync('smartwork_storage_');
          addTearDown(() => dir.deleteSync(recursive: true));
          final storagePaths = _paths(dir.path);

          final config = ProjectConfig(
            projectName: 'demo_app',
            architecture: Architecture.cleanArchitecture,
            stateManagement: stateManagement,
            network: Network.http,
            storage: Storage.hive,
            initialFeatures: ['home'],
          );

          await FeatureGenerator().generate(
            FeatureConfig(
                name: 'auth', components: {FeatureComponent.dataSource}),
            config,
            storagePaths,
            fileWriter,
          );

          final featurePath = storagePaths.featurePath('auth');
          expect(
            File(path.join(featurePath,
                    'data/datasources/auth_local_data_source.dart'))
                .existsSync(),
            isTrue,
          );

          switch (stateManagement) {
            case StateManagement.bloc:
              expect(
                File(path.join(featurePath, 'state/auth_bloc.dart'))
                    .existsSync(),
                isTrue,
              );
            case StateManagement.cubit:
              expect(
                File(path.join(featurePath, 'state/auth_cubit.dart'))
                    .existsSync(),
                isTrue,
              );
            case StateManagement.getx:
              expect(
                Directory(path.join(featurePath, 'presentation/getx'))
                    .existsSync(),
                isTrue,
              );
            case StateManagement.riverpod:
              expect(
                File(path.join(featurePath,
                        'presentation/providers/auth_provider.dart'))
                    .existsSync(),
                isTrue,
              );
          }

          _verifyNoDanglingImportsOrPlaceholders(featurePath);
        });
      }
    });

    group(
        'long feature names never produce a line dart format would '
        'rewrap (regression: a real "smartwork init" run with the '
        'E-Commerce/Food Delivery recommended feature list failed its '
        'Format validation phase because of this)', () {
      test(
          'Clean Architecture + BLoC, feature name "restaurant_listing" '
          '(the longest real recommended feature name)', () async {
        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['restaurant_listing'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'restaurant_listing'),
          config,
          paths,
          fileWriter,
        );

        final featurePath = paths.featurePath('restaurant_listing');
        final dartFiles = Directory(featurePath)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        for (final file in dartFiles) {
          for (final line in file.readAsStringSync().split('\n')) {
            expect(line.length, lessThanOrEqualTo(80),
                reason: '${file.path} has a line dart format would '
                    'rewrap, which fails the "smartwork init" Format '
                    'validation phase: "$line"');
          }
        }
      });
    });

    group('model foundation', () {
      // The Model already exists as part of FeatureComponent.entity (see
      // *Templates.modelTemplate()); this group pins down, explicitly,
      // the guarantees Network/Storage generation depends on: the Model
      // is concrete, field-free, and never carries serialization code —
      // and, for Clean, stays a distinct class/file from the Entity.
      for (final architecture in Architecture.values) {
        test(
            '$architecture: dataSource generates a concrete, field-free '
            'Model with no serialization code', () async {
          final dir = Directory.systemTemp.createTempSync('smartwork_model_');
          addTearDown(() => dir.deleteSync(recursive: true));
          final modelPaths = _paths(dir.path);

          final config = ProjectConfig(
            projectName: 'demo_app',
            architecture: architecture,
            stateManagement: StateManagement.bloc,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: ['home'],
          );

          await FeatureGenerator().generate(
            FeatureConfig(
                name: 'auth', components: {FeatureComponent.dataSource}),
            config,
            modelPaths,
            fileWriter,
          );

          final featurePath = modelPaths.featurePath('auth');
          final modelRelativePath =
              architecture == Architecture.cleanArchitecture
                  ? 'data/models/auth_model.dart'
                  : 'models/auth_model.dart';
          final modelFile = File(path.join(featurePath, modelRelativePath));
          expect(modelFile.existsSync(), isTrue,
              reason: 'dataSource resolves entity, which generates the '
                  'Model');

          final modelContent = modelFile.readAsStringSync();
          expect(modelContent, contains('class AuthModel'));
          expect(modelContent, isNot(contains('abstract class AuthModel')),
              reason: 'the Model must be concrete');
          expect(modelContent, contains('const AuthModel()'),
              reason: 'the Model must have a usable const constructor');
          expect(modelContent, isNot(contains('fromJson')));
          expect(modelContent, isNot(contains('toJson')));
          expect(modelContent, isNot(contains('copyWith')));
          expect(modelContent, isNot(contains('TODO')),
              reason: 'the Model file itself must carry no placeholder '
                  'comment');

          if (architecture == Architecture.cleanArchitecture) {
            // Entity (domain) and Model (data) remain separate classes
            // in separate files.
            final entityFile =
                File(path.join(featurePath, 'domain/entities/auth.dart'));
            expect(entityFile.existsSync(), isTrue);
            expect(modelContent, contains('class AuthModel extends Auth'));
            expect(entityFile.readAsStringSync(), isNot(contains('Model')),
                reason: 'the domain Entity must not itself reference the '
                    'data-layer Model');
          }

          _verifyNoDanglingImportsOrPlaceholders(featurePath);
        });
      }
    });

    group('feature export and import cleanup (Project Structure V1)', () {
      test(
          'Clean: the feature export barrel exists at <feature>.dart and '
          'exports exactly Entity, Model, and Page — via relative paths, '
          'never Repository/UseCase/DataSource internals', () async {
        final dir = Directory.systemTemp.createTempSync('smartwork_export_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final exportPaths = _paths(dir.path);

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth'),
          config,
          exportPaths,
          fileWriter,
        );

        final featurePath = exportPaths.featurePath('auth');
        final barrelFile = File(path.join(featurePath, 'auth.dart'));
        expect(barrelFile.existsSync(), isTrue);

        final content = barrelFile.readAsStringSync();
        expect(content, contains("export 'domain/entities/auth.dart';"));
        expect(content, contains("export 'data/models/auth_model.dart';"));
        expect(
            content, contains("export 'presentation/pages/auth_page.dart';"));
        expect(content, isNot(contains('package:')));
        for (final internalDetail in [
          'repositories/auth_repository.dart',
          'repositories/auth_repository_impl.dart',
          'usecases/auth_usecase.dart',
          'datasources/auth_data_source.dart',
          'datasources/auth_network_data_source.dart',
          'datasources/auth_local_data_source.dart',
        ]) {
          expect(content, isNot(contains(internalDetail)),
              reason: '$internalDetail is internal wiring, not public API');
        }
      });

      test(
          'MVVM and MVP: the feature export barrel exports exactly Model '
          'and Page — never the Service, ViewModel, or Presenter', () async {
        for (final architecture in [Architecture.mvvm, Architecture.mvp]) {
          final dir = Directory.systemTemp.createTempSync('smartwork_export_');
          addTearDown(() => dir.deleteSync(recursive: true));
          final exportPaths = _paths(dir.path);

          final config = ProjectConfig(
            projectName: 'demo_app',
            architecture: architecture,
            stateManagement: StateManagement.bloc,
            network: Network.http,
            storage: Storage.sharedPreferences,
            initialFeatures: ['home'],
          );

          await FeatureGenerator().generate(
            FeatureConfig(name: 'auth'),
            config,
            exportPaths,
            fileWriter,
          );

          final featurePath = exportPaths.featurePath('auth');
          final content =
              File(path.join(featurePath, 'auth.dart')).readAsStringSync();

          expect(content, contains("export 'models/auth_model.dart';"));
          expect(content, contains("export 'views/auth_page.dart';"));
          expect(content, isNot(contains('package:')));
          expect(content, isNot(contains('services/')),
              reason: 'the network/storage service is internal wiring');
          expect(
            content,
            isNot(contains(architecture == Architecture.mvvm
                ? 'viewmodels/'
                : 'presenters/')),
            reason: 'the unconditional ViewModel/Presenter is internal, '
                'not part of the exported public surface',
          );
        }
      });

      test(
          'a feature blueprint that generates neither Entity/Model nor '
          'Page (only widgets) still gets a barrel file, just an empty '
          'one — never referencing a file that was not generated', () async {
        final dir = Directory.systemTemp.createTempSync('smartwork_export_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final exportPaths = _paths(dir.path);

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth', components: {FeatureComponent.widgets}),
          config,
          exportPaths,
          fileWriter,
        );

        final featurePath = exportPaths.featurePath('auth');
        final barrelFile = File(path.join(featurePath, 'auth.dart'));
        expect(barrelFile.existsSync(), isTrue,
            reason: 'the barrel is unconditional, like ViewModel/Presenter');
        expect(barrelFile.readAsStringSync().trim(), isEmpty);
      });

      test(
          'requesting only page excludes Entity/Model from the barrel; '
          'requesting only entity excludes Page', () async {
        final dir = Directory.systemTemp.createTempSync('smartwork_export_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final exportPaths = _paths(dir.path);

        final config = ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth', components: {FeatureComponent.page}),
          config,
          exportPaths,
          fileWriter,
        );
        final pageOnlyBarrel =
            File(path.join(exportPaths.featurePath('auth'), 'auth.dart'))
                .readAsStringSync();
        expect(pageOnlyBarrel,
            contains("export 'presentation/pages/auth_page.dart';"));
        expect(pageOnlyBarrel, isNot(contains('entities')));
        expect(pageOnlyBarrel, isNot(contains('models')));

        final dir2 = Directory.systemTemp.createTempSync('smartwork_export_');
        addTearDown(() => dir2.deleteSync(recursive: true));
        final exportPaths2 = _paths(dir2.path);
        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth', components: {FeatureComponent.entity}),
          config,
          exportPaths2,
          fileWriter,
        );
        final entityOnlyBarrel =
            File(path.join(exportPaths2.featurePath('auth'), 'auth.dart'))
                .readAsStringSync();
        expect(
            entityOnlyBarrel, contains("export 'domain/entities/auth.dart';"));
        expect(entityOnlyBarrel,
            contains("export 'data/models/auth_model.dart';"));
        expect(entityOnlyBarrel, isNot(contains('pages')));
      });

      test(
          'no generated lib/ file contains a package:<projectName>/ '
          'internal import, across every architecture x network x '
          'storage combination — only third-party package imports '
          'remain', () async {
        for (final architecture in Architecture.values) {
          for (final network in Network.values) {
            for (final storage in Storage.values) {
              final dir =
                  Directory.systemTemp.createTempSync('smartwork_export_');
              addTearDown(() => dir.deleteSync(recursive: true));
              final combPaths = _paths(dir.path);

              final config = ProjectConfig(
                projectName: 'demo_app',
                architecture: architecture,
                stateManagement: StateManagement.bloc,
                network: network,
                storage: storage,
                initialFeatures: ['home'],
              );

              await FeatureGenerator().generate(
                FeatureConfig(name: 'auth'),
                config,
                combPaths,
                fileWriter,
              );

              final dartFiles = Directory(combPaths.lib)
                  .listSync(recursive: true)
                  .whereType<File>()
                  .where((f) => f.path.endsWith('.dart'));
              for (final file in dartFiles) {
                final content = file.readAsStringSync();
                expect(content, isNot(contains('package:demo_app')),
                    reason: '${file.path} has an internal package: import '
                        '($architecture + $network + $storage)');
                // Third-party imports remain untouched.
                switch (network) {
                  case Network.http:
                    expect(content, isNot(contains('package:dio')));
                  case Network.dio:
                    // http.Client only appears in the http variant;
                    // nothing to assert for dio's own file here.
                    break;
                  case Network.other:
                    expect(content, isNot(contains('package:http')));
                    expect(content, isNot(contains('package:dio')));
                }
              }
            }
          }
        }
      });

      test(
          'package-name independence: an unusual, non-default project '
          'name never leaks into any internal generated import', () async {
        final dir = Directory.systemTemp.createTempSync('smartwork_export_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final oddPaths = _paths(dir.path);

        const oddProjectName = 'zephyr_quokka_ledger';
        final config = ProjectConfig(
          projectName: oddProjectName,
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.riverpod,
          network: Network.dio,
          storage: Storage.hive,
          initialFeatures: ['home'],
        );

        await FeatureGenerator().generate(
          FeatureConfig(name: 'auth'),
          config,
          oddPaths,
          fileWriter,
        );

        final dartFiles = Directory(oddPaths.lib)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));
        for (final file in dartFiles) {
          final content = file.readAsStringSync();
          expect(content, isNot(contains(oddProjectName)),
              reason: '${file.path} must not reference the project '
                  'package name at all');
          expect(content, isNot(contains('package:$oddProjectName')));
        }
      });
    });
  });
}

/// Constructs [ProjectPaths] rooted at [projectRoot] and pre-creates the
/// project-level services generated Network/Storage data sources import
/// (`NetworkService`/`StorageService` — see
/// `CleanArchitectureTemplates.networkDataSourceTemplate`/
/// `localDataSourceTemplate`, and MVVM/MVP's equivalents), so any
/// fixture that generates a feature in isolation — without running the
/// full `ProjectGenerator`, which writes `lib/services/` first — needs
/// them created here instead, matching what a real project already has
/// on disk before any feature is generated.
ProjectPaths _paths(String projectRoot) {
  final paths = ProjectPaths(projectRoot: projectRoot);
  final networkFile = File(paths.servicesNetworkServiceFile);
  networkFile.parent.createSync(recursive: true);
  networkFile.writeAsStringSync('class NetworkService {}\n');
  final storageFile = File(paths.servicesStorageServiceFile);
  storageFile.parent.createSync(recursive: true);
  storageFile.writeAsStringSync('class StorageService {}\n');
  return paths;
}

/// Asserts every `.dart` file under [featurePath] has no unresolved
/// `{{...}}` placeholders and that every local (relative) import it
/// contains points to a file that actually exists — the generation
/// contract dependency resolution exists to guarantee.
void _verifyNoDanglingImportsOrPlaceholders(String featurePath) {
  final dartFiles = Directory(featurePath)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in dartFiles) {
    final content = file.readAsStringSync();
    expect(content, isNot(contains('{{')),
        reason: '${file.path} has an unresolved placeholder');

    for (final match in RegExp(r"import '(\.\./[^']+|[a-z_]+\.dart)';")
        .allMatches(content)) {
      final importPath = match.group(1)!;
      final resolvedImport =
          path.normalize(path.join(file.parent.path, importPath));
      expect(
        File(resolvedImport).existsSync(),
        isTrue,
        reason: '${file.path} imports $importPath which does not exist',
      );
    }
  }
}
