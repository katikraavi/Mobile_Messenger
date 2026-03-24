# Phase 9: End-to-End Encryption - Task List

## Setup Phase (2 tasks)

### T095: Create EncryptionService with AES-256 methods
**Status**: ⏳ NOT STARTED
**Location**: backend/lib/src/services/encryption_service.dart
**Description**:
- Implement EncryptionService class with encrypt/decrypt methods
- Use dart:typed_data and pointycastle for AES-256-CBC
- Generate random IV per encryption
- Return base64-encoded ciphertext with IV prepended
- Decrypt by extracting IV, then decrypting ciphertext
- Add key derivation: HMAC-SHA256(user_id, ENCRYPTION_MASTER_KEY)

**Inputs**:
- plaintext: String
- user_id: String
- ENCRYPTION_MASTER_KEY: String (from env)

**Outputs**:
```dart
String encrypt(String plaintext, String userId) 
  // Returns: "base64(iv)::base64(ciphertext)"
String decrypt(String encrypted, String userId) 
  // Returns: plaintext
```

**Tests**:
- Round-trip: encrypt("hello", "user1") → decrypt(...) = "hello"
- Different users → different ciphertext for same plaintext
- Invalid ciphertext → throws FormatException
- Missing IV → throws FormatException

---

### T096: Add EncryptionService to server DI and environment
**Status**: ⏳ NOT STARTED
**Location**: backend/lib/src/handlers/... (multiple)
**Description**:
- Import EncryptionService in server.dart
- Create EncryptionService instance in main
- Add ENCRYPTION_MASTER_KEY to environment (backend/.env or docker-compose)
- Wire into MessageService and MediaStorageService
- Ensure EncryptionService accessible from all handlers

**Configuration**:
```
ENCRYPTION_MASTER_KEY=<32-byte hex string>
```

**Tests**:
- EncryptionService initializes without errors
- Server starts with ENCRYPTION_MASTER_KEY set
- Accessible from all services

---

## Core Encryption Phase (6 tasks)

### T097: Encrypt message text on creation [P]
**Status**: ⏳ NOT STARTED
**Location**: backend/lib/src/services/message_service.dart
**Dependencies**: T095, T096
**Description**:
- In MessageService.createMessage(), after validating text:
  - Encrypt plaintext using EncryptionService.encrypt(text, sender_id)
  - Store encrypted value in database
  - Track that "encryption_version=1" is applied
  - Log only that message was encrypted (not content)

**Changes**:
```dart
// BEFORE: Store plaintext
message.text = text;

// AFTER: Store encrypted
final encryptedText = _encryptionService.encrypt(text, userId);
message.text = encryptedText;
message.isEncrypted = true; // Add field if needed
```

**Tests**:
- Database contains encrypted (base64-like) value for text field
- Message.text differs from original plaintext in database
- Decryption with correct userId succeeds

---

### T098: Decrypt message text on retrieval [P]
**Status**: ⏳ NOT STARTED
**Location**: backend/lib/src/services/message_service.dart
**Dependencies**: T095, T096
**Description**:
- In MessageService.getMessages() and getMessageById():
  - After fetching from database, decrypt each message.text
  - Use message.sender_id as key for decryption
  - If decryption fails, log error but don't crash
  - Decryption errors trigger 500 response (fail-safe)

**Changes**:
```dart
// AFTER fetch from DB
for (final msg in messages) {
  if (msg.isEncrypted) {
    try {
      msg.text = _encryptionService.decrypt(msg.text, msg.senderId);
    } catch (e) {
      logger.error('Decrypt failed: $e');
      rethrow; // Trigger 500
    }
  }
}
```

**Tests**:
- getMessages() returns decrypted plaintext
- Plaintext matches original message content
- Decryption failure throws and triggers error response

---

### T099: Encrypt media metadata in MediaStorageService [P]
**Status**: ⏳ NOT STARTED
**Location**: backend/lib/src/services/media_storage_service.dart
**Dependencies**: T095, T096
**Description**:
- In MediaStorageService.uploadFile():
  - Encrypt original_filename before storing in database
  - Store original_filename as encrypted value
  - Keep file_path unencrypted (server-only path)
  - Store mime_type unencrypted (needed for HTTP Content-Type)

**Changes**:
```dart
// BEFORE: Store plaintext filename
final media = MediaStorage(
  originalFilename: filename,
  ...
);

// AFTER: Encrypt filename
final encryptedFilename = 
  _encryptionService.encrypt(filename, uploaderId);
final media = MediaStorage(
  originalFilename: encryptedFilename,
  ...
);
```

