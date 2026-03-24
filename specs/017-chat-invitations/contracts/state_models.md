# Frontend State Models Contract

**Date**: 2026-03-15 | **Feature**: Chat Invitations

---

## Overview

This document defines the Riverpod state models and provider contracts for the Chat Invitations feature frontend. All models use Freezed for immutability and JSON serialization.

---

## Core Models

### ChatInviteModel

**File**: `frontend/lib/features/invitations/models/chat_invite_model.dart`

**JSON Serialization Example**:
```json
{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "senderId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "senderName": "Alice",
  "senderAvatarUrl": "https://api.example.com/avatars/a1b2c3d4.jpg",
  "recipientId": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
  "recipientName": "Bob",
  "recipientAvatarUrl": "https://api.example.com/avatars/b2c3d4e5.jpg",
  "status": "pending",
  "createdAt": "2026-03-15T10:00:00Z",
  "updatedAt": "2026-03-15T10:00:00Z"
}
```

**Dart Model**:
```dart
@freezed
class ChatInvite with _$ChatInvite {
  const factory ChatInvite({
    required String id,
    required String senderId,
    required String senderName,
    required String? senderAvatarUrl,
    required String recipientId,
    required String recipientName,
    required String? recipientAvatarUrl,
    required InviteStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ChatInvite;

  factory ChatInvite.fromJson(Map<String, dynamic> json) =>
      _$ChatInviteFromJson(json);

  Map<String, dynamic> toJson() => _$ChatInviteToJson(this);

  /// Helper to get the "other" user (not current user)
  /// Used in UI to display who sent/received the invite
  String get otherUserId => senderId; // context determines sender vs recipient
  String get otherUserName => senderName;
  String? get otherUserAvatarUrl => senderAvatarUrl;
}

enum InviteStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined');

  final String value;
  const InviteStatus(this.value);

  factory InviteStatus.fromString(String value) {
    return InviteStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => InviteStatus.pending,
    );
  }

  bool get isPending => this == InviteStatus.pending;
  bool get isAccepted => this == InviteStatus.accepted;
  bool get isDeclined => this == InviteStatus.declined;

  String get displayName {
    switch (this) {
      case InviteStatus.pending:
        return 'Pending';
      case InviteStatus.accepted:
        return 'Accepted';
      case InviteStatus.declined:
        return 'Declined';
    }
  }
}
```

---

### InvitationsState

**File**: `frontend/lib/features/invitations/providers/invites_provider.dart`

**Purpose**: Root state for all invitations data and UI state

**Definition**:
```dart
@freezed
class InvitationsState with _$InvitationsState {
  const factory InvitationsState({
    required List<ChatInvite> pendingInvites,
    required List<ChatInvite> sentInvites,
    required int unreadCount,
    required bool isLoading,
    required bool isSending,
    required String? error,
  }) = _InvitationsState;

  factory InvitationsState.initial() => const InvitationsState(
    pendingInvites: [],
    sentInvites: [],
    unreadCount: 0,
    isLoading: false,
    isSending: false,
    error: null,
  );

  /// Get count of pending invites received
  int get pendingCount => pendingInvites.length;

  /// Get count of sent invites pending recipient action
  int get sentCount => sentInvites.where((i) => i.isPending).length;

  /// Total unread (badge count)
  int get totalUnread => unreadCount;

  /// Is in any loading state
  bool get isInFlight => isLoading || isSending;
}
```

**State Transitions**:
- `isLoading = true` during fetch operations (pending, sent invites)
- `isSending = true` during send/accept/decline operations
- `error` set when any operation fails
- `pendingInvites` updated after fetches or mutations
- `unreadCount` updated on fetch or when new invites arrive

---

### SendInviteState

**File**: `frontend/lib/features/invitations/providers/send_invite_provider.dart`

**Purpose**: Encapsulate async state for sending a new invitation

```dart
@freezed
class SendInviteState with _$SendInviteState {
  const factory SendInviteState.initial() = SendInviteInitial;
  const factory SendInviteState.loading() = SendInviteLoading;
  const factory SendInviteState.success(ChatInvite invite) = SendInviteSuccess;
  const factory SendInviteState.error(String message) = SendInviteError;

  bool get isLoading => this is SendInviteLoading;
  bool get isSuccess => this is SendInviteSuccess;
  bool get isError => this is SendInviteError;

  T? maybeWhen<T>({
    T? Function()? initial,
    T? Function()? loading,
    T? Function(ChatInvite)? success,
    T? Function(String)? error,
    required T? Function() orElse,
  }) {
    if (this is SendInviteInitial) return initial?.call();
    if (this is SendInviteLoading) return loading?.call();
    if (this is SendInviteSuccess) 
      return success?.call((this as SendInviteSuccess).invite);
    if (this is SendInviteError) 
      return error?.call((this as SendInviteError).message);
    return orElse?.call();
  }
}
```

