# API Contract: Health Check Endpoint

**Endpoint**: `GET /health`  
**Purpose**: Server health and liveness check for monitoring and orchestration  
**Audience**: Docker Compose health checks, deployment monitoring, Flutter app startup verification

## Request

```
GET /health HTTP/1.1
Host: localhost:8081
```

## Response (Success)

**Status**: `200 OK`

**Headers**:
```
Content-Type: application/json
Cache-Control: no-cache, no-store
```

**Body**:
```json
{
  "status": "ok",
  "timestamp": "2026-03-10T14:30:45.123456Z",
  "uptime_ms": 45678
}
```

**Field Descriptions**:
- `status` (string): Always `"ok"` on success. Other services (auth, database) checks deferred to future features.
- `timestamp` (string): ISO 8601 timestamp of the response, server time (UTC)
- `uptime_ms` (number): Milliseconds since server process started

## Response (Unavailable)

**Status**: `503 Service Unavailable`

**Headers**:
```
Content-Type: application/json
```

**Body**:
```json
{
  "status": "unavailable",
  "reason": "database_not_ready",
  "timestamp": "2026-03-10T14:30:10.000000Z"
}
```

**Scenarios**:
- Database connection lost: `"database_not_ready"`
- Server shutting down: `"shutdown_in_progress"`
- Internal error: `"internal_error"`

## Docker Compose Health Check

```yaml
services:
  serverpod:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081/health"]
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 10s
```

**Behavior**:
- First check starts after 10s (start_period) to allow Serverpod to initialize
- Checks every 10s (interval); expects response within 3s (timeout)
- If 3 consecutive checks fail (retries), container marked unhealthy
- Docker Compose will not consider the service healthy until 1 successful check

## Flutter App Connection Logic

```dart
Future<bool> isBackendHealthy() async {
  try {
    final response = await http.get(
      Uri.parse('$backendUrl/health'),
    ).timeout(Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['status'] == 'ok';
    }
    return false;
  } catch (e) {
    return false;  // Network error, timeout, or JSON parse failure
  }
}

// Startup sequence with retry
Future<bool> connectToBackend() async {
  final delays = [100, 500, 2000, 5000, 10000];  // ms
  
  for (int i = 0; i < delays.length; i++) {
    if (await isBackendHealthy()) {
      return true;  // Success
    }
    if (i < delays.length - 1) {
      await Future.delayed(Duration(milliseconds: delays[i]));
    }
  }
  
  return false;  // All retries exhausted
}
```

## Load Testing Considerations

- Health check endpoint MUST be fast (<50ms) even under load
- Health checks are read-only (no side effects, no database writes)
- Suitable for extremely high-frequency checks (e.g., Kubernetes probes every 1s)

## Future Extensions (Out of Scope for This Feature)

Future health check versions may include:
- `"dependencies"`: Database, Redis, external API connectivity
- `"version"`: Backend application version
- `"build"`: Build timestamp, git commit SHA
- `"ready"`: Boolean indicating if service accepts traffic (vs. initializing)

These are NOT included in v1 health endpoint (this feature).

## Testing

**Unit Test**:
```dart
test('Health endpoint returns ok status', () async {
  final response = await client.get('/health');
  expect(response.statusCode, 200);
  expect(response.json['status'], 'ok');
  expect(response.json, containsKey('timestamp'));
  expect(response.json, containsKey('uptime_ms'));
});
```

**Integration Test**:
```dart
test('Health check accessible after docker-compose up', () async {
  // Run via integration test harness
  final isHealthy = await isBackendHealthy();
  expect(isHealthy, true);
});
```