**Notes**:
- Only filename needs encryption (MIME type is non-sensitive)
- Keep file_path unencrypted for server file operations

**Tests**:
- Database contains encrypted filename
- Filename differs from original plaintext in database

---

### T100: Decrypt media metadata on retrieval [P]
**Status**: ⏳ NOT STARTED
**Location**: backend/lib/src/services/media_storage_service.dart
**Dependencies**: T095, T096
**Description**:
- In MediaStorageService.getMediaById() and downloadFile():
  - Decrypt original_filename after fetching from database
  - Use uploader_id as key for decryption
  - If decryption fails, log error and return generic error

**Changes**:
```dart
// AFTER fetch from DB
if (media.isEncrypted) {
  try {
    media.originalFilename = 
      _encryptionService.decrypt(media.originalFilename, media.uploaderId);
  } catch (e) {
    logger.error('Decrypt failed: $e');
    throw Exception('Cannot decrypt media');
  }
}
```

**Tests**:
- getMediaById() returns decrypted filename
- Filename matches original uploaded filename

---

### T101: Encrypt user profile fields in UserService [P]
**Status**: ⏳ NOT STARTED
**Location**: backend/lib/src/services/user_service.dart
**Dependencies**: T095, T096
**Description**:
- In UserService.updateProfile():
  - Encrypt bio and displayName before database insert
  - Store encrypted values in users table
  - Keep email and username unencrypted (used for search/auth)

**Changes**:
```dart
// Encrypt sensitive profile fields
user.bio = bio != null 
  ? _encryptionService.encrypt(bio, userId)
  : null;
user.displayName = displayName != null
  ? _encryptionService.encrypt(displayName, userId)
  : null;
```

**Notes**:
- Email/username remain unencrypted for authentication
- Only display-oriented fields encrypted

**Tests**:
- Database stores encrypted bio and displayName
- Original plaintext not visible in database

---

### T102: Decrypt user profile on retrieval [P]
**Status**: ⏳ NOT STARTED
**Location**: backend/lib/src/services/user_service.dart
**Dependencies**: T095, T096
**Description**:
- In UserService.getUserById(), getByEmail(), and getByUsername():
  - After fetching user, decrypt bio and displayName
  - Use user_id as key
  - If decryption fails, return empty strings (graceful fallback)

**Changes**:
```dart
// AFTER fetch from DB
if (user.isEncrypted) {
  try {
    user.bio = user.bio != null
      ? _encryptionService.decrypt(user.bio!, user.id)
      : null;
    user.displayName = user.displayName != null
      ? _encryptionService.decrypt(user.displayName!, user.id)
      : null;
  } catch (e) {
    logger.warn('Profile decrypt failed: $e');
    // Keep fields empty
  }
}
```

**Tests**:
- getUserById() returns decrypted profile
- Profile matches original values

---

## Integration Phase (4 tasks)

### T103: Update MessageHandlers for encrypted messages
**Status**: ⏳ NOT STARTED
**Location**: backend/lib/src/handlers/message_handlers.dart
**Dependencies**: T097, T098
**Description**:
- In POST /api/messages (create message handler):
  - Ensure MessageService.createMessage() is called (already encrypts)
  - Verify response includes encrypted text
  - WebSocket broadcast should send encrypted text

- In GET /api/messages endpoint:
  - Ensure decrypted messages are returned
  - Test that plaintext is visible to client

**Changes**: Minimal - ensure MessageService handles encryption internally

**Tests**:
- POST /api/messages stores encrypted in database
- GET /api/messages returns decrypted plaintext to client

---

### T104: Update MediaHandlers for encrypted metadata
**Status**: ⏳ NOT STARTED
**Location**: backend/lib/src/handlers/media_handlers.dart
**Dependencies**: T099, T100
**Description**:
- In POST /api/media/upload:
  - Ensure MediaStorageService.uploadFile() is called (already encrypts)
  - Verify database stores encrypted filename

- In GET /api/media/{mediaId}/download:
  - Ensure decrypted filename used for response headers
  - Content-Disposition header includes decrypted filename

**Changes**: Minimal - ensure MediaStorageService handles encryption internally

**Tests**:
- Media upload stores encrypted filename in database
- Download returns correct decrypted filename in headers

---

