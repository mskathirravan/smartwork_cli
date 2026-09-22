import 'dart:convert';
import 'dart:io';

class MockServerHttpResponse {
  final int statusCode;
  final String body;

  MockServerHttpResponse(this.statusCode, this.body);
}

typedef MockServerHttpCall = Future<MockServerHttpResponse> Function(
  String method,
  Uri url, {
  String? body,
});

Future<MockServerHttpResponse> realMockServerHttpCall(
  String method,
  Uri url, {
  String? body,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, url);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(body);
    }
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    return MockServerHttpResponse(response.statusCode, responseBody);
  } finally {
    client.close(force: true);
  }
}
