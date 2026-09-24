## 1.0.2

`PubspecGenerator.generate`/`mergeInto` and `ProjectGenerator`/
`ProjectInitializer.initialize` accept an optional `projectDescription`,
used only to set the generated project's `pubspec.yaml` description line.
It is not part of `ProjectConfig` and is not persisted to
`.smartwork/project.yaml`; omitting it preserves the exact prior behavior.

## 1.0.1

First pub.dev release. Core engine for SmartWork: architecture templates
(Clean, MVVM, MVP, BLoC/Cubit, GetX/Riverpod), feature blueprint generation,
network and storage generation, Production Services, App Targets, and
project discovery.
