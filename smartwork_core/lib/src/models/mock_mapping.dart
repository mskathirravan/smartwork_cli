class MockMapping {
  final String name;

  final String method;

  final String? urlPath;

  final String? urlPathPattern;

  final String? requestBodyPattern;

  final int responseStatus;

  final Map<String, dynamic>? responseBody;

  final Map<String, String> responseHeaders;

  MockMapping({
    required this.name,
    required this.method,
    this.urlPath,
    this.urlPathPattern,
    this.requestBodyPattern,
    required this.responseStatus,
    this.responseBody,
    this.responseHeaders = const {'Content-Type': 'application/json'},
  }) : assert(
          (urlPath == null) != (urlPathPattern == null),
          'exactly one of urlPath/urlPathPattern must be set',
        );

  Map<String, dynamic> toWireMockJson() => {
        'request': {
          'method': method,
          if (urlPath != null) 'urlPath': urlPath,
          if (urlPathPattern != null) 'urlPathPattern': urlPathPattern,
          if (requestBodyPattern != null)
            'bodyPatterns': [
              {'matches': requestBodyPattern},
            ],
        },
        'response': {
          'status': responseStatus,
          'headers': responseHeaders,
          if (responseBody != null) 'jsonBody': responseBody,
        },
      };

  Map<String, dynamic> toJson() => {
        'name': name,
        'method': method,
        'urlPath': urlPath,
        'urlPathPattern': urlPathPattern,
        'responseStatus': responseStatus,
      };
}
