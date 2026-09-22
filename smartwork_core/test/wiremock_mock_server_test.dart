import 'dart:convert';
import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('WireMockScriptGenerator', () {
    late String tempDir;

    setUp(() async {
      tempDir = (await Directory.systemTemp.createTemp('wiremock_gen_')).path;
    });

    tearDown(() async {
      await Directory(tempDir).delete(recursive: true);
    });

    test('writes start.sh, stop.sh, and README.md when none exist', () async {
      await WireMockScriptGenerator().ensureScripts(
        tempDir,
        exists: (path) => File(path).exists(),
      );

      expect(
        await File('$tempDir/${WireMockScriptGenerator.startScriptPath}')
            .exists(),
        isTrue,
      );
      expect(
        await File('$tempDir/${WireMockScriptGenerator.stopScriptPath}')
            .exists(),
        isTrue,
      );
      expect(
        await File('$tempDir/${WireMockScriptGenerator.readmePath}').exists(),
        isTrue,
      );

      final start =
          await File('$tempDir/${WireMockScriptGenerator.startScriptPath}')
              .readAsString();
      expect(start, contains('#!/usr/bin/env bash'));
      expect(start, contains('java -jar'));
    });

    test('never overwrites a script that already exists', () async {
      final startPath = '$tempDir/${WireMockScriptGenerator.startScriptPath}';
      await Directory('$tempDir/${WireMockScriptGenerator.scriptsDir}')
          .create(recursive: true);
      await File(startPath).writeAsString('# customized by developer');

      await WireMockScriptGenerator().ensureScripts(
        tempDir,
        exists: (path) => File(path).exists(),
      );

      expect(await File(startPath).readAsString(), '# customized by developer');
    });
  });

  group('WireMockMockServer', () {
    late String tempDir;

    setUp(() async {
      tempDir = (await Directory.systemTemp.createTemp('wiremock_srv_')).path;
    });

    tearDown(() async {
      await Directory(tempDir).delete(recursive: true);
    });

    test('start() runs the start script, polls until ready, then returns',
        () async {
      final commandsRun = <String>[];
      var readyCallCount = 0;

      final server = WireMockMockServer(
        projectPath: tempDir,
        runProcess: (executable, arguments, {workingDirectory}) async {
          commandsRun.add('$executable ${arguments.join(' ')}');
          return ProcessResult(0, 0, '', '');
        },
        httpCall: (method, url, {body}) async {
          readyCallCount++;
          // Not ready on the first probe, ready from the second onward —
          // proves start() genuinely polls rather than assuming success
          // right after launching the script.
          final ready = readyCallCount >= 2;
          return MockServerHttpResponse(ready ? 200 : 503, '');
        },
        pollInterval: const Duration(milliseconds: 1),
      );

      await server.start();

      expect(commandsRun.single, contains('bash'));
      expect(commandsRun.single, contains('start.sh'));
      expect(readyCallCount, greaterThanOrEqualTo(2));
    });

    test('start() throws MockServerStartException if never ready', () async {
      final server = WireMockMockServer(
        projectPath: tempDir,
        runProcess: (executable, arguments, {workingDirectory}) async =>
            ProcessResult(0, 0, '', ''),
        httpCall: (method, url, {body}) async =>
            MockServerHttpResponse(503, ''),
        readyTimeout: const Duration(milliseconds: 20),
        pollInterval: const Duration(milliseconds: 5),
      );

      expect(server.start(), throwsA(isA<MockServerStartException>()));
    });

    test('isReady() reflects the admin /mappings endpoint status code',
        () async {
      final server = WireMockMockServer(
        projectPath: tempDir,
        httpCall: (method, url, {body}) async {
          expect(method, 'GET');
          expect(url.path, '/__admin/mappings');
          return MockServerHttpResponse(200, '');
        },
      );

      expect(await server.isReady(), isTrue);
    });

    test('isReady() returns false, never throws, on a connection failure',
        () async {
      final server = WireMockMockServer(
        projectPath: tempDir,
        httpCall: (method, url, {body}) async =>
            throw const SocketException('connection refused'),
      );

      expect(await server.isReady(), isFalse);
    });

    test('loadMappings() POSTs the real WireMock bulk-import shape', () async {
      Map<String, dynamic>? sentBody;

      final server = WireMockMockServer(
        projectPath: tempDir,
        httpCall: (method, url, {body}) async {
          expect(method, 'POST');
          expect(url.path, '/__admin/mappings/import');
          sentBody = jsonDecode(body!) as Map<String, dynamic>;
          return MockServerHttpResponse(200, '');
        },
      );

      await server.loadMappings([
        MockMapping(
          name: 'login success',
          method: 'POST',
          urlPath: '/login',
          responseStatus: 200,
          responseBody: {'token': 'abc'},
        ),
      ]);

      expect(sentBody!['mappings'], hasLength(1));
      expect(sentBody!['mappings'][0]['request']['urlPath'], '/login');
      expect(sentBody!['importOptions']['duplicatePolicy'], 'OVERWRITE');
    });

    test('loadMappings() throws when WireMock rejects the import', () async {
      final server = WireMockMockServer(
        projectPath: tempDir,
        httpCall: (method, url, {body}) async =>
            MockServerHttpResponse(500, 'boom'),
      );

      expect(
        () => server.loadMappings([
          MockMapping(
            name: 'x',
            method: 'GET',
            urlPath: '/x',
            responseStatus: 200,
          ),
        ]),
        throwsA(isA<MockServerStartException>()),
      );
    });

    test('reset() POSTs the real WireMock reset endpoint', () async {
      var called = false;
      final server = WireMockMockServer(
        projectPath: tempDir,
        httpCall: (method, url, {body}) async {
          called = true;
          expect(method, 'POST');
          expect(url.path, '/__admin/reset');
          return MockServerHttpResponse(200, '');
        },
      );

      await server.reset();
      expect(called, isTrue);
    });

    test(
        'stop() runs the stop script, and is safe to call without a '
        'prior start()', () async {
      final commandsRun = <String>[];
      final server = WireMockMockServer(
        projectPath: tempDir,
        runProcess: (executable, arguments, {workingDirectory}) async {
          commandsRun.add('$executable ${arguments.join(' ')}');
          return ProcessResult(0, 0, '', '');
        },
      );

      await server.stop();

      expect(commandsRun.single, contains('stop.sh'));
    });

    test(
        'start() throws a clear MockServerStartException, never a raw '
        'ProcessException, when bash is not on PATH', () async {
      final server = WireMockMockServer(
        projectPath: tempDir,
        runProcess: (executable, arguments, {workingDirectory}) async =>
            throw const ProcessException('bash', []),
      );

      await expectLater(
        server.start(),
        throwsA(isA<MockServerStartException>()),
      );
    });

    test(
        'stop() never throws, even when bash is not on PATH — it must '
        'always be safe to call from a finally block', () async {
      final server = WireMockMockServer(
        projectPath: tempDir,
        runProcess: (executable, arguments, {workingDirectory}) async =>
            throw const ProcessException('bash', []),
      );

      await server.stop();
    });
  });
}
