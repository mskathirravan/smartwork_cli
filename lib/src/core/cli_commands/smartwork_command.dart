import 'package:args/command_runner.dart';

abstract class SmartworkCommand extends Command {
  @override
  Future<void> run() async {
    await execute();
  }

  Future<void> execute();
}
