import '../models/mock_mapping.dart';

class MockServerStartException implements Exception {
  final String message;

  MockServerStartException(this.message);

  @override
  String toString() => 'Mock server failed to start: $message';
}

abstract class MockServer {
  Future<void> start();

  Future<void> stop();

  Future<bool> isReady();

  Future<void> loadMappings(List<MockMapping> mappings);

  Future<void> reset();
}
