import 'project_config.dart';

class TargetChangePlan {
  final Set<AppTarget> current;
  final Set<AppTarget> requested;

  final Set<AppTarget> added;

  final Set<AppTarget> removedFromConfig;

  TargetChangePlan._({
    required this.current,
    required this.requested,
    required this.added,
    required this.removedFromConfig,
  });

  factory TargetChangePlan.compute({
    required Set<AppTarget> current,
    required Set<AppTarget> requested,
  }) {
    return TargetChangePlan._(
      current: current,
      requested: requested,
      added: requested.difference(current),
      removedFromConfig: current.difference(requested),
    );
  }

  bool get hasChanges => added.isNotEmpty || removedFromConfig.isNotEmpty;

  List<AppTarget> get orderedCurrent =>
      AppTarget.values.where(current.contains).toList();

  List<AppTarget> get orderedRequested =>
      AppTarget.values.where(requested.contains).toList();

  List<AppTarget> get orderedAdded =>
      AppTarget.values.where(added.contains).toList();

  List<AppTarget> get orderedRemovedFromConfig =>
      AppTarget.values.where(removedFromConfig.contains).toList();
}
