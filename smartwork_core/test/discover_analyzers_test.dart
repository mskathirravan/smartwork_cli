import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

ProjectScanResult _scan({
  Map<String, dynamic>? pubspecYaml,
  Map<String, String> dartFiles = const {},
}) =>
    ProjectScanResult(
      projectPath: '/fake/project',
      pubspecYaml: pubspecYaml,
      dartFiles: dartFiles,
    );

void main() {
  group('DependencyAnalyzer', () {
    test('reads dependencies and dev_dependencies as declared facts', () {
      final result = DependencyAnalyzer().analyze(_scan(pubspecYaml: {
        'dependencies': {'flutter_bloc': '^9.1.1', 'http': '^1.6.0'},
        'dev_dependencies': {'test': '^1.24.0'},
      }));

      expect(result.confidence, DiscoveryConfidence.declared);
      expect(result.value, hasLength(3));
      expect(
        result.value.firstWhere((d) => d.name == 'flutter_bloc').isDev,
        isFalse,
      );
      expect(result.value.firstWhere((d) => d.name == 'test').isDev, isTrue);
    });

    test('renders an {sdk: flutter}-shaped dependency honestly', () {
      final result = DependencyAnalyzer().analyze(_scan(pubspecYaml: {
        'dependencies': {
          'flutter': {'sdk': 'flutter'},
        },
      }));

      expect(result.value.single.versionConstraint, contains('sdk'));
      expect(result.value.single.versionConstraint, contains('flutter'));
    });

    test('reports unknown confidence when pubspec.yaml is missing', () {
      final result = DependencyAnalyzer().analyze(_scan());
      expect(result.confidence, DiscoveryConfidence.unknown);
      expect(result.value, isEmpty);
    });

    test(
        'an empty but present dependencies section is still declared, '
        'not unknown', () {
      final result = DependencyAnalyzer().analyze(_scan(pubspecYaml: {}));
      expect(result.confidence, DiscoveryConfidence.declared);
      expect(result.value, isEmpty);
    });
  });

  group('StateManagementAnalyzer', () {
    test(
        'distinguishes Bloc from Cubit even though both declare the '
        'identical flutter_bloc dependency', () {
      final blocResult = StateManagementAnalyzer().analyze(_scan(
        pubspecYaml: {
          'dependencies': {'flutter_bloc': '^9.1.1'},
        },
        dartFiles: {
          'lib/features/profile/state/profile_bloc.dart':
              'class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {}',
        },
      ));
      expect(blocResult.value, StateManagement.bloc);
      expect(blocResult.confidence, DiscoveryConfidence.detected);

      final cubitResult = StateManagementAnalyzer().analyze(_scan(
        pubspecYaml: {
          'dependencies': {'flutter_bloc': '^9.1.1'},
        },
        dartFiles: {
          'lib/features/profile/state/profile_cubit.dart':
              'class ProfileCubit extends Cubit<ProfileState> {}',
        },
      ));
      expect(cubitResult.value, StateManagement.cubit);
      expect(cubitResult.confidence, DiscoveryConfidence.detected);
    });

    test(
        'a declared flutter_bloc dependency with no class evidence is '
        'inferred, never detected, and never guesses bloc vs cubit', () {
      final result = StateManagementAnalyzer().analyze(_scan(pubspecYaml: {
        'dependencies': {'flutter_bloc': '^9.1.1'},
      }));

      expect(result.value, isNull);
      expect(result.confidence, DiscoveryConfidence.inferred);
      expect(result.evidence.single, contains('cannot distinguish'));
    });

    test(
        'GetX evidence found only in lib/features/debug/ is still '
        'detected — the whole lib/ tree is searched, debug/ is never '
        'excluded', () {
      final result = StateManagementAnalyzer().analyze(_scan(
        pubspecYaml: {
          'dependencies': {'get': '^4.7.2'},
        },
        dartFiles: {
          'lib/features/profile/presenters/profile_presenter.dart':
              'class ProfilePresenter { bool isLoading = false; }',
          'lib/features/debug/presenters/debug_presenter.dart':
              'class DebugPresenter extends GetxController {}',
        },
      ));

      expect(result.value, StateManagement.getx);
      expect(result.confidence, DiscoveryConfidence.detected);
      expect(result.evidence.single, contains('debug'));
    });

    test('real Riverpod usage is detected', () {
      final result = StateManagementAnalyzer().analyze(_scan(
        pubspecYaml: {
          'dependencies': {'riverpod': '^3.4.3'},
        },
        dartFiles: {
          'lib/features/profile/providers/profile_provider.dart':
              'class ProfileNotifier extends StateNotifier<ProfileState> {}',
        },
      ));

      expect(result.value, StateManagement.riverpod);
      expect(result.confidence, DiscoveryConfidence.detected);
    });

    test(
        'no dependency and no usage evidence at all is unknown, never '
        '"none"', () {
      final result = StateManagementAnalyzer().analyze(_scan());
      expect(result.value, isNull);
      expect(result.confidence, DiscoveryConfidence.unknown);
    });
  });

  group('ArchitectureAnalyzer', () {
    test(
        'Clean Architecture requires import-direction evidence, not '
        'just data/+domain/ folders', () {
      final withImportEvidence = ArchitectureAnalyzer().analyze(_scan(
        dartFiles: {
          'lib/features/profile/domain/entities/profile.dart':
              'class Profile {}',
          'lib/features/profile/domain/repositories/profile_repository.dart':
              "import '../entities/profile.dart';\nabstract class ProfileRepository {}",
          'lib/features/profile/data/repositories/profile_repository_impl.dart':
              "import '../../domain/entities/profile.dart';\nimport '../../domain/repositories/profile_repository.dart';\nclass ProfileRepositoryImpl {}",
        },
      ));
      expect(withImportEvidence.value, Architecture.cleanArchitecture);
      expect(withImportEvidence.confidence, DiscoveryConfidence.detected);

      final folderOnly = ArchitectureAnalyzer().analyze(_scan(
        dartFiles: {
          'lib/features/profile/domain/entities/profile.dart':
              'class Profile {}',
          'lib/features/profile/data/repositories/profile_repository_impl.dart':
              'class ProfileRepositoryImpl {}',
        },
      ));
      expect(folderOnly.value, Architecture.cleanArchitecture);
      expect(folderOnly.confidence, DiscoveryConfidence.inferred);
    });

    test(
        'domain/ importing data/ or presentation/ breaks Clean '
        'detection down to inferred', () {
      final result = ArchitectureAnalyzer().analyze(_scan(
        dartFiles: {
          'lib/features/profile/domain/entities/profile.dart':
              "import '../../data/models/profile_model.dart';\nclass Profile {}",
          'lib/features/profile/data/models/profile_model.dart':
              'class ProfileModel {}',
        },
      ));
      expect(result.confidence, DiscoveryConfidence.inferred);
    });

    test('MVVM shape (viewmodels/+views/, no domain/) is detected', () {
      final result = ArchitectureAnalyzer().analyze(_scan(
        dartFiles: {
          'lib/features/profile/viewmodels/profile_view_model.dart':
              'class ProfileViewModel {}',
          'lib/features/profile/views/profile_page.dart':
              'class ProfilePage {}',
        },
      ));
      expect(result.value, Architecture.mvvm);
      expect(result.confidence, DiscoveryConfidence.detected);
    });

    test('MVP shape (presenters/+views/, no domain/) is detected', () {
      final result = ArchitectureAnalyzer().analyze(_scan(
        dartFiles: {
          'lib/features/profile/presenters/profile_presenter.dart':
              'class ProfilePresenter {}',
          'lib/features/profile/views/profile_page.dart':
              'class ProfilePage {}',
        },
      ));
      expect(result.value, Architecture.mvp);
      expect(result.confidence, DiscoveryConfidence.detected);
    });

    test(
        'mixed architecture across features never guesses a majority — '
        'reports project-level unknown and preserves per-feature '
        'evidence', () {
      final result = ArchitectureAnalyzer().analyze(_scan(
        dartFiles: {
          'lib/features/profile/viewmodels/profile_view_model.dart':
              'class ProfileViewModel {}',
          'lib/features/profile/views/profile_page.dart':
              'class ProfilePage {}',
          'lib/features/settings/presenters/settings_presenter.dart':
              'class SettingsPresenter {}',
          'lib/features/settings/views/settings_page.dart':
              'class SettingsPage {}',
        },
      ));

      expect(result.value, isNull);
      expect(result.confidence, DiscoveryConfidence.unknown);
      expect(result.evidence.any((e) => e.contains('profile')), isTrue);
      expect(result.evidence.any((e) => e.contains('settings')), isTrue);
    });

    test('no lib/features/ folders at all is unknown', () {
      final result = ArchitectureAnalyzer().analyze(_scan());
      expect(result.value, isNull);
      expect(result.confidence, DiscoveryConfidence.unknown);
    });
  });

  group('DependencyInjectionAnalyzer', () {
    test('recognizes SmartWork\'s own static-singleton convention', () {
      final result = DependencyInjectionAnalyzer().analyze(_scan(
        dartFiles: {
          'lib/services/network/network_service.dart': 'class NetworkService {\n'
              '  static final NetworkService instance = NetworkService._();\n'
              '}',
        },
      ));

      expect(result.value, DependencyInjectionKind.staticSingleton);
      expect(result.confidence, DiscoveryConfidence.detected);
    });

    test(
        'a declared get_it dependency with zero usage stays inferred, '
        'never confirmed', () {
      final result = DependencyInjectionAnalyzer().analyze(_scan(
        pubspecYaml: {
          'dependencies': {'get_it': '^7.0.0'},
        },
      ));

      expect(result.value, DependencyInjectionKind.getIt);
      expect(result.confidence, DiscoveryConfidence.inferred);
    });

    test('real GetIt usage is detected', () {
      final result = DependencyInjectionAnalyzer().analyze(_scan(
        dartFiles: {
          'lib/main.dart': 'void main() { GetIt.instance.get<Foo>(); }',
        },
      ));

      expect(result.value, DependencyInjectionKind.getIt);
      expect(result.confidence, DiscoveryConfidence.detected);
    });

    test(
        'real GetX service-locator usage (Get.find</Get.put<) is '
        'detected', () {
      final result = DependencyInjectionAnalyzer().analyze(_scan(
        dartFiles: {
          'lib/main.dart': 'void main() { Get.put<Foo>(Foo()); }',
        },
      ));

      expect(result.value, DependencyInjectionKind.getXServiceLocator);
      expect(result.confidence, DiscoveryConfidence.detected);
    });

    test('no evidence at all is none/unknown', () {
      final result = DependencyInjectionAnalyzer().analyze(_scan());
      expect(result.value, DependencyInjectionKind.none);
      expect(result.confidence, DiscoveryConfidence.unknown);
    });
  });

  group('FeatureAnalyzer', () {
    test(
        'detects component roles under lib/features/<name>/ at '
        'detected confidence', () {
      final result = FeatureAnalyzer().analyze(_scan(dartFiles: {
        'lib/features/profile/domain/entities/profile.dart': '',
        'lib/features/profile/data/repositories/profile_repository_impl.dart':
            '',
        'lib/features/profile/presentation/pages/profile_page.dart': '',
        'test/features/profile/profile_test.dart': '',
      }));

      expect(result.confidence, DiscoveryConfidence.detected);
      final profile = result.value.single;
      expect(profile.name, 'profile');
      expect(profile.components, contains(FeatureComponent.entity));
      expect(profile.components, contains(FeatureComponent.repository));
      expect(profile.components, contains(FeatureComponent.page));
      expect(profile.components, contains(FeatureComponent.tests));
    });

    test(
        'a lib/modules/<name>/ fallback is recognized at inferred '
        'confidence, never as strong as lib/features/', () {
      final result = FeatureAnalyzer().analyze(_scan(dartFiles: {
        'lib/modules/profile/profile_page.dart': '',
      }));

      expect(result.confidence, DiscoveryConfidence.inferred);
      expect(result.value.single.name, 'profile');
    });

    test('a type-first layout never becomes a fabricated feature list', () {
      final result = FeatureAnalyzer().analyze(_scan(dartFiles: {
        'lib/blocs/profile_bloc.dart': '',
        'lib/screens/profile_screen.dart': '',
      }));

      expect(result.value, isEmpty);
      expect(result.confidence, DiscoveryConfidence.unknown);
    });

    test(
        'multiple features are always reported in a deterministic '
        '(alphabetical) order — never whatever order the filesystem '
        'happened to enumerate them in, since Directory.list() gives no '
        'ordering guarantee at all', () {
      // Deliberately declared out of alphabetical order in the fixture
      // itself, so this test would fail if the analyzer merely preserved
      // Map/Directory.list() iteration order instead of actually sorting.
      final result = FeatureAnalyzer().analyze(_scan(dartFiles: {
        'lib/features/zebra/zebra_page.dart': '',
        'lib/features/apple/apple_page.dart': '',
        'lib/features/mango/mango_page.dart': '',
      }));

      expect(
        result.value.map((f) => f.name).toList(),
        ['apple', 'mango', 'zebra'],
      );
    });

    test(
        'a single feature\'s own file-level evidence is also '
        'deterministically ordered', () {
      final result = FeatureAnalyzer().analyze(_scan(dartFiles: {
        'lib/features/profile/presentation/pages/profile_page.dart': '',
        'lib/features/profile/data/repositories/profile_repository_impl.dart':
            '',
        'lib/features/profile/domain/entities/profile.dart': '',
      }));

      final evidence = result.value.single.evidence;
      expect(evidence, [
        'lib/features/profile/data/repositories/profile_repository_impl.dart: repository',
        'lib/features/profile/domain/entities/profile.dart: entity',
        'lib/features/profile/presentation/pages/profile_page.dart: page',
      ]);
    });

    test(
        'lib/modules/<name>/ fallback features are also alphabetically '
        'ordered', () {
      final result = FeatureAnalyzer().analyze(_scan(dartFiles: {
        'lib/modules/zebra/zebra_page.dart': '',
        'lib/modules/apple/apple_page.dart': '',
      }));

      expect(
        result.value.map((f) => f.name).toList(),
        ['apple', 'zebra'],
      );
    });
  });

  group('TestAnalyzer', () {
    test('detects real test()/testWidgets()/group() calls', () {
      final result = TestAnalyzer().analyze(_scan(
        pubspecYaml: {
          'dev_dependencies': {'flutter_test': 'any'},
        },
        dartFiles: {
          'test/features/profile/profile_test.dart':
              "void main() { test('does a thing', () {}); }",
        },
      ));

      expect(result.value.hasTestDirectory, isTrue);
      expect(result.value.hasDetectedTestCalls, isTrue);
      expect(result.value.declaredTestingPackages, contains('flutter_test'));
      expect(result.confidence, DiscoveryConfidence.detected);
    });

    test(
        'a declared testing package with no real test calls is '
        'declared, not detected', () {
      final result = TestAnalyzer().analyze(_scan(
        pubspecYaml: {
          'dev_dependencies': {'flutter_test': 'any'},
        },
        dartFiles: {
          'test/features/profile/profile_test.dart': '// nothing yet',
        },
      ));

      expect(result.value.hasDetectedTestCalls, isFalse);
      expect(result.confidence, DiscoveryConfidence.declared);
    });

    test(
        'reports whether test/ mirrors every feature under '
        'lib/features/', () {
      final mirrored = TestAnalyzer().analyze(_scan(dartFiles: {
        'lib/features/profile/page.dart': '',
        'test/features/profile/profile_test.dart': '',
      }));
      expect(mirrored.value.mirrorsFeatureStructure, isTrue);

      final notMirrored = TestAnalyzer().analyze(_scan(dartFiles: {
        'lib/features/profile/page.dart': '',
        'lib/features/settings/page.dart': '',
        'test/features/profile/profile_test.dart': '',
      }));
      expect(notMirrored.value.mirrorsFeatureStructure, isFalse);
    });

    test('no test directory and no testing dependency is unknown', () {
      final result = TestAnalyzer().analyze(_scan());
      expect(result.value.hasTestDirectory, isFalse);
      expect(result.confidence, DiscoveryConfidence.unknown);
    });
  });
}
