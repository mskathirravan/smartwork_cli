import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smartwork_core/smartwork_core.dart';

class ServiceCommand extends Command {
  final String projectPath;

  ServiceCommand({this.projectPath = '.'});

  @override
  final name = 'service';

  @override
  final description =
      'Add or remove a Production Service in the current project';

  @override
  String get invocation => 'smartwork service add <name> | remove <name>';

  @override
  Future<void> run() async {
    final args = argResults!.rest;

    if (args.isEmpty) {
      print('❌ Usage: smartwork service add <name> | '
          'smartwork service remove <name>');
      exitCode = 1;
      return;
    }

    final action = args.first;
    if (action != 'add' && action != 'remove') {
      print('❌ Unknown action "$action". Usage: smartwork service add '
          '<name> | smartwork service remove <name>');
      exitCode = 1;
      return;
    }

    if (args.length < 2) {
      print('❌ Service name is required. '
          'Usage: smartwork service $action <name>');
      exitCode = 1;
      return;
    }
    final serviceId = args[1];

    try {
      if (action == 'add') {
        await ServiceLifecycle().addService(
          projectPath: projectPath,
          serviceId: serviceId,
        );
        _reportAddSuccess(serviceId);
      } else {
        await ServiceLifecycle().removeService(
          projectPath: projectPath,
          serviceId: serviceId,
        );
        _reportRemoveSuccess(serviceId);
      }
    } on FileSystemException {
      print('❌ No Smartwork project found in the current directory.');
      print('   Run "smartwork init" first.');
      exitCode = 1;
    } on UnknownServiceException catch (e) {
      print('❌ $e');
      print('   Valid services: '
          '${Service.values.map((s) => s.id).join(', ')}');
      exitCode = 1;
    } on ServiceAlreadySelectedException catch (e) {
      print('❌ $e — nothing was changed.');
      exitCode = 1;
    } on ServiceNotSelectedException catch (e) {
      print('❌ $e — nothing was changed.');
      exitCode = 1;
    }
  }

  void _reportAddSuccess(String serviceId) {
    final service = Service.values.firstWhere((s) => s.id == serviceId);
    print('✔ Service added: ${service.displayName}\n');
    print('Generated:');
    print('  • lib/services/${service.folderName}/${service.fileName}');
    print('  • test/services/${service.folderName}/'
        '${service.fileName.replaceAll('.dart', '')}_test.dart\n');
    if (service.hasInitialize) {
      print('✔ Bootstrap updated: ${service.className}.instance.'
          'initialize() now runs at startup.');
    } else {
      print('ℹ Bootstrap unchanged: ${service.className} has no '
          'initialize() to call.');
    }
    if (service == Service.deeplink) {
      _reportDeeplinkRoutingExample();
    }
  }

  void _reportDeeplinkRoutingExample() {
    print('\nDeeplinkService never navigates on its own — AppRouter stays '
        'the single routing authority. Example: forwarding an incoming '
        'link to AppRouter and passing its query parameters as route '
        'arguments (requires a GlobalKey<NavigatorState> on MaterialApp, '
        'since this runs before any BuildContext exists):\n');
    print('  DeeplinkService.instance.uriStream.listen((uri) {');
    print('    navigatorKey.currentState?.pushNamed(');
    print('      uri.path,');
    print('      arguments: uri.queryParameters,');
    print('    );');
    print('  });');
  }

  void _reportRemoveSuccess(String serviceId) {
    final service = Service.values.firstWhere((s) => s.id == serviceId);
    print('✔ Service removed: ${service.displayName}\n');
    print('Removed lib/services/${service.folderName}/ and its generated '
        'test.');
    print('✔ Bootstrap updated: no longer initializes ${service.className}.');
  }
}
