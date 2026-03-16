import 'dart:async';

/// Automatic retry configuration
class RetryConfig {
  /// Maximum number of retry attempts
  final int maxAttempts;
  
  /// Initial delay between retries
  final Duration initialDelay;
  
  /// Maximum delay between retries
  final Duration maxDelay;
  
  /// Multiplier for exponential backoff (e.g., 2.0 means delay doubles each time)
  final double backoffMultiplier;
  
  /// Called to determine if an error should trigger a retry
  final bool Function(dynamic error, int attemptNumber)? shouldRetry;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.shouldRetry,
  });
  
  /// Standard config for network operations
  static const RetryConfig networkDefault = RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 30),
    backoffMultiplier: 2.0,
  );
  
  /// Aggressive retry for critical operations
  static const RetryConfig critical = RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(milliseconds: 300),
    maxDelay: Duration(seconds: 60),
    backoffMultiplier: 1.5,
  );
  
  /// No retry for operations that shouldn't be retried
  static const RetryConfig none = RetryConfig(
    maxAttempts: 0,
    initialDelay: Duration(),
    maxDelay: Duration(),
    backoffMultiplier: 1.0,
  );
}

/// Executes an operation with automatic retry and exponential backoff
class Retryable {
  /// Execute a future with automatic retry on failure
  static Future<T> execute<T>(
    Future<T> Function() operation, {
    RetryConfig? config,
    void Function(int, Duration)? onRetry,
    void Function(dynamic)? onFinalFailure,
  }) async {
    config ??= RetryConfig.networkDefault;
    int attempt = 0;
    Duration currentDelay = config.initialDelay;
    dynamic lastError;

    while (attempt <= config.maxAttempts) {
      try {
        attempt++;
        return await operation();
      } catch (e) {
        lastError = e;
        
        // Check if this error should trigger a retry
        if (config.shouldRetry != null && 
            !config.shouldRetry!(e, attempt)) {
          rethrow;
        }

        // Check if we've exhausted retries
        if (attempt > config.maxAttempts) {
          onFinalFailure?.call(e);
          rethrow;
        }

        // Calculate delay for next retry
        final nextDelay = Duration(
          milliseconds: (currentDelay.inMilliseconds * 
              config.backoffMultiplier).toInt().clamp(0, config.maxDelay.inMilliseconds),
        );

        onRetry?.call(attempt, nextDelay);
        
        // Wait before retrying
        await Future.delayed(nextDelay);
        currentDelay = nextDelay;
      }
    }

    throw lastError ?? Exception('Operation failed after $attempt attempts');
  }

  /// Execute a future with timeout and automatic retry
  static Future<T> executeWithTimeout<T>(
    Future<T> Function() operation, {
    Duration timeout = const Duration(seconds: 30),
    RetryConfig? config,
    void Function(int, Duration)? onRetry,
    void Function(dynamic)? onFinalFailure,
  }) async {
    config ??= RetryConfig.networkDefault;
    return execute(
      () => operation().timeout(timeout),
      config: config,
      onRetry: onRetry,
      onFinalFailure: onFinalFailure,
    );
  }
}

/// Retry strategy for different scenarios
class RetryStrategy {
  /// Strategy for transient network errors (retry with backoff)
  static RetryConfig transientNetwork() => const RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 10),
    backoffMultiplier: 2.0,
  );

  /// Strategy for server errors (retry with longer delays)
  static RetryConfig serverError() => const RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 30),
    backoffMultiplier: 2.0,
  );

  /// Strategy for rate limiting (aggressive backoff)
  static RetryConfig rateLimited() => const RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 120),
    backoffMultiplier: 3.0,
  );

  /// Strategy for timeout errors (quick retries)
  static RetryConfig timeout() => const RetryConfig(
    maxAttempts: 2,
    initialDelay: Duration(milliseconds: 800),
    maxDelay: Duration(seconds: 5),
    backoffMultiplier: 2.0,
  );

  /// Strategy for user-initiated actions (should not retry automatically)
  static RetryConfig noRetry() => RetryConfig.none;

  /// Determine appropriate strategy based on error
  static RetryConfig forError(dynamic error) {
    final errorStr = error.toString();
    
    if (errorStr.contains('429') || errorStr.contains('rate limit')) {
      return rateLimited();
    } else if (errorStr.contains('timeout')) {
      return timeout();
    } else if (errorStr.contains('500') || errorStr.contains('502') || errorStr.contains('503')) {
      return serverError();
    } else if (errorStr.contains('Connection') || errorStr.contains('Network')) {
      return transientNetwork();
    } else {
      return RetryConfig.networkDefault;
    }
  }
}
