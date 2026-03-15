import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_invite_model.dart';
import '../services/invite_api_service.dart';

// TODO: Connect to auth provider to get base URL and auth token
// API Service Provider
final inviteApiServiceProvider = Provider<InviteApiService>((ref) {
  // Placeholder - should be initialized with real base URL and token from auth
  return InviteApiService(
    baseUrl: 'http://localhost:8080',
    authToken: null, // TODO: Get from auth provider
  );
});

// Query Providers

/// Provides list of pending invitations for current user
final pendingInvitesProvider =
    FutureProvider<List<ChatInviteModel>>((ref) async {
  final apiService = ref.watch(inviteApiServiceProvider);
  return apiService.fetchPendingInvites();
});

/// Provides list of sent invitations for current user
final sentInvitesProvider =
    FutureProvider<List<ChatInviteModel>>((ref) async {
  final apiService = ref.watch(inviteApiServiceProvider);
  return apiService.fetchSentInvites();
});

/// Provides count of pending invitations (for badge display)
final pendingInviteCountProvider = FutureProvider<int>((ref) async {
  final apiService = ref.watch(inviteApiServiceProvider);
  return apiService.getPendingInviteCount();
});

// Mutation Providers (State Notifiers for side effects)

/// Provider for send invite mutation state and operations
final sendInviteMutationProvider =
    StateNotifierProvider<SendInviteMutationNotifier, SendInviteState>((ref) {
  final apiService = ref.watch(inviteApiServiceProvider);
  return SendInviteMutationNotifier(apiService, ref);
});

/// Provider for accept invite mutation state and operations
final acceptInviteMutationProvider =
    StateNotifierProvider<AcceptInviteMutationNotifier, AcceptInviteState>(
        (ref) {
  final apiService = ref.watch(inviteApiServiceProvider);
  return AcceptInviteMutationNotifier(apiService, ref);
});

/// Provider for decline invite mutation state and operations
final declineInviteMutationProvider =
    StateNotifierProvider<DeclineInviteMutationNotifier, DeclineInviteState>(
        (ref) {
  final apiService = ref.watch(inviteApiServiceProvider);
  return DeclineInviteMutationNotifier(apiService, ref);
});

// State classes for mutations

class SendInviteState {
  final bool isLoading;
  final ChatInviteModel? data;
  final String? error;

  SendInviteState({
    this.isLoading = false,
    this.data,
    this.error,
  });

  SendInviteState copyWith({
    bool? isLoading,
    ChatInviteModel? data,
    String? error,
  }) {
    return SendInviteState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }
}

class AcceptInviteState {
  final bool isLoading;
  final ChatInviteModel? data;
  final String? error;

  AcceptInviteState({
    this.isLoading = false,
    this.data,
    this.error,
  });

  AcceptInviteState copyWith({
    bool? isLoading,
    ChatInviteModel? data,
    String? error,
  }) {
    return AcceptInviteState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }
}

class DeclineInviteState {
  final bool isLoading;
  final ChatInviteModel? data;
  final String? error;

  DeclineInviteState({
    this.isLoading = false,
    this.data,
    this.error,
  });

  DeclineInviteState copyWith({
    bool? isLoading,
    ChatInviteModel? data,
    String? error,
  }) {
    return DeclineInviteState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }
}

// State Notifier implementations

class SendInviteMutationNotifier extends StateNotifier<SendInviteState> {
  final InviteApiService _apiService;
  final Ref _ref;

  SendInviteMutationNotifier(this._apiService, this._ref)
      : super(SendInviteState());

  /// Send invitation and invalidate queries on success
  Future<void> sendInvite(String recipientId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _apiService.sendInvite(recipientId);
      state = state.copyWith(isLoading: false, data: result);
      
      // Invalidate sent invites query to refresh list
      _ref.invalidate(sentInvitesProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Reset state
  void reset() {
    state = SendInviteState();
  }
}

class AcceptInviteMutationNotifier extends StateNotifier<AcceptInviteState> {
  final InviteApiService _apiService;
  final Ref _ref;

  AcceptInviteMutationNotifier(this._apiService, this._ref)
      : super(AcceptInviteState());

  /// Accept invitation and invalidate queries on success
  Future<void> acceptInvite(String inviteId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _apiService.acceptInvite(inviteId);
      state = state.copyWith(isLoading: false, data: result);
      
      // Invalidate both queries to refresh lists
      _ref.invalidate(pendingInvitesProvider);
      _ref.invalidate(pendingInviteCountProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Reset state
  void reset() {
    state = AcceptInviteState();
  }
}

class DeclineInviteMutationNotifier
    extends StateNotifier<DeclineInviteState> {
  final InviteApiService _apiService;
  final Ref _ref;

  DeclineInviteMutationNotifier(this._apiService, this._ref)
      : super(DeclineInviteState());

  /// Decline invitation and invalidate queries on success
  Future<void> declineInvite(String inviteId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _apiService.declineInvite(inviteId);
      state = state.copyWith(isLoading: false, data: result);
      
      // Invalidate both queries to refresh lists
      _ref.invalidate(pendingInvitesProvider);
      _ref.invalidate(pendingInviteCountProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Reset state
  void reset() {
    state = DeclineInviteState();
  }
}
