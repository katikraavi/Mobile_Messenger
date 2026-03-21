import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/resilient_http_client.dart';

/// Network state provider that watches connectivity changes
final networkStateProvider = StreamProvider<NetworkState>((ref) {
  final listener = NetworkStateListener();
  
  // Start monitoring when provider is watched
  listener.startMonitoring();
  
  // Return the stream and manage lifecycle
  ref.onDispose(() {
    listener.stopMonitoring();
  });
  
  return listener.stateStream;
});

/// Current network state provider (latest value)
final currentNetworkStateProvider = StateProvider<NetworkState>((ref) {
  // Watch the stream and update state when it changes
  final state = ref.watch(networkStateProvider);
  
  return state.when(
    data: (networkState) => networkState,
    loading: () => NetworkState.unknown,
    error: (_, __) => NetworkState.unknown,
  );
});

/// Indicates if device is online
final isOnlineProvider = Provider<bool>((ref) {
  final state = ref.watch(currentNetworkStateProvider);
  return state.isOnline;
});

/// Indicates if device is possibly offline or degraded
final isOfflineProvider = Provider<bool>((ref) {
  final state = ref.watch(currentNetworkStateProvider);
  return state.isOffline;
});

/// Network status with user-friendly message
final networkStatusProvider = Provider<Map<String, dynamic>>((ref) {
  final state = ref.watch(currentNetworkStateProvider);
  
  return {
    'state': state,
    'description': state.description,
    'isOnline': state.isOnline,
    'isOffline': state.isOffline,
    'shouldShowWarning': state != NetworkState.online,
  };
});
