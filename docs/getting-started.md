# Getting Started

[← Back to README](../README.md)

## Requirements

- **Dart SDK** `>=3.2.0 <4.0.0` (to run the SmartWork CLI itself)
- **Flutter SDK** — the **latest stable** release. Generated projects use
  the newest versions of their packages (e.g. `riverpod`, `google_fonts`,
  `package_info_plus`), which require a recent Flutter SDK; older
  Flutter versions are not supported. SmartWork always invokes the
  `flutter`/`dart` executables it finds on your shell's `PATH`, it does
  not pin or download a specific version itself

Verify your environment:

```bash
dart --version
flutter --version
```

Once SmartWork is installed (see below), `smartwork doctor` re-checks
both of these for you — including whether your Flutter SDK can resolve
the package versions SmartWork generates — plus whatever project you run
it in.

## Flutter SDK Setup

SmartWork doesn't manage your Flutter SDK — it just runs `flutter`/
`dart` by name and lets your shell decide which installation that
resolves to. That means either of the following works with no special
configuration on SmartWork's side.

### Option 1: Normal Flutter SDK

1. [Install Flutter](https://docs.flutter.dev/get-started/install) for
   your platform.
2. Add Flutter's `bin/` directory to your `PATH`.
3. Verify:

   ```bash
   flutter --version
   flutter doctor
   ```

4. Continue to [Install SmartWork CLI](#install-smartwork-cli) below.

### Option 2: FVM

[FVM](https://fvm.app) (Flutter Version Management) lets a project pin
a specific Flutter version instead of relying on one global install.
SmartWork has no FVM-specific integration — there's no `fvm smartwork`
command — but since SmartWork only ever calls the bare `flutter`/
`dart` executables, it transparently picks up whichever version your
shell resolves those names to. If that's the version FVM selected,
SmartWork uses it automatically.

```bash
dart pub global activate fvm
fvm install <flutter-version>
fvm use <flutter-version>
```

Make sure `flutter`/`dart` resolve to FVM's copies in the shell where
you'll run `smartwork` — for example by working inside a project
directory where FVM has configured `PATH`, or by exporting FVM's
per-version SDK path yourself. Confirm it before relying on it:

```bash
fvm flutter --version
smartwork doctor
```

If `smartwork doctor`'s reported Flutter version doesn't match `fvm
flutter --version`, `flutter` on `PATH` isn't currently resolving to
FVM's copy — fix your `PATH` before continuing.

## Install SmartWork CLI

```bash
dart pub global activate smartwork_cli
```

This installs a `smartwork` executable on your machine. Make sure Dart's
global bin directory is on your `PATH`:

```bash
# macOS/Linux (add to ~/.zshrc, ~/.bashrc, etc.)
export PATH="$PATH:$HOME/.pub-cache/bin"
```

```powershell
# Windows (PowerShell)
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
```

On macOS, the default shell is zsh, so this usually means adding that line
to `~/.zshrc`. To open and edit it:

```bash
open -e ~/.zshrc   # opens in TextEdit
code ~/.zshrc      # opens in VS Code (if the `code` CLI is installed)
nano ~/.zshrc      # edit directly in the terminal
```

After saving, reload it in your current terminal with `source ~/.zshrc`, or
just open a new terminal window.

```bash
smartwork --help
```

### Help

```bash
smartwork --help
smartwork help
```

### Update

```bash
smartwork update
```

Updates the installed SmartWork CLI itself — never the current Flutter
project:

- **Installed from pub.dev** (`dart pub global activate smartwork_cli`):
  re-activates the latest version from pub.dev.
- **Installed from a source checkout** (`dart pub global activate
  --source path .`): runs `git pull`, then re-activates from the
  checkout.

When a newer version is on pub.dev, every command — including
`smartwork --help` — ends with a notice telling you to run
`smartwork update`. SmartWork asks pub.dev at most once a day (cached in
`~/.smartwork/update_check.json`), never slows a command down, and only
shows the notice in a terminal.

If you are on SmartWork 1.0.2 or earlier, `smartwork update` can't update
a pub.dev install yet — run this once instead:

```bash
dart pub global activate smartwork_cli
```

### Version

```bash
smartwork version
```

Prints the installed SmartWork CLI's own version (read from its
`pubspec.yaml`, no network request).

## SmartWork + Normal Flutter vs FVM

| Setup | Flutter command | SmartWork |
| --- | --- | --- |
| Normal Flutter | `flutter ...` | Run `smartwork ...` normally — it resolves `flutter`/`dart` from `PATH` the same way |
| FVM | `fvm flutter ...` | Same `smartwork ...` commands, as long as `PATH` currently resolves to FVM's selected version (see [Option 2: FVM](#option-2-fvm)) |

SmartWork itself has no separate FVM-aware invocation — there's
nothing to prefix with `fvm`.
