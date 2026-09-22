import 'package:smartwork_core/smartwork_core.dart';

abstract class StateManagementGenerator {
  Future<void> generate(
    ProjectConfig config,
    ProjectPaths paths,
    FileWriter fileWriter,
  );
}
