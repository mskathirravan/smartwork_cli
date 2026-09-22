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
