import 'dart:io';

/// smartwork_cli's own version, kept in sync with this package's
/// `pubspec.yaml` `version:` field on every release (see
/// `version_test.dart`, which fails if the two ever drift).
///
/// Used only as a last resort, when no `pubspec.yaml` can be found on
/// disk — the normal case for `dart pub global activate`: pub's global
/// package cache (`~/.pub-cache/global_packages/smartwork_cli/`) stores
/// only the compiled snapshot, `pubspec.lock`, and `package_config.json`,
/// never a copy of the source `pubspec.yaml`, so the filesystem search
/// below always misses for a globally-activated install — which is how
/// real users actually run this CLI.
const String fallbackSmartworkCliVersion = '1.0.3';

String? readSmartworkCliVersion({Directory? workingDirectory}) {
  final candidates = <File>[];

  var dir = File.fromUri(Platform.script).parent;
  for (var i = 0; i < 8; i++) {
    candidates.add(File('${dir.path}/pubspec.yaml'));
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }

  candidates.add(
      File('${(workingDirectory ?? Directory.current).path}/pubspec.yaml'));

  return findSmartworkCliVersionAmong(candidates) ??
      fallbackSmartworkCliVersion;
}

/// Returns the version declared by the first of [candidates] that is
/// genuinely smartwork_cli's own `pubspec.yaml` (matched by its `name:`
/// field, never just any `pubspec.yaml` that happens to exist), or null
/// if none of them is. Separated from [readSmartworkCliVersion] so this
/// matching logic — and the "none of them match" case that triggers
/// [fallbackSmartworkCliVersion] — is directly testable with fake files,
/// without needing to fake `Platform.script` or pub's global-activation
/// cache layout.
String? findSmartworkCliVersionAmong(Iterable<File> candidates) {
  for (final file in candidates) {
    if (!file.existsSync()) continue;
    final content = file.readAsStringSync();
    if (!RegExp(r'^name:\s*smartwork_cli\s*$', multiLine: true)
        .hasMatch(content)) {
      continue;
    }
    final match =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(content);
    if (match != null) return match.group(1);
  }
  return null;
}
