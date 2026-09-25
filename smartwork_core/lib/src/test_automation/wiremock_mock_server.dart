import 'dart:convert';
import 'dart:io';

import '../flutter/flutter_bootstrap.dart' show ProcessRunner, runSystemProcess;
import '../models/mock_mapping.dart';
import 'mock_server.dart';
import 'mock_server_http.dart';
import 'wiremock_script_generator.dart';

class WireMockMockServer implements MockServer {
  final String projectPath;
  final Uri baseUrl;
  final ProcessRunner _runProcess;
  final MockServerHttpCall _httpCall;
  final WireMockScriptGenerator _scriptGenerator;
  final Duration readyTimeout;
  final Duration pollInterval;

  WireMockMockServer({
    required this.projectPath,
    Uri? baseUrl,
    ProcessRunner? runProcess,
    MockServerHttpCall? httpCall,
    WireMockScriptGenerator? scriptGenerator,
    this.readyTimeout = const Duration(seconds: 15),
    this.pollInterval = const Duration(milliseconds: 300),
  })  : baseUrl = baseUrl ?? Uri.parse('http://localhost:8080'),
        _runProcess = runProcess ?? runSystemProcess,
        _httpCall = httpCall ?? realMockServerHttpCall,
        _scriptGenerator = scriptGenerator ?? WireMockScriptGenerator();

  @override
  Future<void> start() async {
    await _scriptGenerator.ensureScripts(
      projectPath,
      exists: (path) => File(path).exists(),
    );

    try {
      await _runProcess(
        'bash',
        [WireMockScriptGenerator.startScriptPath],
        workingDirectory: projectPath,
      );
    } on ProcessException catch (e) {
      throw MockServerStartException(
        'the "bash" executable was not found on PATH, needed to run '
        '${WireMockScriptGenerator.startScriptPath}. (${e.message})',
      );
    }

    final deadline = DateTime.now().add(readyTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await isReady()) return;
      await Future.delayed(pollInterval);
    }

    throw MockServerStartException(
      'WireMock did not become ready at $baseUrl within '
      '${readyTimeout.inSeconds}s. Check '
      '${WireMockScriptGenerator.scriptsDir}/wiremock.log and '
      '${WireMockScriptGenerator.scriptsDir}/README.md.',
    );
  }

  @override
  Future<void> stop() async {
    try {
      await _runProcess(
        'bash',
        [WireMockScriptGenerator.stopScriptPath],
        workingDirectory: projectPath,
      );
    } on ProcessException {}
  }

  @override
  Future<bool> isReady() async {
    try {
      final response = await _httpCall('GET', _adminUrl('/mappings'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> loadMappings(List<MockMapping> mappings) async {
    final response = await _httpCall(
      'POST',
      _adminUrl('/mappings/import'),
      body: jsonEncode({
        'mappings': mappings.map((m) => m.toWireMockJson()).toList(),
        'importOptions': {'duplicatePolicy': 'OVERWRITE'},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MockServerStartException(
        'Failed to load ${mappings.length} mapping(s) into WireMock: '
        'HTTP ${response.statusCode}',
      );
    }
  }

  @override
  Future<void> reset() async {
    await _httpCall('POST', _adminUrl('/reset'));
  }

  Uri _adminUrl(String path) => baseUrl.replace(
        path: '${baseUrl.path}/__admin$path',
      );
}
