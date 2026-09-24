## 1.0.2

`smartwork init` now asks for a project description and a project type
(E-Commerce, Food Delivery, Booking, Social, Dashboard, E-Book, Finance, or
Custom) right after the project name. Predefined types seed the Initial
Features step with a recommended feature list the developer can accept as-is
or reject in favor of the existing free-text feature entry; Custom skips
recommendations entirely and behaves exactly as before. Project type is a
CLI-only recommendation layer — it is not persisted to `.smartwork/project.yaml`
and never reaches generation. The project description is used only to set
the generated project's `pubspec.yaml` description line; it is likewise not
persisted to `.smartwork/project.yaml`. Requires `smartwork_core >=1.0.2`.

## 1.0.1

First pub.dev release. CLI for SmartWork: project generation (`init`,
`feature`, `service`, `target`, `font`, `localization`, `model`, `icon`,
`splash`), project discovery, test automation and maintenance (`test`), and
environment health checks (`doctor`).
