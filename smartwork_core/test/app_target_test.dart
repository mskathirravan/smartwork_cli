import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// [AppTarget] is one of the six real Flutter platforms a project can be
/// built for (`android`, `ios`, `web`, `windows`, `macos`, `linux`) —
/// this milestone's replacement for the earlier single mobile/desktop/
/// both UI-responsiveness choice. These tests cover the enum itself, its
/// platform/display-name mapping, `ProjectConfig.appTargets` (default,
/// serialization, deterministic ordering, backward-compatible
/// deserialization), [AppTargetSelection] parsing, [TargetChangePlan]
/// computation, and generated documentation.
void main() {
  group('AppTarget', () {
    test('has exactly the six expected values, in menu/display order', () {
      expect(AppTarget.values, [
        AppTarget.android,
        AppTarget.ios,
        AppTarget.web,
        AppTarget.windows,
        AppTarget.macos,
        AppTarget.linux,
      ]);
    });

    test(
        'platformFolder maps each target to its real Flutter platform '
        'folder name', () {
      expect(AppTarget.android.platformFolder, 'android');
      expect(AppTarget.ios.platformFolder, 'ios');
      expect(AppTarget.web.platformFolder, 'web');
      expect(AppTarget.windows.platformFolder, 'windows');
      expect(AppTarget.macos.platformFolder, 'macos');
      expect(AppTarget.linux.platformFolder, 'linux');
    });

    test(
        'displayName is human-readable, with iOS/macOS capitalized '
        'correctly', () {
      expect(AppTarget.android.displayName, 'Android');
      expect(AppTarget.ios.displayName, 'iOS');
      expect(AppTarget.web.displayName, 'Web');
      expect(AppTarget.windows.displayName, 'Windows');
      expect(AppTarget.macos.displayName, 'macOS');
      expect(AppTarget.linux.displayName, 'Linux');
    });
  });

  group('ProjectConfig.appTargets', () {
    ProjectConfig baseConfig({Set<AppTarget>? appTargets}) {
      return ProjectConfig(
        projectName: 'demo_app',
        appTargets: appTargets,
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );
    }

    test('defaults to Android + iOS when not specified', () {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );

      expect(config.appTargets, {AppTarget.android, AppTarget.ios});
    });

    test('accepts every single target explicitly', () {
      for (final target in AppTarget.values) {
        expect(baseConfig(appTargets: {target}).appTargets, {target});
      }
    });

    test('accepts an arbitrary multi-target combination', () {
      final config = baseConfig(appTargets: {AppTarget.android, AppTarget.web});
      expect(
        config.appTargets,
        unorderedEquals({AppTarget.android, AppTarget.web}),
      );
    });

    test(
        'orderedAppTargets is always in AppTarget.values declaration '
        'order, regardless of selection/insertion order', () {
      final config = baseConfig(
        appTargets: {AppTarget.linux, AppTarget.android, AppTarget.macos},
      );

      expect(config.orderedAppTargets,
          [AppTarget.android, AppTarget.macos, AppTarget.linux]);
    });

    test(
        'toYaml round-trips every single AppTarget value through '
        'fromYaml', () {
      for (final target in AppTarget.values) {
        final config = baseConfig(appTargets: {target});
        final restored = ProjectConfig.fromYaml(config.toYaml());
        expect(restored.appTargets, {target});
      }
    });

    test('toYaml round-trips a multi-target selection through fromYaml', () {
      final config = baseConfig(
        appTargets: {AppTarget.android, AppTarget.ios, AppTarget.web},
      );

      final restored = ProjectConfig.fromYaml(config.toYaml());

      expect(
        restored.appTargets,
        unorderedEquals({AppTarget.android, AppTarget.ios, AppTarget.web}),
      );
    });

    test(
        'toYaml serializes appTargets as a deterministically ordered '
        'list of plain enum names', () {
      final yaml = baseConfig(
        appTargets: {AppTarget.macos, AppTarget.android, AppTarget.web},
      ).toYaml();

      expect(yaml['appTargets'], ['android', 'web', 'macos']);
    });

    test(
        'fromYaml falls back to all six targets when appTargets is '
        'entirely absent — backward compatibility with a project.yaml '
        'written before multi-target AppTargets existed (whether it has '
        'no AppTarget field at all, or the old singular appTarget: '
        'mobile/desktop/both field, every platform folder already '
        'exists on disk for such a project, so this is the only '
        'accurate reading)', () {
      final yaml = baseConfig().toYaml()..remove('appTargets');

      final restored = ProjectConfig.fromYaml(yaml);

      expect(restored.appTargets, unorderedEquals(AppTarget.values));
    });

    test(
        'fromYaml falls back to all six targets when only the legacy '
        'singular appTarget field is present', () {
      final yaml = baseConfig().toYaml()
        ..remove('appTargets')
        ..['appTarget'] = 'both';

      final restored = ProjectConfig.fromYaml(yaml);

      expect(restored.appTargets, unorderedEquals(AppTarget.values));
    });

    test(
        'fromYaml never invents a target when appTargets is explicitly '
        'present, even if it is an empty list', () {
      final yaml = baseConfig().toYaml()..['appTargets'] = <String>[];

      final restored = ProjectConfig.fromYaml(yaml);

      expect(restored.appTargets, isEmpty);
    });
  });

  group('ConfigValidator: appTargets', () {
    ProjectConfig configWith(Set<AppTarget> appTargets) {
      return ProjectConfig(
        projectName: 'demo_app',
        appTargets: appTargets,
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );
    }

    test('rejects an empty App Target selection', () {
      final errors = ConfigValidator.validate(configWith({}));

      expect(
        errors.map((e) => e.toString()),
        contains('At least one App Target is required'),
      );
    });

    test('accepts a single App Target', () {
      final errors = ConfigValidator.validate(configWith({AppTarget.web}));

      expect(
        errors.map((e) => e.toString()),
        isNot(contains('At least one App Target is required')),
      );
    });
  });

  group('AppTargetSelection.parse', () {
    test('parses a single selection', () {
      expect(AppTargetSelection.parse('1'), {AppTarget.android});
    });

    test('parses multiple selections', () {
      expect(
        AppTargetSelection.parse('1,2'),
        {AppTarget.android, AppTarget.ios},
      );
    });

    test('parses all six selections', () {
      expect(AppTargetSelection.parse('1,2,3,4,5,6'),
          unorderedEquals(AppTarget.values));
    });

    test('tolerates surrounding whitespace around tokens', () {
      expect(
        AppTargetSelection.parse(' 1 , 3 '),
        {AppTarget.android, AppTarget.web},
      );
    });

    test('rejects an empty selection', () {
      expect(
        () => AppTargetSelection.parse(''),
        throwsA(isA<InvalidAppTargetSelectionException>()),
      );
      expect(
        () => AppTargetSelection.parse('   '),
        throwsA(isA<InvalidAppTargetSelectionException>()),
      );
    });

    test('rejects a non-numeric token', () {
      expect(
        () => AppTargetSelection.parse('1,x'),
        throwsA(isA<InvalidAppTargetSelectionException>()),
      );
    });

    test('rejects a number outside 1-6', () {
      expect(
        () => AppTargetSelection.parse('0'),
        throwsA(isA<InvalidAppTargetSelectionException>()),
      );
      expect(
        () => AppTargetSelection.parse('7'),
        throwsA(isA<InvalidAppTargetSelectionException>()),
      );
    });

    test('normalizes a duplicate selection rather than rejecting it', () {
      expect(AppTargetSelection.parse('1,1'), {AppTarget.android});
      expect(
        AppTargetSelection.parse('1,1,2,2'),
        {AppTarget.android, AppTarget.ios},
      );
    });

    test('exception messages are printable, non-empty strings', () {
      try {
        AppTargetSelection.parse('');
        fail('expected an exception');
      } on InvalidAppTargetSelectionException catch (e) {
        expect(e.toString(), isNotEmpty);
      }
    });
  });

  group('TargetChangePlan.compute', () {
    test('added is everything in requested but not current', () {
      final plan = TargetChangePlan.compute(
        current: {AppTarget.android, AppTarget.ios},
        requested: {AppTarget.android, AppTarget.ios, AppTarget.web},
      );

      expect(plan.added, {AppTarget.web});
      expect(plan.removedFromConfig, isEmpty);
      expect(plan.hasChanges, isTrue);
    });

    test('removedFromConfig is everything in current but not requested', () {
      final plan = TargetChangePlan.compute(
        current: {AppTarget.android, AppTarget.ios, AppTarget.web},
        requested: {AppTarget.android},
      );

      expect(plan.added, isEmpty);
      expect(plan.removedFromConfig, {AppTarget.ios, AppTarget.web});
      expect(plan.hasChanges, isTrue);
    });

    test('an identical selection has no changes', () {
      final plan = TargetChangePlan.compute(
        current: {AppTarget.android, AppTarget.ios},
        requested: {AppTarget.ios, AppTarget.android},
      );

      expect(plan.added, isEmpty);
      expect(plan.removedFromConfig, isEmpty);
      expect(plan.hasChanges, isFalse);
    });

    test('ordered getters follow AppTarget.values declaration order', () {
      final plan = TargetChangePlan.compute(
        current: {AppTarget.linux, AppTarget.android},
        requested: {AppTarget.macos, AppTarget.ios},
      );

      expect(plan.orderedCurrent, [AppTarget.android, AppTarget.linux]);
      expect(plan.orderedRequested, [AppTarget.ios, AppTarget.macos]);
      expect(plan.orderedAdded, [AppTarget.ios, AppTarget.macos]);
      expect(
          plan.orderedRemovedFromConfig, [AppTarget.android, AppTarget.linux]);
    });
  });

  group('AppTarget in generated documentation', () {
    ProjectConfig configFor(Set<AppTarget> targets) {
      return ProjectConfig(
        projectName: 'demo_app',
        appTargets: targets,
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['auth'],
      );
    }

    test('documents an Application Targets section', () {
      final content = ProjectDocumentationGenerator()
              .generateAll(configFor({AppTarget.android, AppTarget.ios}))[
          'docs/architecture.md']!;

      expect(content, contains('Application Targets'));
    });

    test(
        'lists only the selected targets, never an unselected one as '
        'active', () {
      final content = ProjectDocumentationGenerator()
              .generateAll(configFor({AppTarget.android, AppTarget.web}))[
          'docs/architecture.md']!;

      expect(content, contains('- Android'));
      expect(content, contains('- Web'));
      expect(content, isNot(contains('- iOS')));
      expect(content, isNot(contains('- Windows')));
      expect(content, isNot(contains('- macOS')));
      expect(content, isNot(contains('- Linux')));
    });

    test(
        'touch-only targets (Android/iOS) get single-column mobile '
        'guidance, with no adaptive LayoutBuilder advice', () {
      final content = ProjectDocumentationGenerator()
              .generateAll(configFor({AppTarget.android, AppTarget.ios}))[
          'docs/development.md']!;

      expect(content, contains('single-column'));
      expect(content, isNot(contains('LayoutBuilder')));
    });

    test(
        'pointer-only targets (Web/Windows/macOS/Linux) get wide/'
        'resizable guidance, with no adaptive LayoutBuilder advice', () {
      final content = ProjectDocumentationGenerator().generateAll(
        configFor({AppTarget.web, AppTarget.windows, AppTarget.macos}),
      )['docs/development.md']!;

      expect(content, contains('resizable'));
      expect(content, isNot(contains('LayoutBuilder')));
    });

    test(
        'mixing a touch and a pointer target triggers adaptive '
        'LayoutBuilder/MediaQuery guidance', () {
      final content = ProjectDocumentationGenerator()
              .generateAll(configFor({AppTarget.android, AppTarget.web}))[
          'docs/development.md']!;

      expect(content, contains('LayoutBuilder'));
      expect(content, contains('MediaQuery'));
    });

    test(
        'mentions the real Flutter platform folder names alongside the '
        'App Targets section, with no SmartWork command reference', () {
      final content = ProjectDocumentationGenerator()
              .generateAll(configFor(Set<AppTarget>.from(AppTarget.values)))[
          'docs/architecture.md']!;

      expect(content, contains('android/'));
      expect(content, contains('ios/'));
      expect(content, isNot(contains('smartwork target')));
      expect(content, isNot(contains('SmartWork')));
    });
  });
}