---

### AcceptInviteState

**File**: `frontend/lib/features/invitations/providers/accept_invite_provider.dart`

**Purpose**: Encapsulate async state for accepting an invitation

```dart
@freezed
class AcceptInviteState with _$AcceptInviteState {
  const factory AcceptInviteState.initial() = AcceptInviteInitial;
  const factory AcceptInviteState.loading() = AcceptInviteLoading;
  const factory AcceptInviteState.success({
    required ChatInvite invite,
    required ChatResponse chat,
  }) = AcceptInviteSuccess;
  const factory AcceptInviteState.error(String message) = AcceptInviteError;

  bool get isLoading => this is AcceptInviteLoading;
  bool get isSuccess => this is AcceptInviteSuccess;
  bool get isError => this is AcceptInviteError;
}

@freezed
class ChatResponse with _$ChatResponse {
  const factory ChatResponse({
    required String id,
    required List<String> participants,
    required DateTime createdAt,
    required String? inviteId,
  }) = _ChatResponse;

  factory ChatResponse.fromJson(Map<String, dynamic> json) =>
      _$ChatResponseFromJson(json);
}
```

---

## Provider Contracts

### Fetch Providers

#### `pendingInvitesProvider`
```dart
final pendingInvitesProvider = FutureProvider<List<ChatInvite>>((ref) async {
  final apiService = ref.watch(inviteApiServiceProvider);
  return apiService.fetchPendingInvites();
});
```

**Contract**:
- **Returns**: `Future<List<ChatInvite>>`
- **Errors**: Throws on network/auth failures
- **Cache**: Invalidated after send/accept/decline mutations
- **Refresh**: Manual via `ref.refresh(pendingInvitesProvider)`

---

#### `sentInvitesProvider`
```dart
final sentInvitesProvider = FutureProvider<List<ChatInvite>>((ref) async {
  final apiService = ref.watch(inviteApiServiceProvider);
  return apiService.fetchSentInvites();
});
```

**Contract**:
- **Returns**: `Future<List<ChatInvite>>`
- **Errors**: Throws on network/auth failures
- **Cache**: Invalidated after send mutations
- **Refresh**: Manual via `ref.refresh(sentInvitesProvider)`

---

#### `inviteCountProvider`
```dart
final inviteCountProvider = FutureProvider<int>((ref) async {
  final pending = await ref.watch(pendingInvitesProvider.future);
  return pending.length;
});
```

**Contract**:
- **Returns**: `Future<int>` - total unread invites
- **Usage**: Drives badge count on Invitations tab
- **Updates**: Automatically when `pendingInvitesProvider` updates

---

### Mutation Providers

#### `sendInviteMutationProvider`
```dart
final sendInviteMutationProvider = 
  StateNotifierProvider<SendInviteNotifier, SendInviteState>((ref) {
    return SendInviteNotifier(ref);
  });

class SendInviteNotifier extends StateNotifier<SendInviteState> {
  SendInviteNotifier(Ref ref) : super(const SendInviteState.initial());

  Future<void> sendInvite(String recipientId) async {
    state = const SendInviteState.loading();
    try {
      final apiService = ref.read(inviteApiServiceProvider);
      final invite = await apiService.sendInvite(recipientId);
      state = SendInviteState.success(invite);
      // Invalidate sent invites list
      ref.invalidate(sentInvitesProvider);
    } catch (error) {
      state = SendInviteState.error(error.toString());
    }
  }
}
```

**Contract**:
- **Method**: `sendInvite(String recipientId)`
- **Returns**: `Future<void>` (state changes via StateNotifier)
- **Success State**: Includes created ChatInvite
- **Error State**: Includes error message
- **Side Effects**: Invalidates `sentInvitesProvider`

---