### T105: Verify WebSocket broadcasts include encrypted text [P]
**Status**: ⏳ NOT STARTED
**Location**: backend/lib/src/handlers/websocket_handler.dart
**Dependencies**: T097, T098
**Description**:
- When messageCreated event broadcasts:
  - Ensure message.text is already encrypted (from T097)
  - Verify encrypted text is sent to all clients
  - Clients receive: `{..., "text": "base64(iv)::base64(ct)", ...}`

- Decrypt client-side (see T107)

**No code changes needed** - encryption in T097 ensures broadcast contains encrypted text by default

**Tests**:
- messageCreated event contains encrypted text field
- Text differs from original plaintext

---

### T106: Update Message model to support encryption metadata [P]
**Status**: ⏳ NOT STARTED
**Location**: backend/lib/src/models/message_model.dart and frontend/lib/models/message.dart
**Dependencies**: T097, T098
**Description**:
- Add `isEncrypted: bool` field (default true for new messages)
- Add `encryptionVersion: int?` field (track encryption scheme, default 1)
- Update fromJson/toJson to include these fields
- Helps future key rotation or algorithm changes

**Changes**:
```dart
@JsonSerializable()
class Message {
  final String id;
  final String text; // Stored encrypted in DB
  final String senderId;
  final String chatId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String? mediaUrl;
  final String? mediaType;
  final bool isEncrypted; // NEW
  final int? encryptionVersion; // NEW
  
  Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.chatId,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.mediaUrl,
    this.mediaType,
    this.isEncrypted = true,
    this.encryptionVersion = 1,
  });
  
  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);
  
  Message copyWith({
    String? id,
    String? text,
    String? senderId,
    String? chatId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? mediaUrl,
    String? mediaType,
    bool? isEncrypted,
    int? encryptionVersion,
  }) => Message(
    id: id ?? this.id,
    text: text ?? this.text,
    senderId: senderId ?? this.senderId,
    chatId: chatId ?? this.chatId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
    mediaUrl: mediaUrl ?? this.mediaUrl,
    mediaType: mediaType ?? this.mediaType,
    isEncrypted: isEncrypted ?? this.isEncrypted,
    encryptionVersion: encryptionVersion ?? this.encryptionVersion,
  );
}
```

**Tests**:
- Model serializes/deserializes with encryption metadata
- isEncrypted defaults to true

---

## Frontend Integration Phase (3 tasks)

### T107: Decrypt message text on display in ChatDetailScreen
**Status**: ⏳ NOT STARTED
**Location**: frontend/lib/screens/chat_detail_screen.dart
**Dependencies**: T098, T106
**Description**:
- Create DecryptionService for frontend (mirror of backend encrypt/decrypt)
- In _buildMessageBubbles():
  - Check if message.isEncrypted == true
  - Decrypt message.text using current user's key
  - Display decrypted plaintext in bubble

**Decrypt Flow**:
```dart
// Frontend: same encryption as backend
// 1. User ID from auth context
// 2. Derive key same way as backend
// 3. Decrypt using same AES-256-CBC

String decryptedText = message.isEncrypted
  ? decryptionService.decrypt(message.text, userId)
  : message.text;
```

**Note**: Frontend receives encrypted text from WebSocket - decrypt client-side

**Tests**:
- Message displays decrypted plaintext in chat bubble
- Encrypted and decrypted text matches original

---

### T108: Display decrypted user profiles in ProfileScreen
**Status**: ⏳ NOT STARTED
**Location**: frontend/lib/screens/profile_screen.dart
**Dependencies**: T102
**Description**:
- Create DecryptionService for frontend
- In ProfileScreen.build():
  - Get user profile data from API
  - Decrypt bio and displayName if isEncrypted == true
  - Display decrypted values

**Changes**:
```dart
final user = await userService.getUserProfile(userId);
final decryptedBio = user.isEncrypted 
  ? await decryptionService.decrypt(user.bio, userId)
  : user.bio;
final decryptedName = user.isEncrypted
  ? await decryptionService.decrypt(user.displayName, userId)
  : user.displayName;
```

**Tests**:
- Profile screen displays decrypted bio and name
- Values match original stored values

---

### T109: Add decryption error handling for frontend
**Status**: ⏳ NOT STARTED
**Location**: frontend/lib/services/decryption_service.dart
**Dependencies**: T107, T108
**Description**:
- Create DecryptionService with error handling
- Invalid ciphertext → log error, show placeholder "Message could not be decrypted"
- Missing encryption key → show "Encryption unavailable"
- Both cases graceful, don't crash app

