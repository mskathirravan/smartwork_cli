## 1.0.3

SmartWork supports only the latest stable Flutter. When the developer's
Flutter SDK is too old for the package versions SmartWork generates, it now
says so and tells them to update, instead of failing silently.

- `ProjectValidator`: the Dependencies phase runs before Format. A
  `flutter pub get` failure caused by an out-of-date SDK carries a `hint`
  (new `ValidationPhaseResult.hint`) telling the developer to update
  Flutter. New `resolveDependencies()` runs that phase on its own, and
  `ProjectValidationFailedException.details` includes the failed phase's
  hint and output.
- New `SdkUpdateHint` recognizes these failures (`isSdkTooOld`,
  `message`, `describeFailure`).
- `EnvironmentDoctor`: new "Package compatibility" check resolves every
  package SmartWork can generate against the local SDK
  (`PubspecGenerator.generateDependencyProbe`). `EnvironmentCheck` gains
  `inconclusive` for checks that can't reach a verdict (e.g. offline).
- `CoverageNotProducedException` includes `flutter test`'s output.
- Processes are launched through the shell on Windows (new
  `runSystemProcess`, the default `ProcessRunner`), so `flutter.bat` is
  found.
- Google Font projects: the generated `AppTheme` tests use `testWidgets`.
- Fixed: `FontLifecycle.updateFontSample` deleted `font_sample.dart`
  while project code still used `FontSample`; it now keeps (and updates)
  the sample in that case.
- Fixed: disabling localization now deletes the Dart files
  `flutter gen-l10n` generated in `lib/l10n/` (they import the removed
  packages); ARB files are kept.
- Fixed: removing a managed dependency (e.g. disabling localization) left
  its nested `sdk: flutter` line behind, corrupting `pubspec.yaml`.
- Generated Dart code is run through `dart format`, so long feature or
  model names no longer produce unformatted code (or fail `init`'s Format
  phase). New `FileWriter.recordDartWrites` and
  `ProjectValidator.formatDartFiles`.

## 1.0.2

`PubspecGenerator.generate`/`mergeInto` and `ProjectGenerator`/
`ProjectInitializer.initialize` accept an optional `projectDescription`,
used only to set the generated project's `pubspec.yaml` description line.
It is not part of `ProjectConfig` and is not persisted to
`.smartwork/project.yaml`; omitting it preserves the exact prior behavior.

## 1.0.1

First pub.dev release. Core engine for SmartWork: architecture templates
(Clean, MVVM, MVP, BLoC/Cubit, GetX/Riverpod), feature blueprint generation,
network and storage generation, Production Services, App Targets, and
project discovery.
