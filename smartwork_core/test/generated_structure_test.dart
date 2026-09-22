import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

/// V1 Architecture Final Audit: a dedicated, whole-project structural
/// check that the generated `lib/` tree has exactly the top-level
/// pieces the architecture requires — `core/`, `services/`, `features/`,
/// plus `main.dart` — and that Bootstrap/Routing/Debug live at their
/// final locations, never their pre-V1-Final-Architecture ones.
///
/// V1.1-2 (Shared UI) added a fourth, equally narrow top-level piece,
/// `shared/` (currently just `shared/ui/`) — see `SharedUiTemplates`'
/// own doc comment for why neither `core/` (constants/environment/
/// utilities only) nor `services/` (project-level capabilities) was
/// the right fit for a plain, stateless `Widget`. The Constants &
/// Utils gap analysis later added `core/utilities/` as a third `core/`
/// subfolder (see `UtilitiesTemplates`) — still `core/`, since none of
/// the five utilities is a `services/`-style project-level capability
/// or a `shared/ui/`-style widget either. This audit's job is exactly
/// the same as before: catch the shape of the whole tree drifting
/// beyond the pieces the architecture actually defines.
///
/// Every other generator test already asserts on individual files'
/// *content*; this one exists specifically to catch the shape of the
/// whole tree drifting — a stray `lib/core/bootstrap/`, a resurrected
/// `lib/services/debug/`, or a new, unplanned top-level folder — which
/// no single generator's own test would necessarily notice.
void main() {
  group('Generated project structure (V1 Architecture Final Audit)', () {
    late Directory tempDir;
    late ProjectPaths paths;

    setUpAll(() async {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_structure_audit_');
      paths = ProjectPaths(projectRoot: tempDir.path);

      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: Architecture.cleanArchitecture,
        stateManagement: StateManagement.bloc,
        network: Network.http,
        storage: Storage.sharedPreferences,
        services: Service.values.map((s) => s.id).toSet(),
        initialFeatures: ['auth'],
      );
      await ProjectGenerator(outputPath: tempDir.path, config: config)
          .generate();
    });

    tearDownAll(() => tempDir.deleteSync(recursive: true));

    test(
        'lib/ has exactly the four top-level pieces plus main.dart — '
        'core/, services/, features/, shared/ — no other top-level '
        'entry', () {
      final topLevel = Directory(paths.lib)
          .listSync()
          .map((e) => path.basename(e.path))
          .toSet();

      expect(
        topLevel,
        {'core', 'services', 'features', 'shared', 'main.dart'},
      );
    });

    test(
        'lib/core/ carries only constants/, environment/, and '
        'utilities/', () {
      final coreTopLevel = Directory(paths.core)
          .listSync()
          .map((e) => path.basename(e.path))
          .toSet();

      expect(coreTopLevel, {'constants', 'environment', 'utilities'});
    });

    test('lib/shared/ carries only ui/', () {
      final sharedTopLevel = Directory(path.join(paths.lib, 'shared'))
          .listSync()
          .map(
            (e) => path.basename(e.path),
          )
          .toSet();

      expect(sharedTopLevel, {'ui'});
    });

    test(
        'Bootstrap, Routing, Network, Storage, Theme all live under '
        'lib/services/', () {
      for (final dir in [
        paths.servicesBootstrap,
        paths.servicesRouting,
        paths.servicesNetwork,
        paths.servicesStorage,
        paths.servicesTheme,
      ]) {
        expect(Directory(dir).existsSync(), isTrue,
            reason: '$dir should exist');
      }
    });

    test('Home and Debug both live under lib/features/', () {
      expect(Directory(paths.featurePath('home')).existsSync(), isTrue);
      expect(Directory(paths.featuresDebug).existsSync(), isTrue);
    });

    test(
        'the old, pre-V1-Final-Architecture locations do not exist: '
        'no lib/core/bootstrap, lib/core/routing, lib/core/services, '
        'or lib/services/debug', () {
      for (final staleDir in [
        path.join(paths.core, 'bootstrap'),
        path.join(paths.core, 'routing'),
        path.join(paths.core, 'services'),
        path.join(paths.core, 'debug'),
        path.join(paths.services, 'debug'),
      ]) {
        expect(Directory(staleDir).existsSync(), isFalse,
            reason: '$staleDir must not exist');
      }
    });

    test(
        'the mirror holds under test/ too: test/core/, test/services/, '
        'test/features/, test/shared/ only — no stale test/core/'
        'bootstrap etc.', () {
      final testTopLevel = Directory(paths.test)
          .listSync()
          .map((e) => path.basename(e.path))
          .toSet();

      expect(testTopLevel, {'core', 'services', 'features', 'shared'});

      for (final staleDir in [
        path.join(paths.testCore, 'bootstrap'),
        path.join(paths.testCore, 'routing'),
        path.join(paths.testServices, 'debug'),
      ]) {
        expect(Directory(staleDir).existsSync(), isFalse,
            reason: '$staleDir must not exist');
      }
    });
  });
}
