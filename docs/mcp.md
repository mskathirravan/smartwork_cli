# SmartWork MCP

[← Back to README](../README.md)

SmartWork MCP lets an MCP-compatible AI client (or any MCP client)
perform the same project operations as the CLI, through structured
tools instead of interactive prompts.

## Installation

> Not yet published on pub.dev (`publish_to: none`) — run it from
> source for now.

```bash
git clone <repository-url>
cd smartwork/smartwork_mcp
dart pub get
```

Your MCP client needs to run this command with `smartwork_mcp/` as the
working directory:

```bash
dart run bin/smartwork_mcp.dart
```

Or compile it once for faster startup, and point your client at the
resulting binary directly:

```bash
dart compile exe bin/smartwork_mcp.dart -o smartwork_mcp_server
```

The server speaks MCP over stdio (`stdin`/`stdout`) and identifies
itself as `smartwork_mcp`.

## Client Setup

The server speaks plain stdio MCP, so it works with any compliant
client. Every example below assumes you've either cloned the repo
(pointing `cwd`/working directory at `smartwork_mcp/`) or compiled the
binary as shown in [Installation](#installation) — compiling once and
pointing clients at the resulting executable avoids repeating `cwd`
everywhere.

### Claude Desktop

Edit your `claude_desktop_config.json`
(`~/Library/Application Support/Claude/claude_desktop_config.json` on
macOS, `%APPDATA%\Claude\claude_desktop_config.json` on Windows):

```json
{
  "mcpServers": {
    "smartwork": {
      "command": "dart",
      "args": ["run", "bin/smartwork_mcp.dart"],
      "cwd": "/absolute/path/to/smartwork_mcp"
    }
  }
}
```

Restart Claude Desktop after saving. The tools appear under the 🔨
icon in a new chat.

### Claude Code

Either add it with the CLI, using the compiled binary so no working
directory is needed:

```bash
claude mcp add smartwork /absolute/path/to/smartwork_mcp_server
```

Or add it to a project's `.mcp.json` so it's shared with anyone
working in that repo:

```json
{
  "mcpServers": {
    "smartwork": {
      "command": "dart",
      "args": ["run", "bin/smartwork_mcp.dart"],
      "cwd": "/absolute/path/to/smartwork_mcp"
    }
  }
}
```

### Cursor

Settings → MCP → Add new MCP server, or edit `~/.cursor/mcp.json`
(global) or `.cursor/mcp.json` in a project (project-scoped) directly:

```json
{
  "mcpServers": {
    "smartwork": {
      "command": "dart",
      "args": ["run", "bin/smartwork_mcp.dart"],
      "cwd": "/absolute/path/to/smartwork_mcp"
    }
  }
}
```

### GitHub Copilot (VS Code)

Run **MCP: Add Server** from the Command Palette, or add a
`.vscode/mcp.json` to the project. Copilot's MCP config uses a
`servers` key (not `mcpServers`) and requires `"type": "stdio"`:

```json
{
  "servers": {
    "smartwork": {
      "type": "stdio",
      "command": "dart",
      "args": ["run", "bin/smartwork_mcp.dart"],
      "cwd": "/absolute/path/to/smartwork_mcp"
    }
  }
}
```

### Other clients (local AI tools, etc.)

Any other MCP-compatible client — including local setups such as
LM Studio, Ollama-based agents, or Continue.dev — follows the same
stdio contract. Configuration syntax varies per client, but each one
needs the same three things: the command (`dart`), its arguments
(`run bin/smartwork_mcp.dart`), and the working directory
(`smartwork_mcp/`, or nothing if you point at the compiled binary
instead):

```json
{
  "mcpServers": {
    "smartwork": {
      "command": "dart",
      "args": ["run", "bin/smartwork_mcp.dart"],
      "cwd": "/absolute/path/to/smartwork_mcp"
    }
  }
}
```

## Available Tools

| Tool | Description |
| --- | --- |
| `smartwork_doctor` | Read-only Dart/Flutter and project readiness check |
| `smartwork_feature_add` | Add a feature to an existing project |
| `smartwork_feature_remove` | Remove a feature from an existing project |
| `smartwork_service_add` | Add a Production Service |
| `smartwork_service_remove` | Remove a Production Service |
| `smartwork_init_plan` | Build and validate a new project's configuration (read-only) |
| `smartwork_init_apply` | Perform real project initialization from a confirmed plan |
| `smartwork_target_plan` | Compute an App Targets change (read-only) |
| `smartwork_target_apply` | Perform a confirmed App Targets change |
| `smartwork_splash_add` | Add or reconfigure the Splash Screen |
| `smartwork_model_from_json` | Generate a Dart model from a JSON sample document |
| `smartwork_app_icon_set` | Generate the App Icon from a single square source image |
| `smartwork_discover` | Read-only analysis of any existing Flutter project |

## Plan and Apply

`init` and `target` follow an explicit plan-then-apply pattern —
there's no interactive confirmation prompt over MCP, so the client
does that step instead:

```text
smartwork_init_plan   →  review the returned plan  →  smartwork_init_apply (confirm: true)
smartwork_target_plan →  review the returned plan  →  smartwork_target_apply (confirm: true)
```

`apply` requires the exact `plan` object the matching `plan` tool
returned, plus `confirm: true`. Omitting confirmation, or passing
`confirm: false`, performs no action.

## Example Workflow

1. Run `smartwork_doctor` to check the project.
2. Call `smartwork_target_plan` (or `smartwork_init_plan`) for the
   operation you want.
3. Review the returned plan.
4. Call the matching `apply` tool with that plan and `confirm: true`.
5. Run `smartwork_doctor` again to verify the result.

## Worked Example: Bootstrap a Project

A concrete round trip through `smartwork_init_plan` →
`smartwork_init_apply` → `smartwork_doctor`, as an AI client would
call them.

**1. Call `smartwork_init_plan`** with the desired configuration:

```json
{
  "name": "smartwork_init_plan",
  "arguments": {
    "projectPath": "/Users/me/dev/loyalty_app",
    "projectName": "loyalty_app",
    "architecture": "cleanArchitecture",
    "stateManagement": "bloc",
    "network": "dio",
    "storage": "hive",
    "appTargets": ["android", "ios"],
    "services": ["analytics", "crashReporting", "secureSession"]
  }
}
```

The tool responds with a canonical plan and a read-only safety report
— nothing is created yet:

```json
{
  "success": true,
  "operation": "init_plan",
  "plan": {
    "projectName": "loyalty_app",
    "architecture": "cleanArchitecture",
    "stateManagement": "bloc",
    "network": "dio",
    "storage": "hive",
    "appTargets": ["android", "ios"],
    "services": ["analytics", "crashReporting", "secureSession"],
    "initialFeatures": ["home"]
  },
  "safety": {
    "state": "empty",
    "isRegeneration": false,
    "existingPlatforms": []
  }
}
```

**2. Review the plan**, then call `smartwork_init_apply` with that
exact `plan` object plus `confirm: true`:

```json
{
  "name": "smartwork_init_apply",
  "arguments": {
    "projectPath": "/Users/me/dev/loyalty_app",
    "plan": { "...": "the plan object returned above, unchanged" },
    "confirm": true
  }
}
```

```json
{
  "success": true,
  "operation": "init_apply",
  "projectPath": "/Users/me/dev/loyalty_app",
  "result": {
    "fileCount": 87,
    "directoryCount": 24,
    "featureCount": 1,
    "validationPhases": [
      { "phase": "structure", "passed": true },
      { "phase": "analyze", "passed": true },
      { "phase": "format", "passed": true },
      { "phase": "test", "passed": true }
    ]
  }
}
```

**3. Confirm health** with `smartwork_doctor`:

```json
{ "name": "smartwork_doctor", "arguments": { "projectPath": "/Users/me/dev/loyalty_app" } }
```

```json
{
  "success": true,
  "projectPath": "/Users/me/dev/loyalty_app",
  "checks": [
    { "label": "Dart SDK", "status": "pass" },
    { "label": "Flutter SDK", "status": "pass" },
    { "label": "Flutter project", "status": "pass" },
    { "label": "SmartWork project", "status": "pass" },
    { "label": "Configuration valid", "status": "pass" },
    { "label": "App Targets", "status": "pass", "detail": "Android, iOS" },
    { "label": "Services", "status": "pass", "detail": "Analytics, Crash Reporting, Secure Session" }
  ],
  "errors": [],
  "warnings": []
}
```

If `confirm` is omitted or `smartwork_init_apply` is called with a
hand-edited `plan` that doesn't validate, the tool returns
`"success": false` with an `error.code` (e.g.
`confirmation_required`, `invalid_configuration`) and touches nothing
— the same safe-by-default behavior applies to `smartwork_target_plan`
/ `smartwork_target_apply`.
