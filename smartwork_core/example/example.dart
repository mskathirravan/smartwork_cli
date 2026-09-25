// An example prints its results.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';

/// Describes a SmartWork project, checks it, and (with a path argument)
/// generates it: `dart run example/example.dart /path/to/empty_dir`.
///
/// Generating runs `flutter create`, `flutter pub get`, `flutter analyze`
/// and `flutter test`, so it needs the latest stable Flutter on PATH.
Future<void> main(List<String> args) async {
  final config = ProjectConfig(
    projectName: 'shop_app',
    appTargets: {AppTarget.android, AppTarget.ios},
    architecture: Architecture.cleanArchitecture,
    stateManagement: StateManagement.bloc,
    network: Network.dio,
    storage: Storage.sharedPreferences,
    services: {Service.logger.id, Service.forceUpdate.id},
    initialFeatures: ['home', 'cart', 'profile'],
  );

  // 1. Check the configuration before generating anything.
  final errors = ConfigValidator.validate(config);
  if (errors.isNotEmpty) {
    for (final error in errors) {
      print('Invalid configuration: ${error.message}');
    }
    exitCode = 1;
    return;
  }

  // 2. See which packages SmartWork will add to the project.
  final dependencies = PubspecGenerator().resolveDependencies(config);
  print('Dependencies: ${dependencies.runtime.join(', ')}');
  print('Dev dependencies: ${dependencies.dev.join(', ')}');

  // 3. Check the local Flutter SDK can resolve those packages.
  for (final check in await EnvironmentDoctor().checkEnvironment()) {
    final status = check.inconclusive ? 'ℹ' : (check.passed ? '✓' : '✗');
    print('$status ${check.label}${check.detail == null ? '' : ': '
        '${check.detail}'}');
  }

  if (args.isEmpty) return;

  // 4. Generate and validate the project, exactly like `smartwork init`.
  try {
    final result = await ProjectInitializer().initialize(
      projectPath: args.first,
      config: config,
    );
    print('Generated ${result.generation.fileCount} files; '
        'validation ${result.validation.passed ? 'passed' : 'failed'}.');
  } on ProjectValidationFailedException catch (e) {
    print(e.details);
    exitCode = 1;
  }
}
