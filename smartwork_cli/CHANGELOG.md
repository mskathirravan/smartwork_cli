## 1.0.3

**Updating from 1.0.2:** `smartwork update` in 1.0.2 can't update an
install from pub.dev. Run this once:

```bash
dart pub global activate smartwork_cli
```

From 1.0.3 on, `smartwork update` works for pub.dev installs.

- `smartwork init` and `smartwork target`: a failed validation step now
  shows why (the command's output). When the Flutter SDK is too old for
  the package versions SmartWork uses, they say so and tell you to update
  Flutter (`flutter upgrade`). SmartWork supports only the latest stable
  Flutter. Dependencies is now checked before Format.
- `smartwork doctor`: new "Package compatibility" check tells you,
  before you generate anything, whether your Flutter SDK can resolve
  SmartWork's packages.
- `smartwork font`, `smartwork service` and `smartwork localization` run
  `flutter pub get` when they change `pubspec.yaml` and report problems
  right away.
- `smartwork update` re-activates the latest version from pub.dev for
  pub.dev installs (source checkouts still use `git pull`).
- New-version notice: when pub.dev has a newer SmartWork, commands end
  with a reminder to run `smartwork update` (checked at most once a day,
  terminal only).
- Prompts: an invalid menu choice asks again instead of silently using a
  default; the Localization prompt also accepts y/yes and n/no.
- `smartwork test coverage` / `smartwork test update` show `flutter test`'s
  output when the run itself fails.
- Windows: `flutter` is now found when launched from SmartWork.
- Fixed: turning localization off (`smartwork localization`) corrupted
  `pubspec.yaml`, and left `flutter gen-l10n`'s generated
  `lib/l10n/app_localizations*.dart` files importing the removed packages.
  Those generated files are now deleted (ARB files are kept).
- Fixed: switching the font to None (or declining the sample) deleted
  `font_sample.dart` even when the Home page still used `FontSample`,
  breaking the build. The sample is now kept while it's in use.
- Generated code is always `dart format`-clean, including long feature
  and model names.
- Ending input at a prompt (Ctrl-D) cancels cleanly without changing
  anything, instead of looping or picking a default.
- The configuration summary uses the same labels as the prompts (MVVM,
  BLoC, GetX, HTTP, ...).
- Added `example/README.md`: a typical SmartWork session.
- Requires `smartwork_core >=1.0.3`.

## 1.0.2

`smartwork init` now asks for a project description and a project type
(E-Commerce, Food Delivery, Booking, Social, Dashboard, E-Book, Finance, or
Custom) right after the project name. Predefined types seed the Initial
Features step with a recommended feature list the developer can accept as-is
or reject in favor of the existing free-text feature entry; Custom skips
recommendations entirely and behaves exactly as before. Project type is a
CLI-only recommendation layer — it is not persisted to `.smartwork/project.yaml`
and never reaches generation. The project description is used only to set
the generated project's `pubspec.yaml` description line; it is likewise not
persisted to `.smartwork/project.yaml`. Requires `smartwork_core >=1.0.2`.

## 1.0.1

First pub.dev release. CLI for SmartWork: project generation (`init`,
`feature`, `service`, `target`, `font`, `localization`, `model`, `icon`,
`splash`), project discovery, test automation and maintenance (`test`), and
environment health checks (`doctor`).
