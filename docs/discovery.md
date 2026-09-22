# Project Discovery & Doctor

[← Back to README](../README.md)

Both commands below are read-only — neither ever writes a file,
generates code, or modifies anything.

## Discover

```bash
smartwork discover
smartwork discover --json
```

Builds a machine-readable understanding of an existing Flutter project
(SmartWork-generated or not): framework, platforms, dependencies,
architecture, state management, dependency injection, features, and
test structure, each reported with its own confidence
(`declared`/`detected`/`inferred`/`unknown`) and supporting evidence.
`--json` prints the complete result as machine-readable JSON instead
of a human-readable summary.

Each `ProjectKnowledge` field carries its own confidence and
human-readable evidence, so a genuinely unanalyzable target (no
Flutter project at all) is the only case Discover reports as a
failure — a real project it simply couldn't confirm much about still
exits successfully with its honest, low-confidence findings.

## Doctor

```bash
smartwork doctor
```

Reports Dart/Flutter readiness and, if run inside a SmartWork project,
its configuration and any missing platform folder.
