# Project Generation

[← Back to README](../README.md)

## Initialize a project

```bash
smartwork init
```

Prompts you through project name, App Targets, architecture, state
management, network, storage, Production Services, and initial
features, then bootstraps a real Flutter project (`flutter create`)
and generates SmartWork's structure on top of it. Asks one
confirmation before writing anything.

## Open the Debug screen

Every generated app includes a Debug screen for development. To open
it, run the app in debug mode (`flutter run`) and **tap the version
text (`v1.0.0`) on the Home screen 10 times**.

It lets you:

- switch the **Environment** (DEV, STAGE, PROD);
- switch the **Theme** (system, light, dark);
- **send a test notification** (a local simulation — no real push
  provider is connected).

Environment and Theme changes are drafts: tap **Apply** to save and
switch them live, or **Cancel** to discard them.

The Debug screen only opens in debug builds — tapping the version in a
release build does nothing, so it never ships to your users. The tap
count is `AppConstants.debugTapCount` in
`lib/core/constants/app_constants.dart`; each generated project's own
`docs/development.md` has the full details.

## Add a feature

```bash
smartwork feature profile
```

Note there's no `add` keyword — the feature name is the argument.
Optionally choose exactly which pieces to generate:

```bash
smartwork feature profile --components entity,repository,page
```

## Remove a feature

```bash
smartwork feature remove profile
```

## Add a service

```bash
smartwork service add analytics
```

Unlike `feature`, `service` does require the `add`/`remove` keyword.

## Remove a service

```bash
smartwork service remove analytics
```

## Configure targets

```bash
smartwork target
```

Prompts for the complete desired set of App Targets (Android, iOS,
Web, Windows, macOS, Linux) for an existing SmartWork project, shows
the plan, and asks one confirmation before creating any newly-added
platform folder. Removing a target only drops it from configuration —
it never deletes a platform folder.

## Generate a model from JSON

```bash
smartwork model from-json <json-file-path> --feature <feature-name>
```

Generates a Dart model (fields, a `const` constructor,
`fromJson`/`toJson`, and one class per nested object) from a single
JSON sample document, into an existing feature. The target feature
must already exist — this command never creates one. Only a single
JSON sample is supported (not a JSON Schema); serialization is plain,
generated Dart code, with no `json_serializable`/`freezed`/
`build_runner` dependency added. Running it again refuses to overwrite
an existing generated model file.

## Generate an App Icon

```bash
smartwork icon --source <path-to-square-image>
```

Generates the App Icon for Android, iOS, macOS, and Web from a single
square `.png`/`.jpg`/`.jpeg` source image. There's no `add`/`remove`
sub-verb — a project has exactly one App Icon, so running the command
again with a new source replaces it.

## Add or reconfigure a Splash Screen

```bash
smartwork splash --background <hex> --icon <path>
```

Adds (or reconfigures) the Splash Screen using a background color
(`--background`, a 6-digit hex value) and a centered icon image
(`--icon`). Like `icon`, there's no `add`/`remove` sub-verb — running
the command again with new values changes the existing Splash Screen.

## Add or update a Font

```bash
smartwork font
```

Prompts for None/Custom Font/Google Font — the same choice `smartwork
init` asks — and applies it to an existing project: copies a Custom
Font's file(s) into `assets/fonts/`, regenerates `app_theme.dart` to
use the new font, and syncs `pubspec.yaml` (the `fonts:` section or
the `google_fonts` dependency). Like `icon`/`splash`, there's no
`add`/`remove` sub-verb — running it again replaces the current font.

## Add or update Localization

```bash
smartwork localization
```

Prompts for supported locales and a default locale — the same choice
`smartwork init` asks — and applies it to an existing project:
generates `l10n.yaml` and one baseline ARB file per newly-added
locale (an existing ARB file's translations are never overwritten),
rewires `lib/main.dart`, and syncs `pubspec.yaml`'s
`flutter_localizations` dependency and `generate: true` flag.
Disabling localization removes `l10n.yaml` but preserves every ARB
file already in `lib/l10n/`.

## Supported Options

| Category | Supported values |
| --- | --- |
| Architecture | Clean Architecture, MVVM, MVP |
| State management | BLoC, Cubit, GetX, Riverpod |
| Network | HTTP, Dio, Other |
| Storage | SharedPreferences, Hive, Other |
| App Targets | Android, iOS, Web, Windows, macOS, Linux |

`Other` (Network/Storage) means SmartWork adds no dependency and
generates no networking/persistence code for that concern — a
first-class choice for bringing your own solution, not an error state.

## Example Workflow

```bash
smartwork init                      # create the project
smartwork feature profile           # add a feature
smartwork service add analytics     # add a service
smartwork font                      # add or update the font
smartwork localization              # add or update localization
smartwork doctor                    # confirm everything is healthy
```
