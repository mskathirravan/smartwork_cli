import '../filesystem/file_writer.dart';

class WireMockScriptGenerator {
  final FileWriter _fileWriter;

  WireMockScriptGenerator({FileWriter? fileWriter})
      : _fileWriter = fileWriter ?? FileWriter();

  static const scriptsDir = 'scripts/wiremock';

  static const startScriptPath = '$scriptsDir/start.sh';
  static const stopScriptPath = '$scriptsDir/stop.sh';
  static const readmePath = '$scriptsDir/README.md';

  Future<void> ensureScripts(
    String projectPath, {
    required Future<bool> Function(String path) exists,
  }) async {
    if (!await exists('$projectPath/$startScriptPath')) {
      await _fileWriter.write('$projectPath/$startScriptPath', _startScript);
    }
    if (!await exists('$projectPath/$stopScriptPath')) {
      await _fileWriter.write('$projectPath/$stopScriptPath', _stopScript);
    }
    if (!await exists('$projectPath/$readmePath')) {
      await _fileWriter.write('$projectPath/$readmePath', _readme);
    }
  }

  static const _startScript = '''
#!/usr/bin/env bash
# Starts a local WireMock instance for this project's API-dependent
# tests. See README.md in this directory for how to obtain the JAR.
set -euo pipefail

DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PORT="\${WIREMOCK_PORT:-8080}"
JAR="\${WIREMOCK_JAR:-\$DIR/wiremock-standalone.jar}"
PID_FILE="\$DIR/.wiremock.pid"

if [ -f "\$PID_FILE" ] && kill -0 "\$(cat "\$PID_FILE")" 2>/dev/null; then
  echo "WireMock is already running (pid \$(cat "\$PID_FILE"))."
  exit 0
fi

if [ ! -f "\$JAR" ]; then
  echo "WireMock JAR not found at \$JAR" >&2
  echo "See \$DIR/README.md to download one, or set WIREMOCK_JAR." >&2
  exit 1
fi

java -jar "\$JAR" --port "\$PORT" --root-dir "\$DIR" \\
  > "\$DIR/wiremock.log" 2>&1 &
echo \$! > "\$PID_FILE"
''';

  static const _stopScript = '''
#!/usr/bin/env bash
# Stops the WireMock instance started by start.sh, if any.
set -euo pipefail

DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="\$DIR/.wiremock.pid"

if [ -f "\$PID_FILE" ]; then
  PID="\$(cat "\$PID_FILE")"
  kill "\$PID" 2>/dev/null || true
  rm -f "\$PID_FILE"
fi
''';

  static const _readme = '''
# WireMock scripts

These scripts let an API-dependent test run start a local WireMock
instance for deterministic mocked API responses, without adding any
WireMock dependency to this project itself.

## Setup

1. Download a WireMock standalone JAR from
   https://wiremock.org/docs/standalone/java-jar/ (any recent version).
2. Place it at `scripts/wiremock/wiremock-standalone.jar`, or set the
   `WIREMOCK_JAR` environment variable to wherever you keep it.
3. Make sure a Java runtime is on `PATH` (`java -version`).

## Usage

This project's own test tooling calls `start.sh`/`stop.sh`
automatically around a test run that needs mocked APIs — you do not
normally run these yourself. `start.sh` is a no-op if WireMock is
already running; `stop.sh` is always safe to call, even if WireMock
was never started.

`WIREMOCK_PORT` (default `8080`) controls which port WireMock listens
on. `mappings/`, `__files/`, `.wiremock.pid`, and `wiremock.log` are
working files for this local WireMock instance and should not be
committed.
''';
}
