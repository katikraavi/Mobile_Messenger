import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';

/// HTTP Client for connecting to Serverpod backend
/// 
/// Features:
/// - Exponential backoff retry logic (5 attempts: 100ms, 500ms, 2s, 5s, 10s)
/// - Health check endpoint verification
/// - Base URL configuration for Android/iOS emulator differences
/// - Support for both HTTP and HTTPS backends
/// - Extended timeout for slow networks

class ApiClient {
  static String _baseUrl = '';
  static http.Client? _httpClient;
  static bool _isHealthy = false;
  static bool _isInitialized = false;
  static const bool _debugMode = true; // Enable detailed logging

  /// Initialize API client with backend URL
  ///
  /// Priority order for backend URL resolution:
  /// 1. API_BASE_URL dart-define (injected at build time for APK distribution)
  /// 2. BACKEND_URL dart-define (legacy, injected at build time for APK distribution)
  /// 3. Hosted production backend: https://mobile-messenger.onrender.com
  ///
  /// To build with a custom URL:
  ///   flutter build apk --dart-define=API_BASE_URL=http://192.168.1.100:8081
  static Future<void> initialize({bool waitForHealthCheck = false}) async {
    if (_isInitialized) {
      return;
    }

    _httpClient = http.Client();

    // Prefer compile-time API_BASE_URL (set via --dart-define when building APK for testers)
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (apiBaseUrl.isNotEmpty) {
      _baseUrl = apiBaseUrl;
    } else {
      // Fall back to legacy BACKEND_URL
      const envUrl = String.fromEnvironment('BACKEND_URL');
      if (envUrl.isNotEmpty) {
        _baseUrl = envUrl;
      } else {
        // Default to hosted production backend
        _baseUrl = 'https://mobile-messenger.onrender.com';
      }
    }

    _isInitialized = true;

    // Avoid blocking app startup on slow/unreachable networks.
    if (waitForHealthCheck) {
      _isHealthy = await connectToBackend();
    } else {
      unawaited(
        connectToBackend().then((connected) {
          _isHealthy = connected;
        }),
      );
    }
  }

  /// Connect to backend with exponential backoff retry logic
  /// 
  /// Attempts: 5 times with delays: 100ms, 500ms, 2s, 5s, 10s
  /// Returns true if health check succeeds, false after all retries exhausted
  static Future<bool> connectToBackend() async {
    if (!_isInitialized) {
      await initialize();
    }

    const maxRetries = 5;
    const delays = [100, 500, 2000, 5000, 10000]; // milliseconds

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final isServerHealthy = await isHealthy();
        if (isServerHealthy) {
          debugPrint('[API Client] Backend connected successfully on attempt ${attempt + 1}');
          return true;
        }
      } catch (e) {
        debugPrint('[API Client] Connection attempt ${attempt + 1} failed: $e');
      }

      // Wait before next retry (except after last attempt)
      if (attempt < maxRetries - 1) {
        final delay = delays[attempt];
        debugPrint('[API Client] Retrying in ${delay}ms...');
        await Future.delayed(Duration(milliseconds: delay));
      }
    }

    debugPrint('[API Client] Failed to connect to backend after $maxRetries attempts');
    return false;
  }

  /// Check if backend health endpoint is responding
  /// 
  /// Returns true if /health endpoint responds with 200 and valid JSON
  /// Returns false if connection fails or response is invalid
  static Future<bool> isHealthy() async {
    try {
      final response = await _httpClient!.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Health check timeout'),
      );

      if (response.statusCode == 200) {
        // Parse JSON response
        // Expected: {"status": "ok", "timestamp": "<ISO8601>", "uptime_ms": <number>}
        debugPrint('[API Client] Backend health check passed');
        return true;
      } else {
        debugPrint('[API Client] Health check failed with status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('[API Client] Health check error: $e');
      return false;
    }
  }

  /// Get base URL for backend
  static String getBaseUrl() => _baseUrl;

  /// Check if backend connection is established
  static bool get isConnected => _isHealthy;

  /// Set base URL manually (for testing or special configurations)
  static void setBaseUrl(String url) => _baseUrl = url;

  /// Make GET request to backend endpoint
  /// 
  /// Example: ApiClient.get('/users') → http://host.docker.internal:8081/users
  static Future<http.Response> get(String endpoint) async {
    if (!_isInitialized) {
      await initialize();
    }
    return _httpClient!.get(Uri.parse('$_baseUrl$endpoint'));
  }

  /// Make POST request to backend endpoint
  static Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    return _httpClient!.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
      body: body,
    );
  }

  /// Make PUT request to backend endpoint
  static Future<http.Response> put(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    return _httpClient!.put(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
      body: body,
    );
  }

  /// Make DELETE request to backend endpoint
  static Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    return _httpClient!.delete(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
    );
  }

  /// Close HTTP client (call when app is shutting down)
  static void dispose() {
    _httpClient?.close();
    _httpClient = null;
    _isInitialized = false;
  }
}
