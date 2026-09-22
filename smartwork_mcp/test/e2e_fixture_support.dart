import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';

/// Shared support for the real-Flutter E2E test files in this package.
///
/// Every real-project fixture these tests exercise used to be an
/// undocumented, external precondition ("run the E2E generation step
/// first") — a manual `flutter create`/`smartwork init` a person or
/// agent was expected to perform before invoking `dart test`, which a
/// clean checkout could never satisfy on its own. These helpers make
/// each test file build its own fixture, through the same real Core
/// pipeline `smartwork init`/`smartwork feature`/`smartwork service`
/// themselves use, so `dart test` alone is sufficient and repeatable.
///
/// Every fixture lives under the repo-root `tmp/` convention (temporary,
/// never committed) and is removed once its owning test file
/// finishes, so no fixture ever leaks into a later run or another file.

/// The real, on-disk path for a `tmp/<dirName>` fixture, resolved the
/// same way every existing E2E test already resolves it (relative to
/// this package's own `Directory.current`, two levels up to the repo
/// root).
String e2eFixturePath(String dirName) =>
    Directory.current.parent.uri.resolve('tmp/$dirName').toFilePath();

/// Deletes an existing fixture directory, if any — used both to start
/// from a clean slate before generating and to clean up afterward.
void deleteE2EFixture(String projectPath) {
  final dir = Directory(projectPath);
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
}

/// Creates a fresh, empty fixture directory — for tests that perform
/// their own real generation (`smartwork_init_plan`/`_apply`) against
/// a directory that must exist but start empty.
void createEmptyE2EFixture(String projectPath) {
  deleteE2EFixture(projectPath);
  Directory(projectPath).createSync(recursive: true);
}

/// Generates a real, complete SmartWork project fixture at [projectPath]
/// via [ProjectInitializer] — the same real `flutter create` + generate
/// + validate + document sequence `smartwork init` itself runs, not a
/// hand-rolled approximation. Any previous fixture at this path is
/// removed first, so repeated runs are deterministic regardless of
/// what an earlier run left behind.
Future<void> generateSmartworkFixture(
  String projectPath, {
  required ProjectConfig config,
}) async {
  deleteE2EFixture(projectPath);
  await ProjectInitializer()
      .initialize(projectPath: projectPath, config: config);
}

/// Adds a feature to an already-generated fixture via the real
/// [FeatureLifecycle] — the same Core class `smartwork feature`/
/// `smartwork_feature_add` call, with the same default blueprint a bare
/// `FeatureConfig(name: ...)` resolves to.
Future<void> addFixtureFeature(String projectPath, String featureName) =>
    FeatureLifecycle().addFeature(
      projectPath: projectPath,
      feature: FeatureConfig(name: featureName),
    );

/// Adds a Production Service to an already-generated fixture via the
/// real [ServiceLifecycle] — the same Core class `smartwork service
/// add`/`smartwork_service_add` calls.
Future<void> addFixtureService(String projectPath, String serviceId) =>
    ServiceLifecycle()
        .addService(projectPath: projectPath, serviceId: serviceId);

/// Bootstraps a bare Flutter project (via [FlutterBootstrap] directly)
/// with no SmartWork generation layered on top — for tests asserting
/// on `TargetStateDetector`'s "existing plain Flutter project" state,
/// which must never have a `.smartwork/project.yaml`.
Future<void> generateBareFlutterFixture(
  String projectPath, {
  required String projectName,
  Set<String>? platforms,
}) async {
  deleteE2EFixture(projectPath);
  await FlutterBootstrap().create(
    projectName: projectName,
    targetPath: projectPath,
    platforms: platforms,
  );
}

/// Creates a non-empty, non-Flutter directory fixture — a plain file on
/// disk, nothing that looks like a Flutter or SmartWork project.
void createNonFlutterFixture(String projectPath) {
  deleteE2EFixture(projectPath);
  Directory(projectPath).createSync(recursive: true);
  File('$projectPath/random.txt').writeAsStringSync('not a project\n');
}
