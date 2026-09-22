import 'dart:io';

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
