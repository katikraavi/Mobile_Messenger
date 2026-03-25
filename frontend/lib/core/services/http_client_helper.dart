import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Custom HTTP client for development that handles certificate issues on emulators
/// 
/// This client catches certificate validation errors that commonly occur on Android
/// emulators and retries the request with a custom HttpClient that accepts all
/// certificates in development mode.
class DevHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      return await _inner.send(request);
    } on SocketException catch (e) {
      if (e.toString().contains('certificate') || 
          e.toString().contains('CERTIFICATE')) {
        // Certificate validation error - try again with custom client
        debugPrint('[DevHttpClient] Certificate error on ${request.url.host}, retrying with custom client');
        
        final httpClient = HttpClient()
          ..badCertificateCallback = (cert, host, port) {
            debugPrint('[DevHttpClient] Accepting certificate for $host:$port (dev mode)');
            return true; // Accept all certificates in development
          };
        
        final uri = request.url;
        final method = request.method;
        
        final httprequest = await httpClient.openUrl(method, uri);
        request.headers.forEach((name, value) {
          httprequest.headers.add(name, value);
        });
        
        if (request is http.Request) {
          httprequest.add(request.bodyBytes);
        }
        
        final response = await httprequest.close();
        final bytes = await response.fold<List<int>>([], (list, chunk) => list..addAll(chunk));
        
        // Convert HttpHeaders to Map<String, String>
        final headers = <String, String>{};
        response.headers.forEach((name, values) {
          if (values.isNotEmpty) {
            headers[name] = values.first;
          }
        });
        
        return http.StreamedResponse(
          Future.value(bytes).asStream(),
          response.statusCode,
          contentLength: bytes.length,
          request: request,
          headers: headers,
          isRedirect: response.isRedirect,
        );
      }
      rethrow;
    }
  }
}

/// Global HTTP client instance that handles certificate issues
final devHttpClient = DevHttpClient();
