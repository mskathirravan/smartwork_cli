import 'service_definition.dart';

class ServiceChanges {
  final Set<String> current;
  final Set<String> desired;

  final Set<String> added;

  final Set<String> removed;

  final Set<String> unchanged;

  ServiceChanges._({
    required this.current,
    required this.desired,
    required this.added,
    required this.removed,
    required this.unchanged,
  });

  factory ServiceChanges.compute({
    required Set<String> current,
    required Set<String> desired,
  }) {
    return ServiceChanges._(
      current: current,
      desired: desired,
      added: desired.difference(current),
      removed: current.difference(desired),
      unchanged: current.intersection(desired),
    );
  }

  bool get hasChanges => added.isNotEmpty || removed.isNotEmpty;

  List<Service> get orderedCurrent => _ordered(current);

  List<Service> get orderedDesired => _ordered(desired);

  List<Service> get orderedAdded => _ordered(added);

  List<Service> get orderedRemoved => _ordered(removed);

  List<Service> get orderedUnchanged => _ordered(unchanged);

  List<Service> _ordered(Set<String> ids) =>
      Service.values.where((s) => ids.contains(s.id)).toList();
}
