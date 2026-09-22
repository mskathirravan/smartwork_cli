# Testing

[← Back to README](../README.md)

## Test Automation

```bash
smartwork test analyze <feature>              # read-only report
smartwork test generate <feature>             # plan, confirm, then write
smartwork test generate <feature> --dry-run   # show the plan only
smartwork test check <feature>                # CI-facing Test Guard
smartwork test coverage <feature>             # run tests, report real coverage
```

Works against any existing Flutter feature under `lib/features/<name>/`
— not only ones `smartwork init`/`smartwork feature` generated.
`analyze` reports which production classes are covered, missing, or
outdated by an existing test, and always exits `0` (informational, like
`smartwork discover`). `generate` shows the exact files it would create
before writing anything, and only writes after an explicit `y`
confirmation (or `--non-interactive`); it never overwrites an existing
test file, and never generates a call that wouldn't compile — a class
whose constructor needs an argument, has no public constructor, or is
`abstract` gets a real `skip:`-marked scaffold instead of a guess.
`check` reports the same analysis but exits non-zero if anything is
missing/outdated/broken/partial (including a Test Maintenance finding
— see below), so it can gate a CI pipeline. `coverage` genuinely runs
the project's tests (`flutter test --coverage`) and reports real,
per-file line coverage and uncovered lines for the feature — the one
command here that isn't purely read-only in the "never executes
anything" sense, though it still never writes to a source file.
`analyze`/`generate`/`check`/`coverage` support `--format json`;
`analyze`/`coverage` also support `--verbose`. API mocking during a
test run (`MockServer`/WireMock) is available as underlying
infrastructure but not yet wired into any CLI command automatically.

Deliberately not implemented: an update workflow for `outdated` tests
found by `analyze`/`check` themselves (see Test Maintenance below for
the separate, dedicated update command) and committed fixture Flutter
projects — validation instead uses the repository's own `tmp/`
convention, ephemeral and never committed.

## Test Maintenance

```bash
smartwork test update <feature>               # plan, review, then apply
smartwork test update <feature> --dry-run     # show the plan only, write nothing
smartwork test update <feature> --non-interactive  # apply high-confidence updates only
```

Extends Test Guard from *detecting* an outdated test into a full,
approved update: `smartwork test update <feature>` finds an existing
test whose call no longer matches its subject's current signature,
shows a confidence-scored plan with a real diff for each proposed
change, asks `[Y]es/[N]o/[V]iew diff` before touching anything, then
applies the change and runs `dart format`/`flutter analyze`/
`flutter test` for real — rolling back automatically if any of those
fail. **SmartWork never blindly rewrites a developer-authored test**:
only the exact outdated expression is replaced, every comment, helper,
mock, and unrelated test in the file is preserved untouched, and a
change SmartWork cannot confidently determine is never applied — it is
reported for manual review instead (`low` confidence). `--dry-run`
shows the same plan and writes nothing; `--non-interactive` applies
only `high`-confidence updates and never silently applies a `medium`-
or `low`-confidence one.

Deliberately out of scope: WireMock mapping drift (no persisted
canonical API contract to diff a mapping against yet), purely semantic
changes where an identifier still compiles but its meaning changed,
and navigation-graph changes (no structured navigation-graph model
exists in SmartWork today to compare against).
