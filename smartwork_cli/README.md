# smartwork_cli

> "Don't read success stories, you will only get a message. Read
> failure stories, you will get some ideas to get access."
> — APJ Abdul Kalam

**The all-in-one Flutter project companion** — init, architect, scaffold,
test, and ship, without leaving the terminal.

SmartWork bootstraps a real Flutter app with a consistent architecture, grows
it with features, services, targets, fonts, and localization, and verifies
it's still healthy — one command at a time.

## Demo
![smartwork init walking through configuration, bootstrapping, and validation in the terminal](../docs/assets/project-output.gif)

## Install

```bash
dart pub global activate smartwork_cli
```

Make sure Dart's global bin directory is on your `PATH`:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

## Quick Start

```bash
smartwork init
smartwork feature profile
smartwork service add analytics
smartwork doctor
```

Every command has `--help`, e.g. `smartwork feature --help`.

## Commands

| Command | What it does |
| --- | --- |
| `smartwork init` | Bootstraps a real Flutter project and applies architecture, state management, network, storage, fonts, localization, and Production Services |
| `smartwork feature <name>` | Generates a new feature; `smartwork feature remove <name>` deletes one |
| `smartwork service add\|remove <name>` | Adds or removes a Production Service (analytics, notifications, secure session, remote config, ...) |
| `smartwork target` | Changes an existing project's App Targets (Android/iOS/Web/Windows/macOS/Linux) |
| `smartwork font` | Adds or updates the Custom/Google Font on an existing project |
| `smartwork localization` | Adds or updates localization on an existing project |
| `smartwork model from-json` | Generates a Dart model from a JSON sample |
| `smartwork icon` | Generates the App Icon from one square source image |
| `smartwork splash` | Adds or reconfigures the Splash Screen |
| `smartwork discover` | Read-only analysis of any existing Flutter project |
| `smartwork doctor` | Checks whether the SmartWork/Flutter environment and current project are healthy |
| `smartwork test` | Analyzes, generates, and maintains tests for an existing feature |
| `smartwork update` | Updates the installed SmartWork CLI itself |
| `smartwork version` | Prints the installed SmartWork CLI version |

## Documentation

Full documentation, including MCP setup, lives in the
[SmartWork repository](https://github.com/mskathirravan/smartwork_cli).

## License

MIT — see [LICENSE](LICENSE).
