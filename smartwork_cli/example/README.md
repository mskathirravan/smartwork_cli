# SmartWork CLI example

A typical session: install SmartWork, create a Flutter app, then grow it.
SmartWork needs the latest stable Flutter SDK.

```bash
# Install (or update) the CLI and check your environment
dart pub global activate smartwork_cli
smartwork doctor

# Create a project in an empty folder — SmartWork asks for the
# architecture, state management, network, storage, services and
# features, then generates and validates the app
mkdir shop_app && cd shop_app
smartwork init

# Grow it
smartwork feature cart
smartwork model from-json order.json --feature cart
smartwork service add analytics
smartwork font                 # custom or Google Font
smartwork localization         # e.g. en, fr, de
smartwork target               # add Web, macOS, ...

# Keep its tests up to date
smartwork test analyze cart
smartwork test generate cart
smartwork test check cart      # CI gate

# Run it
flutter run
```

In the running app (debug builds), tap the version text on the Home
screen 10 times to open the Debug screen.

When a new SmartWork version is available, any command reminds you to
run `smartwork update`.

See the [smartwork_cli README](https://pub.dev/packages/smartwork_cli) for
every command and option.
