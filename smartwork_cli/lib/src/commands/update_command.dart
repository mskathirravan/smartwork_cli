import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_core/smartwork_core.dart';

class UpdateCommand extends Command {
  final ProcessRunner _runProcess;
  final Directory? _sourceDirectoryOverride;

  UpdateCommand({ProcessRunner? runProcess, Directory? sourceDirectory})
      : _runProcess = runProcess ?? Process.run,
        _sourceDirectoryOverride = sourceDirectory;

  @override
  final name = 'update';

  @override
  final description =
      'Update the installed SmartWork CLI itself (never the current '
      'Flutter project)';

  Directory get _sourceDirectory =>
      _sourceDirectoryOverride ??
      Directory.fromUri(Platform.script.resolve('..'));

  bool _looksLikeSmartworkCliCheckout(Directory dir) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (!pubspec.existsSync()) return false;
    return RegExp(r'^name:\s*smartwork_cli\s*$', multiLine: true)
        .hasMatch(pubspec.readAsStringSync());
  }

  @override
  Future<void> run() async {
    final sourceDir = _sourceDirectory;

    if (!_looksLikeSmartworkCliCheckout(sourceDir)) {
      print(
        'smartwork update: could not locate smartwork_cli\'s own source '
        'checkout (expected a pubspec.yaml declaring "name: smartwork_cli" '
        'under ${sourceDir.path}). If this CLI was relocated outside its '
        'source checkout, update it manually: pull the latest source and '
        'run "dart pub global activate --source path ." from '
        'smartwork_cli/.',
      );
      exitCode = 1;
      return;
    }

    print('Updating SmartWork CLI from ${sourceDir.path} ...');

    final pull = await _runProcess(
      'git',
      ['pull'],
      workingDirectory: sourceDir.path,
    );
    _relay(pull);
    if (pull.exitCode != 0) {
      print(
        'smartwork update failed while pulling the latest source. See the '
        'output above for details.',
      );
      exitCode = pull.exitCode;
      return;
    }

    final activate = await _runProcess(
      'dart',
      ['pub', 'global', 'activate', '--source', 'path', '.'],
      workingDirectory: sourceDir.path,
    );
    _relay(activate);
    if (activate.exitCode != 0) {
      print(
        'smartwork update failed while activating the updated CLI. See '
        'the output above for details.',
      );
      exitCode = activate.exitCode;
      return;
    }

    print('SmartWork CLI updated successfully.');
  }

  void _relay(ProcessResult result) {
    final out = result.stdout.toString().trimRight();
    final err = result.stderr.toString().trimRight();
    if (out.isNotEmpty) print(out);
    if (err.isNotEmpty) print(err);
  }
}
