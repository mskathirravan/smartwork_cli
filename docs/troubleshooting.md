# Troubleshooting

[← Back to README](../README.md)

## `smartwork: command not found`

Dart's global executable directory isn't on your `PATH`. Find it with
`dart pub global activate` (it prints the path if it isn't already
there) and add it to your shell's profile.

## Flutter not found

```bash
flutter --version
flutter doctor
```

If these fail, SmartWork's own `flutter create`/`flutter analyze`/
`flutter test` steps will fail the same way — fix your Flutter
installation first.

## "Your Flutter SDK is too old for the package versions SmartWork uses"

SmartWork generates projects with the newest versions of their packages,
so it supports only the latest stable Flutter. When your SDK is older,
`flutter pub get` can't resolve those packages — for example:

```
Because app depends on google_fonts >=6.3.1 which requires SDK version >=3.7.0 <4.0.0, version solving failed.
```

or `meta is pinned to version 1.15.0 by flutter_test from the flutter SDK`.
`smartwork init`, `smartwork target`, `smartwork font`,
`smartwork service` and `smartwork localization` show this under
`✗ Dependencies`; `smartwork doctor` reports it as
`✗ Package compatibility` before you generate anything. Update Flutter,
then run the command again:

```bash
flutter upgrade
# FVM:
fvm install stable && fvm use stable
```

## FVM-managed Flutter not found

```bash
fvm flutter --version
```

If this works but `smartwork doctor` reports a different (or no)
Flutter version, your shell's `PATH` isn't currently resolving
`flutter` to FVM's copy.

## "This is not a SmartWork-generated project"

`smartwork target`, and any MCP tool that mutates an existing project,
refuse to run without a real `.smartwork/project.yaml` in the target
directory. Run `smartwork init` there first.

## MCP server not starting

Confirm Dart is installed and `smartwork_mcp`'s dependencies are
fetched (`dart pub get` inside `smartwork_mcp/`), then confirm the
exact command your MCP client is configured to run — `dart run
bin/smartwork_mcp.dart` — succeeds when run directly from a terminal
with `smartwork_mcp/` as the working directory.