#### `acceptInviteMutationProvider`
```dart
final acceptInviteMutationProvider = 
  StateNotifierProvider<AcceptInviteNotifier, AcceptInviteState>((ref) {
    return AcceptInviteNotifier(ref);
  });

class AcceptInviteNotifier extends StateNotifier<AcceptInviteState> {
  AcceptInviteNotifier(Ref ref) : super(const AcceptInviteState.initial());

  Future<void> acceptInvite(String inviteId) async {
    state = const AcceptInviteState.loading();
    try {
      final apiService = ref.read(inviteApiServiceProvider);
      final response = await apiService.acceptInvite(inviteId);
      state = AcceptInviteState.success(
        invite: response.invite,
        chat: response.chat,
      );
      // Invalidate both lists + chat list
      ref.invalidate(pendingInvitesProvider);
      ref.invalidate(chatListProvider); // Navigate to new chat
    } catch (error) {
      state = AcceptInviteState.error(error.toString());
    }
  }
}
```

**Contract**:
- **Method**: `acceptInvite(String inviteId)`
- **Returns**: `Future<void>` (state changes via StateNotifier)
- **Success State**: Includes invite + created chat
- **Error State**: Includes error message
- **Side Effects**: Invalidates `pendingInvitesProvider` and `chatListProvider`

---

#### `declineInviteMutationProvider`
```dart
final declineInviteMutationProvider = 
  StateNotifierProvider<DeclineInviteNotifier, DeclineInviteState>((ref) {
    return DeclineInviteNotifier(ref);
  });

class DeclineInviteNotifier extends StateNotifier<DeclineInviteState> {
  DeclineInviteNotifier(Ref ref) : super(const DeclineInviteState.initial());

  Future<void> declineInvite(String inviteId) async {
    state = const DeclineInviteState.loading();
    try {
      final apiService = ref.read(inviteApiServiceProvider);
      final invite = await apiService.declineInvite(inviteId);
      state = DeclineInviteState.success(invite);
      // Invalidate pending invites list
      ref.invalidate(pendingInvitesProvider);
    } catch (error) {
      state = DeclineInviteState.error(error.toString());
    }
  }
}
```

**Contract**:
- **Method**: `declineInvite(String inviteId)`
- **Returns**: `Future<void>` (state changes via StateNotifier)
- **Success State**: Includes updated invite (status='declined')
- **Error State**: Includes error message
- **Side Effects**: Invalidates `pendingInvitesProvider`

---

### Supporting Providers

#### `inviteApiServiceProvider`
```dart
final inviteApiServiceProvider = Provider((ref) {
  final httpClient = ref.watch(httpClientProvider);
  return InviteApiService(httpClient);
});
```

**Interface**:
```dart
class InviteApiService {
  Future<ChatInvite> sendInvite(String recipientId);
  Future<List<ChatInvite>> fetchPendingInvites();
  Future<List<ChatInvite>> fetchSentInvites();
  Future<({ChatInvite invite, ChatResponse chat})> acceptInvite(String inviteId);
  Future<ChatInvite> declineInvite(String inviteId);
}
```

---

## Error Handling Contract

**Error Types**:
```dart
abstract class InviteException implements Exception {
  final String message;
  InviteException(this.message);
}

class DuplicatePendingInviteException extends InviteException {
  DuplicatePendingInviteException() 
    : super('You already have a pending invitation to this user');
}

class AlreadyChattingException extends InviteException {
  AlreadyChattingException() 
    : super('You are already chatting with this user');
}

class SelfInviteException extends InviteException {
  SelfInviteException() 
    : super('You cannot invite yourself');
}

class InviteNotFoundException extends InviteException {
  InviteNotFoundException() 
    : super('Invitation not found');
}

class UnauthorizedInviteActionException extends InviteException {
  UnauthorizedInviteActionException() 
    : super('You are not authorized to perform this action');
}

class NetworkException extends InviteException {
  NetworkException() 
    : super('Network error. Please check your connection.');
}
```

---

## Offline Support

**Strategy**: Local cache + action queue

```dart
final offlineInvitesProvider = Provider((ref) {
  // Read from local storage if available
  final localStorage = ref.watch(localStorageProvider);
  return localStorage.getInvites() ?? [];
});

final pendingActionsProvider = StateNotifierProvider<
  PendingActionsNotifier, 
  List<PendingInviteAction>
>((ref) {
  return PendingActionsNotifier(ref);
});

class PendingInviteAction {
  final String id;
  final String inviteId;
  final InviteActionType type; // send, accept, decline
  final DateTime createdAt;
  
  bool get isPending => true;
}

enum InviteActionType { send, accept, decline }
```

**Behavior**:
- When online → execute pending actions immediately
- When offline → queue actions locally
- On reconnect → retry queued actions
- UI shows loading indicator for queued actions

