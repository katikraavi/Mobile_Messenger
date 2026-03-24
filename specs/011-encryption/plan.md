# Phase 9: End-to-End Encryption - Implementation Plan

## Overview
Implement AES-256 encryption for all sensitive data (messages, media metadata, user profiles). Data is encrypted on write and decrypted on read, ensuring database-level security.

## Architecture

### Encryption Service (Backend)
- **EncryptionService**: Central AES-256 operations
  - `encrypt(plaintext: String, key: String) → String` (base64-encoded ciphertext)
  - `decrypt(ciphertext: String, key: String) → String` (returns plaintext)
  - Key derivation from user ID + master encryption key
  - IV randomization per encryption for security

### Message Encryption Flow
1. **On Create**: User sends message → Text encrypted before DB insert → WebSocket broadcast includes encrypted text
2. **On Retrieve**: Client requests messages → Server sends encrypted text → Client decrypts with user's key
3. **Key Management**: Each user has encryption key derived from user_id + application master key

### User Keys
- Master encryption key stored in environment (ENCRYPTION_MASTER_KEY)
- Per-user key = HMAC(user_id, master_key)
- Same key used for all user data (messages, profiles, media)

## Tasks Breakdown

### Phase Setup (T095-T096)
- T095: Create EncryptionService with AES-256 encrypt/decrypt methods
- T096: Add EncryptionService to server dependency injection

### Core Encryption (T097-T102)
- T097: Encrypt message text on MessageService.createMessage()
- T098: Decrypt message text on MessageService.getMessages()
- T099: Encrypt media metadata in MediaStorageService
- T100: Decrypt media metadata on retrieval
- T101: Encrypt user profile fields (bio, display_name) in UserService
- T102: Decrypt user profile on retrieval

### Integration (T103-T106)
- T103: Update message_handlers.dart to use encrypted/decrypted messages
- T104: Update media_handlers.dart to use encrypted metadata
- T105: Ensure WebSocket broadcasts include encrypted text
- T106: Update message model to support decryption lifecycle

### Frontend Integration (T107-T109)
- T107: Decrypt message text on display in ChatDetailScreen
- T108: Display decrypted user profiles in ProfileScreen
- T109: Add decryption error handling

### Testing & Validation (T110-T112)
- T110: Verify database stores encrypted values
- T111: Test message send/receive with encryption
- T112: Verify profile data encrypted/decrypted correctly

## Database Changes
No schema changes required - existing varchar fields store base64-encoded ciphertext as strings.

## Security Considerations
- Never log plaintext values (only encrypted versions)
- Key derivation includes user_id for per-user security
- IV randomization prevents pattern detection
- Decryption errors trigger 500 Server Error (fail-safe)
- All encryption/decryption happens server-side
- Client receives encrypted values only from public endpoints

## Testing Strategy
1. **Unit Tests**: EncryptionService.encrypt/decrypt round-trip
2. **Integration Tests**: Message create/retrieve with encryption
3. **Database Inspection**: Verify encrypted values in database
4. **E2E**: Full message flow with encryption

## Implementation Order
1. EncryptionService (backend core)
2. Message encryption (production impact - start with read)
3. Media/Profile encryption (lower priority)
4. Frontend decryption
5. Testing & validation

## Rollback Strategy
- All data already stored as strings (backwards compatible)
- Can disable encryption by setting ENCRYPTION_MASTER_KEY to empty
- Decryption failures fall back to returning original value (if not encrypted)
