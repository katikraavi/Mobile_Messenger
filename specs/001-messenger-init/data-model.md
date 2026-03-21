# Data Model & Organization: Initialize Flutter Messenger Project

**Created**: March 10, 2026  
**Phase**: 1 - Design  
**Status**: Project structure phase - detailed models deferred to feature implementation

## Overview

This feature establishes the **data model organization philosophy and directory structure** that subsequent features (auth, profile, chat, invites) will populate. No concrete data models are created in this feature—instead, we define the patterns, conventions, and shared utilities that all models will follow.

## Model Organization Layers

### Layer 1: Shared Models (Frontend + Backend)

**Location**: `backend/lib/src/models/` (source-of-truth) + `frontend/lib/models/` (generated or re-referenced)

**Purpose**: Define entities, DTOs, and schemas that cross the frontend-backend boundary

**Conventions**:
- File naming: `snake_case.dart` (e.g., `user_model.dart`, `message_model.dart`)
- Class naming: `PascalCase` (e.g., `class UserModel`, `class MessageModel`)
- Properties: `camelCase` (e.g., `userId`, `createdAt`, `isActive`)

**Inheritance Pattern**:
```dart
// Backend model (database-backed)
class UserModel extends UpdateModel {
  final String userId;
  final String fullName;
  final String encryptedEmail;   // Always encrypted in database
  final DateTime createdAt;
}

// Frontend DTO (data transfer)
class UserDTO {
  final String userId;
  final String fullName;
  final String email;  // Decrypted on device
  
  factory UserDTO.fromJson(Map<String, dynamic> json) => ...
  Map<String, dynamic> toJson() => ...
}
```

### Layer 2: Backend-Only Models (Business Logic)

**Location**: `backend/lib/src/services/`

**Purpose**: Internal business logic representations not exposed to frontend

**Examples**:
- `InternalAuthToken` - backend authentication state
- `DatabaseConnection` - connection pooling configuration
- `EncryptionContext` - temporary context for encryption operations

### Layer 3: Frontend-Only Models (UI State)

**Location**: `frontend/lib/core/models/` and `frontend/lib/features/*/models/`

**Purpose**: UI-specific state management not persisted to backend

**Examples**:
- `AppState` - navigation stack, loaded/loading/error states
- `ChatScreenState` - UI pagination, draft messages
- `FormState` - validation errors, field focus

### Layer 4: Configuration Models

**Location**: `backend/config/`, `frontend/lib/core/config/`

**Purpose**: Environment-specific configuration (not secrets)

**Examples**:
- `ClientConfig` - backend URL, API version, timeouts
- `DatabaseConfig` - connection pool size, retry strategy
- `FeatureFlagsConfig` - feature toggles

## Encryption & Sensitive Data Handling

**Policy** (from Constitution):
- All user messages, profile data, and chat metadata MUST be encrypted before storage
- Encryption happens in backend before database persistence
- Frontend receives encrypted data OR decrypted plaintext (decided by API design, deferred to auth feature)

**Model Pattern for Encrypted Fields**:
```dart
// In database model
class UserModel extends UpdateModel {
  String id;
  String fullName;
  String encryptedEmail;  // Field name indicates encrypted state
  String encryptedPhoneNumber;
  
  // Never: plaintext(email)
  // Always: encrypted(sensitive_data)
}

// Encryption/decryption in UserService, not in model
class UserService {
  Future<UserModel> createUser(String email, String phone) async {
    final encrypted_email = encrypt(email);  // In service layer
    final encrypted_phone = encrypt(phone);
    return UserModel(
      id: generateId(),
      encryptedEmail: encrypted_email,
      encryptedPhoneNumber: encrypted_phone,
    );
  }
}
```

## Relationships & Aggregates

**Cardinality Patterns** (to be fully implemented with auth/chat features):

| Entity | 1:1 Relationships | 1:N Relationships | N:N Relationships |
|--------|-------------------|-------------------|-------------------|
| User | Profile | Messages, Chats, Invites | Contacts (through Chat) |
| Chat | Icon/Metadata | Messages, Participants | Users (many-to-many) |
| Message | Sender | — | — |
| Invite | Receiver | — | — |

**Aggregate Root Pattern**:
- **UserAggregate**: User (root) → Profile, Contacts, Settings
- **ChatAggregate**: Chat (root) → Messages, Participants, Settings
- **NotificationAggregate**: Notification (root) → Delivery Log

## Database Schema Design Principles

### Principle 1: Immutability Where Possible

Messages, invites are immutable (or soft-delete). Users and profiles are mutable but versioned.

### Principle 2: Denormalization for Performance

- Chat list includes last message (denormalized from Messages table)
- User list includes online status (denormalized from real-time WebSocket heartbeats)

### Principle 3: Soft Deletes & Audit Trail

All tables include `deleted_at` and `updated_at` timestamps for recovery and compliance.

### Principle 4: Indexing Strategy

- User queries: Index on `user_id`, `email`, `username`
- Chat queries: Index on `participants`, `created_at` (for pagination)
- Message queries: Index on `chat_id`, `created_at` (for chronological display)

## Migrations & Schema Evolution

**Versioning Strategy** (managed by Serverpod):
```
backend/migrations/
├── 1_initial_schema.sql      # Initial User, Chat, Message, Invite tables
├── 2_add_encryption_keys.sql  # Add key management table (auth feature)
├── 3_user_profiles.sql        # Add Profile table (profile feature)
├── 4_message_encryption.sql   # Add encryption metadata (chat feature)
└── 5_invites_redesign.sql     # Refine invite schema (invites feature)
```

**Process**:
1. Serverpod models defined in `backend/lib/src/models/`
2. Developer runs `serverpod generate` to auto-create/update migrations
3. On `docker-compose up`, migrations auto-apply to database
4. Schema version tracked in `_serverpod_schema_version` table

## Type Safety & Validation

### Dart Type System

- Use `final` for immutable fields
- Use `nullable` (?) only when optional data is truly optional
- Use `sealed` for enum-like types with associated data

```dart
// Good
class Message {
  final String id;
  final String text;
  final DateTime sentAt;
  final String? editedNote;  // Optional: edited_at timestamp if updated
}

// Avoid
class Message {
  String? id;  // Should never be null after creation
  String text;  // Should be final
  DateTime? sentAt;  // Should always be present
}
```

### Validation Rules

| Field | Rules | Example |
|-------|-------|---------|
| username | 3-20 chars, alphanumeric + underscore, unique | `john_doe_123` |
| email | RFC 5322 compliant, unique | `user@example.com` |
| message content | Non-empty, ≤ 5000 chars (before encryption) | Any text |
| phone | E.164 format, optional | `+1-555-0123` |

## Shared Constants & Enums

**Location**: `backend/lib/src/models/enums.dart` + `frontend/lib/core/models/enums.dart`

```dart
// Shared enums
enum UserRole { admin, user, guest }
enum MessageStatus { pending, sent, failed, edited }
enum ChatType { direct, group }
enum InviteStatus { pending, accepted, rejected, expired }

// Shared constants
class Limits {
  static const int maxUsernameLength = 20;
  static const int maxMessageLength = 5000;
  static const int maxGroupParticipants = 500;
  static const Duration messageRetentionPeriod = Duration(days: 30);
}
```

## Next Steps

1. **Auth feature**: Implement User, UserCredential, AuthToken models
2. **Profile feature**: Implement UserProfile, ProfileSettings models
3. **Chat feature**: Implement Chat, Message, Participant models
4. **Invites feature**: Implement Invite, InviteNotification models

All models will follow the organizational patterns and naming conventions established in this document.