**Error Handling**:
```dart
try {
  return decryptionService.decrypt(encryptedText, userId);
} catch (e) {
  logger.error('Decrypt error: $e');
  return '[Message could not be decrypted]';
}
```

**Tests**:
- Invalid ciphertext shows placeholder
- Chat continues to work despite decrypt errors
- Errors logged for debugging

---

## Testing & Validation Phase (3 tasks)

### T110: Verify database stores encrypted values
**Status**: ⏳ NOT STARTED
**Location**: Integration tests / database verification script
**Description**:
- Write verification script that:
  - Sends message via API
  - Queries database directly
  - Confirms message.text is encrypted (base64 format, not plaintext)
  - Confirms original text is NOT visible in database

**Verification**:
```bash
# In database:
SELECT text FROM messages WHERE id='...';
# Result should be: "base64..." (not "hello")

# Confirm original text is absent:
SELECT * FROM messages WHERE text LIKE '%original_text_substring%';
# Result should be EMPTY
```

**Tests**:
- All messages in database are encrypted
- Plaintext impossible to read from database

---

### T111: Test message send/receive with encryption [P]
**Status**: ⏳ NOT STARTED
**Location**: Integration tests
**Description**:
- End-to-end test:
  1. User A sends message "Hello from A"
  2. Verify message stored encrypted in database
  3. User B retrieves messages
  4. Verify User B receives decrypted "Hello from A"
  5. Verify message displays correctly in chat bubble

**Test Steps**:
1. POST /api/messages (encrypted in DB)
2. Direct DB query (confirm encrypted)
3. GET /api/messages (receives decrypted)
4. Message display (shows plaintext)

**Tests**: Full encryption/decryption round-trip works
- Database level: encrypted
- API level: returns decrypted
- UI level: displays plaintext

---

### T112: Verify profile data encrypted/decrypted correctly [P]
**Status**: ⏳ NOT STARTED
**Location**: Integration tests
**Description**:
- End-to-end user profile test:
  1. User updates profile (bio="My bio is private", name="John Doe")
  2. Verify bio and name stored encrypted in database
  3. User retrieves profile
  4. Verify receives back "My bio is private" and "John Doe"
  5. Profile screen displays correctly decrypted

**Test Steps**:
1. PUT /api/users/{userId}/profile (encrypted in DB)
2. Direct DB query (confirm encrypted)
3. GET /api/users/{userId}/profile (receives decrypted)
4. Profile screen (shows plaintext)

**Tests**:
- Profile encryption round-trip works
- Email/username remain searchable (unencrypted)
- Bio/displayName private (encrypted)

---

## Summary

**Total Tasks**: 18 tasks
- Setup: 2 ✓ (T095-T096)
- Core Encryption: 6 ✓ (T097-T102)
- Integration: 4 ✓ (T103-T106)
- Frontend: 3 ✓ (T107-T109)
- Testing: 3 ✓ (T110-T112)

**Files to Create**:
1. backend/lib/src/services/encryption_service.dart (NEW - 200 lines)
2. frontend/lib/services/decryption_service.dart (NEW - 120 lines)

**Files to Modify**:
1. backend/lib/src/services/message_service.dart (encrypt/decrypt calls)
2. backend/lib/src/services/media_storage_service.dart (encrypt metadata)
3. backend/lib/src/services/user_service.dart (encrypt/decrypt profile)
4. backend/lib/src/handlers/message_handlers.dart (verify flow)
5. backend/lib/src/handlers/media_handlers.dart (verify flow)
6. backend/lib/src/handlers/websocket_handler.dart (verify broadcast)
7. backend/lib/src/models/message_model.dart (add encryption metadata)
8. backend/server.dart (wire DI)
9. frontend/lib/models/message.dart (add encryption metadata)
10. frontend/lib/screens/chat_detail_screen.dart (decrypt display)
11. frontend/lib/screens/profile_screen.dart (decrypt display)
12. backend/.env (add ENCRYPTION_MASTER_KEY)

**Environment Variables**:
- ENCRYPTION_MASTER_KEY: 32-byte hex string (generated via `openssl rand -hex 32`)

**Testing**:
- 9 unit/integration test scenarios covering encrypt/decrypt round-trips
- Database inspection verifying encrypted storage
- E2E message and profile flows

**Estimated Time**: 4-5 hours (following established patterns from Phase 8)
