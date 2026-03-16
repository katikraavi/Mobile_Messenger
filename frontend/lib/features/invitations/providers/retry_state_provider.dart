import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks retry state for an operation
class RetryState {
  final int currentAttempt;
  final int maxAttempts;
  final bool isRetrying;
  final int? nextRetrySeconds;
  final String? lastError;

  const RetryState({
    this.currentAttempt = 0,
    this.maxAttempts = 3,
    this.isRetrying = false,
    this.nextRetrySeconds,
    this.lastError,
  });

  bool get canRetry => currentAttempt < maxAttempts;
  int get remainingAttempts => maxAttempts - currentAttempt;

  RetryState copyWith({
    int? currentAttempt,
    int? maxAttempts,
    bool? isRetrying,
    int? nextRetrySeconds,
    String? lastError,
  }) {
    return RetryState(
      currentAttempt: currentAttempt ?? this.currentAttempt,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      isRetrying: isRetrying ?? this.isRetrying,
      nextRetrySeconds: nextRetrySeconds ?? this.nextRetrySeconds,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Provider for managing retry state for individual operations
class RetryStateNotifier extends StateNotifier<RetryState> {
  RetryStateNotifier() : super(const RetryState());

  void startRetry(int maxAttempts) {
    state = RetryState(
      currentAttempt: 1,
      maxAttempts: maxAttempts,
      isRetrying: true,
    );
  }

  void updateAttempt(int attempt, Duration nextDelay) {
    state = state.copyWith(
      currentAttempt: attempt,
      nextRetrySeconds: nextDelay.inSeconds,
    );
  }

  void failureOccurred(String error) {
    state = state.copyWith(
      lastError: error,
      isRetrying: false,
    );
  }

  void success() {
    state = const RetryState();
  }

  void reset() {
    state = const RetryState();
  }
}

/// Global retry state notifier provider
final globalRetryStateProvider = 
    StateNotifierProvider<RetryStateNotifier, RetryState>((ref) {
  return RetryStateNotifier();
});

/// Operation-specific retry state (for future enhancement)
final operationRetryProvider = 
    StateNotifierProvider.family<RetryStateNotifier, RetryState, String>((ref, operationId) {
  return RetryStateNotifier();
});

/// Monitor network retry status
final networkRetryStatusProvider = Provider<Map<String, dynamic>>((ref) {
  final retryState = ref.watch(globalRetryStateProvider);
  
  return {
    'isRetrying': retryState.isRetrying,
    'attempt': retryState.currentAttempt,
    'maxAttempts': retryState.maxAttempts,
    'canRetry': retryState.canRetry,
    'remainingAttempts': retryState.remainingAttempts,
    'nextRetrySeconds': retryState.nextRetrySeconds,
    'lastError': retryState.lastError,
  };
});
