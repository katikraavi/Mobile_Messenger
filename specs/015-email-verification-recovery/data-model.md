# Data Model & Database Schema: Email Verification and Password Recovery

**Date**: March 11, 2026  
**Feature**: `015-email-verification-recovery`  
**Status**: Design Complete

## Data Model Overview

Email verification and password recovery data model extending the existing User, Chat, and Message entities from Specs 002-003 with secure token management. Four new database entities track verification tokens, password reset tokens, and reset attempts with proper expiration, single-use semantics, and rate-limiting support. One extension to the existing Users table adds verification timestamp field.

## Entity Definitions

### Entity 1: VerificationToken

**Purpose**: Represents an email verification token for new user account activation  
**Lifecycle**: Created on registration → Consumed when user clicks verification link → Expires 24 hours later  
**Retention**: Deleted on successful verification or after 24+ hours (cleanup job)

**Fields**:
- `id` (UUID, PRIMARY KEY, NOT NULL): Unique token record identifier
- `user_id` (UUID, FOREIGN KEY → User.id, NOT NULL): User whose email is being verified
- `token_hash` (VARCHAR(255), UNIQUE, NOT NULL): SHA256 hash of verification token (raw token never stored in database)
- `expires_at` (TIMESTAMP WITH TIME ZONE, NOT NULL): Token expiration time (created_at + 24 hours UTC)
- `used_at` (TIMESTAMP WITH TIME ZONE, NULL): When token was successfully used (null = unused)
- `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, DEFAULT CURRENT_TIMESTAMP): Token creation timestamp (UTC)

**Relationships**:
- Many-to-One with User: Multiple verification tokens may exist for one user (resend scenario)
- One verification token belongs to exactly one user

**Constraints**:
- PRIMARY KEY (id): Ensures unique record identifier
- FOREIGN KEY user_id → User.id ON DELETE CASCADE: When user deleted, remove associated verification tokens
- UNIQUE(token_hash): Ensure no duplicate token hashes in database (two different tokens cannot hash to same value)
- NOT NULL: id, user_id, token_hash, expires_at, created_at (required fields always present)
- CHECK (used_at IS NULL OR used_at >= created_at): Temporal validity—if used, must be after creation
- CHECK (expires_at > created_at): Expiration must be in future (prevents misconfigured tokens)

**Indexes**:
- PRIMARY KEY on id: Fast lookup by token ID
- UNIQUE INDEX on token_hash: Fast verification token lookup by hash (most common query: "Find token by hash")
- COMPOSITE INDEX on (user_id, created_at DESC): Find most recent verification token for a user (resend scenario)
- INDEX on expires_at: Cleanup queries to find expired tokens for deletion
- INDEX on used_at: Find all used tokens (audit/reporting queries)

**Design Rationale**:
- Token itself (32 bytes, Base64URL) transmitted via email and frontend, never stored in database
- Only SHA256 hash stored in database—prevents token exposure if database is compromised
- Allows resending verification email (creates new token, old token remains but becomes irrelevant after new expires_at)
- Single `used_at` timestamp indicates successful verification; no explicit status field (simpler)
- Prevents double-verification: If `used_at IS NOT NULL`, token already consumed
- created_at and expires_at both stored: Allows audit trail ("when was this token issued?") and cleanup queries

**Data Access Patterns**:
1. Generate new token: INSERT into VerificationToken with generated token_hash, NOW() for created_at, NOW() + 24 hours for expires_at
2. Verify token: SELECT * FROM VerificationToken WHERE token_hash = ? AND expires_at > NOW() — returns token if valid, null if not found or expired
3. Mark used: UPDATE VerificationToken SET used_at = NOW() WHERE id = ? — consumes token
4. Get latest token for user: SELECT * FROM VerificationToken WHERE user_id = ? ORDER BY created_at DESC LIMIT 1
5. Invalidate previous tokens: UPDATE VerificationToken SET used_at = NOW() WHERE user_id = ? AND used_at IS NULL — marks all unused tokens as "used"
6. Cleanup expired: DELETE FROM VerificationToken WHERE expires_at < NOW() - INTERVAL '24 hours'

**Example Record**:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
  "token_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "expires_at": "2026-03-12T12:34:56+00:00",
  "used_at": "2026-03-11T12:34:56+00:00",
  "created_at": "2026-03-11T12:34:56+00:00"
}
```

---

### Entity 2: PasswordResetToken

**Purpose**: Represents a password reset token for secure account recovery  
**Lifecycle**: Created when user requests password reset → Consumed when user sets new password → Expires 24 hours later  
**Retention**: Deleted on successful reset or after 24+ hours (cleanup job)

**Fields**:
- `id` (UUID, PRIMARY KEY, NOT NULL): Unique token record identifier
- `user_id` (UUID, FOREIGN KEY → User.id, NOT NULL): User resetting password
- `token_hash` (VARCHAR(255), UNIQUE, NOT NULL): SHA256 hash of password reset token (raw token never stored)
- `expires_at` (TIMESTAMP WITH TIME ZONE, NOT NULL): Token expiration time (created_at + 24 hours UTC)
- `used_at` (TIMESTAMP WITH TIME ZONE, NULL): When token was successfully used (null = unused)
- `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, DEFAULT CURRENT_TIMESTAMP): Token creation timestamp (UTC)

**Relationships**:
- Many-to-One with User: Multiple password reset tokens may exist for one user (multiple reset requests)
- One token belongs to exactly one user

**Constraints**:
- PRIMARY KEY (id): Ensures unique record identifier
- FOREIGN KEY user_id → User.id ON DELETE CASCADE: When user deleted, remove reset tokens
- UNIQUE(token_hash): No duplicate token hashes
- NOT NULL: id, user_id, token_hash, expires_at, created_at
- CHECK (used_at IS NULL OR used_at >= created_at): Temporal validity
- CHECK (expires_at > created_at): Expiration in future

**Indexes**:
- PRIMARY KEY on id: Fast lookup
- UNIQUE INDEX on token_hash: Fast token lookup by hash (primary query)
- COMPOSITE INDEX on (user_id, created_at DESC): Find most recent reset token for user
- INDEX on expires_at: Cleanup queries
- INDEX on used_at: Audit queries

**Design Rationale**:
- Identical structure to VerificationToken for consistency (both are single-use tokens with 24-hour expiration)
- Separated into distinct table for clarity and potential future policy differences (e.g., different expiration times)
- Same security model: Only hash stored, raw token transmitted via email
- Single-use: `used_at` timestamp marks consumption—attempting reuse fails
- Failed reset attempts don't consume token (user can retry with same token until expiration)

**Data Access Patterns**:
1. Generate new token: INSERT with token_hash, created_at, expires_at (same pattern as VerificationToken)
2. Verify token: SELECT * FROM PasswordResetToken WHERE token_hash = ? AND expires_at > NOW()
3. Mark used: UPDATE PasswordResetToken SET used_at = NOW() WHERE id = ?
4. Get latest token for user: SELECT * FROM PasswordResetToken WHERE user_id = ? ORDER BY created_at DESC LIMIT 1
5. Invalidate unused tokens for user: UPDATE PasswordResetToken SET used_at = NOW() WHERE user_id = ? AND used_at IS NULL
6. Cleanup expired: DELETE FROM PasswordResetToken WHERE expires_at < NOW() - INTERVAL '24 hours'

---

### Entity 3: PasswordResetAttempt

**Purpose**: Tracks password reset requests per email for rate limiting enforcement  
**Lifecycle**: Created on each password reset request → Automatically ignored after 60 minutes by time-windowed queries → Periodic deletion of entries older than 1+ days  
**Retention**: Kept for 24 hours minimum (allows rate limit window + buffer), cleanup job deletes older records

**Fields**:
- `id` (UUID, PRIMARY KEY, NOT NULL): Unique attempt record identifier
- `email` (VARCHAR(255), NOT NULL): Email address requesting password reset (case-insensitive storage recommended)
- `attempted_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, DEFAULT CURRENT_TIMESTAMP): When reset was requested (UTC)

**Relationships**:
- Reference (not FK) to User via email: Tracks attempts even if email not found in User table
- Enables rate limiting without revealing whether email is registered (user enumeration prevention)
- No foreign key: Allows tracking attempts for non-existent emails

**Constraints**:
- PRIMARY KEY (id): Ensures unique record identifier
- NOT NULL: email, attempted_at (required)
- No UNIQUE constraint: Multiple attempts per email allowed (tracked by time sorting)
- No FOREIGN KEY: Deliberately allows tracking attempts for emails not in User table

**Indexes**:
- PRIMARY KEY on id: Record lookup
- COMPOSITE INDEX on (email, attempted_at DESC): Primary query for rate limiting check ("Count attempts for this email in last hour")
- INDEX on attempted_at: Cleanup queries ("Find records older than 1 day")
- INDEX on email: Query attempts by email address

**Design Rationale**:
- Tracks per-email (not IP) to avoid blocking legitimate multi-device users
- Per-IP tracking unnecessary (assuming single email per person; IP-based DoS prevention is separate concern)
- No explicit "attempt_count" field: COUNT aggregation on time-windowed query is dynamic and always current
- Automatic expiration via queries (only consider attempts from last 60 minutes; records older than 24 hours automatically cleanup)
- Periodic cleanup job prevents unbounded table growth (typical: runs hourly, keeps last 24 hours)
- Generic rate limiting: Same limit (5 per hour) for all emails—no per-user customization

**Data Access Patterns**:
1. Record attempt: INSERT INTO PasswordResetAttempt (email, attempted_at) VALUES (?, NOW())
2. Check rate limit: SELECT COUNT(*) FROM PasswordResetAttempt WHERE email = ? AND attempted_at > NOW() - INTERVAL '1 hour' — returns count
3. Clear attempts (after successful reset): UPDATE PasswordResetAttempt SET attempted_at = NOW() - INTERVAL '1 day' WHERE email = ? (or just DELETE)
4. Cleanup: DELETE FROM PasswordResetAttempt WHERE attempted_at < NOW() - INTERVAL '1 day'

**Example Records**:
```json
[
  {
    "id": "750e8400-e29b-41d4-a716-446655440000",
    "email": "alice@example.com",
    "attempted_at": "2026-03-11T10:00:00+00:00"
  },
  {
    "id": "850e8400-e29b-41d4-a716-446655440000",
    "email": "alice@example.com",
    "attempted_at": "2026-03-11T10:15:00+00:00"
  },
  {
    "id": "950e8400-e29b-41d4-a716-446655440000",
    "email": "alice@example.com",
    "attempted_at": "2026-03-11T10:30:00+00:00"
  }
]
```
— Attempting 6th reset within the 1-hour window starting from first attempt will be blocked

---

### Entity 4: Users Table Extension (from Spec 002)

**Existing Fields** (unchanged from Spec 002):
- `id` (UUID, PRIMARY KEY): User identifier
- `email` (VARCHAR(255), UNIQUE, NOT NULL): User's email address
- `username` (VARCHAR(50), UNIQUE, NOT NULL): Display name/login username
- `password_hash` (VARCHAR(255), NOT NULL): Bcrypt hash of password (never plain text)
- `email_verified` (BOOLEAN, DEFAULT false): Flag indicating verification status
- `profile_picture_url` (TEXT, nullable): URL to user's avatar image
- `about_me` (TEXT, nullable): User's biographical text/bio
- `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL): Account creation timestamp

**New Fields Added for Spec 015**:
- `verified_at` (TIMESTAMP WITH TIME ZONE, NULL): When email was verified (null = never/pending verification)

**Rationale for New Field**:
- `email_verified` (boolean flag) answers "Is email verified?" → TRUE/FALSE
- `verified_at` (timestamp) answers "When was it verified?" → ISO8601 timestamp for audit trail
- Similar pattern to Message.edited_at: Tracks when significant event occurred
- Enables audit queries: "Find all users verified on March 11" or "Find users verified in past 7 days"
- Not replacing `email_verified`: Keeping both for backward compatibility with Spec 003 queries

**Behavior**:
- On registration (Spec 003): `email_verified = false`, `verified_at = NULL`
- On email verification (Spec 015): `email_verified = true`, `verified_at = NOW()`
- On password reset (Spec 015): `verified_at` unchanged (password change doesn't affect email verification)

**New Indexes Added**:
- INDEX on email_verified: Queries for unverified users (e.g., "Send reminder emails to unverified users")
- INDEX on verified_at: Audit queries (e.g., "Find users verified between dates X and Y")

**Example Record**:
```json
{
  "id": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
  "email": "alice@example.com",
  "username": "alice_wonder",
  "password_hash": "$2b$10$...", // bcrypt hash
  "email_verified": true,
  "verified_at": "2026-03-11T12:34:56+00:00",
  "profile_picture_url": "https://...",
  "about_me": "Software engineer in SF",
  "created_at": "2026-03-10T09:00:00+00:00"
}
```

---

## Database Migration Scripts

### Migration 1: Create VerificationToken Table

**File**: `backend/migrations/007_create_verification_tokens_table.dart`

```dart
import 'package:postgres/postgres.dart';

Future<void> migration(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS verification_tokens (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL,
      token_hash VARCHAR(255) NOT NULL UNIQUE,
      expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
      used_at TIMESTAMP WITH TIME ZONE,
      created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      
      CONSTRAINT fk_verification_tokens_user_id 
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
      CONSTRAINT check_verification_tokens_used_at 
        CHECK(used_at IS NULL OR used_at >= created_at),
      CONSTRAINT check_verification_tokens_expires_at 
        CHECK(expires_at > created_at)
    );
    
    CREATE INDEX idx_verification_tokens_user_id_created_at 
      ON verification_tokens(user_id, created_at DESC);
    CREATE INDEX idx_verification_tokens_expires_at 
      ON verification_tokens(expires_at);
    CREATE INDEX idx_verification_tokens_used_at 
      ON verification_tokens(used_at);
  ''');
  
  print('✓ Created verification_tokens table');
}

Future<void> rollback(Connection connection) async {
  await connection.execute('DROP TABLE IF EXISTS verification_tokens;');
  print('✓ Dropped verification_tokens table');
}
```

### Migration 2: Create PasswordResetToken Table

**File**: `backend/migrations/008_create_password_reset_tokens_table.dart`

```dart
import 'package:postgres/postgres.dart';

Future<void> migration(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS password_reset_tokens (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL,
      token_hash VARCHAR(255) NOT NULL UNIQUE,
      expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
      used_at TIMESTAMP WITH TIME ZONE,
      created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      
      CONSTRAINT fk_password_reset_tokens_user_id 
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
      CONSTRAINT check_password_reset_tokens_used_at 
        CHECK(used_at IS NULL OR used_at >= created_at),
      CONSTRAINT check_password_reset_tokens_expires_at 
        CHECK(expires_at > created_at)
    );
    
    CREATE INDEX idx_password_reset_tokens_user_id_created_at 
      ON password_reset_tokens(user_id, created_at DESC);
    CREATE INDEX idx_password_reset_tokens_expires_at 
      ON password_reset_tokens(expires_at);
    CREATE INDEX idx_password_reset_tokens_used_at 
      ON password_reset_tokens(used_at);
  ''');
  
  print('✓ Created password_reset_tokens table');
}

Future<void> rollback(Connection connection) async {
  await connection.execute('DROP TABLE IF EXISTS password_reset_tokens;');
  print('✓ Dropped password_reset_tokens table');
}
```

### Migration 3: Create PasswordResetAttempt Table

**File**: `backend/migrations/009_create_password_reset_attempts_table.dart`

```dart
import 'package:postgres/postgres.dart';

Future<void> migration(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS password_reset_attempts (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email VARCHAR(255) NOT NULL,
      attempted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE INDEX idx_password_reset_attempts_email_attempted_at 
      ON password_reset_attempts(email, attempted_at DESC);
    CREATE INDEX idx_password_reset_attempts_attempted_at 
      ON password_reset_attempts(attempted_at);
  ''');
  
  print('✓ Created password_reset_attempts table');
}

Future<void> rollback(Connection connection) async {
  await connection.execute('DROP TABLE IF EXISTS password_reset_attempts;');
  print('✓ Dropped password_reset_attempts table');
}
```

### Migration 4: Add verified_at to Users Table

**File**: `backend/migrations/010_add_verified_at_to_users.dart`

```dart
import 'package:postgres/postgres.dart';

Future<void> migration(Connection connection) async {
  // Add column if not exists
  await connection.execute('''
    ALTER TABLE users
    ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;
  ''');
  
  // Create indexes
  await connection.execute('''
    CREATE INDEX IF NOT EXISTS idx_users_email_verified 
      ON users(email_verified);
    CREATE INDEX IF NOT EXISTS idx_users_verified_at 
      ON users(verified_at);
  ''');
  
  print('✓ Added verified_at column to users table');
}

Future<void> rollback(Connection connection) async {
  await connection.execute('ALTER TABLE users DROP COLUMN IF EXISTS verified_at;');
  await connection.execute('DROP INDEX IF EXISTS idx_users_verified_at;');
  print('✓ Removed verified_at column from users table');
}
```

---

## Data Relationships Diagram

```
User (from Spec 002)
  ├─ email_verified: BOOLEAN
  ├─ verified_at: TIMESTAMP (NEW)
  │
  ├─→ VerificationToken (1-to-many)
  │   ├─ id: UUID (PK)
  │   ├─ token_hash: VARCHAR (UNIQUE)
  │   ├─ expires_at: TIMESTAMP
  │   ├─ used_at: TIMESTAMP (nullable)
  │   └─ created_at: TIMESTAMP
  │
  └─→ PasswordResetToken (1-to-many)
      ├─ id: UUID (PK)
      ├─ token_hash: VARCHAR (UNIQUE)
      ├─ expires_at: TIMESTAMP
      ├─ used_at: TIMESTAMP (nullable)
      └─ created_at: TIMESTAMP

PasswordResetAttempt (independent)
  ├─ id: UUID (PK)
  ├─ email: VARCHAR (no FK)
  └─ attempted_at: TIMESTAMP
```

---

## Data Access Patterns

### Verification Flow
1. **Register**: User created with `email_verified = false`, `verified_at = NULL`
2. **Send verification**: Generate token → hash → store in VerificationToken
3. **Verify**: User clicks link → frontend extracts token → backend hashes token → lookup in VerificationToken
4. **Consume**: Mark VerificationToken.used_at = NOW(), set User.email_verified = true, User.verified_at = NOW()
5. **Resend**: New VerificationToken created, old token row remains but becomes unused

### Password Recovery Flow
1. **Forgot password**: User provides email → check rate limit on PasswordResetAttempt → generate token → store in PasswordResetToken
2. **Rate limit check**: `SELECT COUNT(*) FROM password_reset_attempts WHERE email = ? AND attempted_at > NOW() - INTERVAL '1 hour'`
3. **Reset password**: User clicks link → frontend extracts token → backend hashes token → lookup in PasswordResetToken
4. **Consume**: Mark PasswordResetToken.used_at = NOW(), update User.password_hash (bcrypt), invalidate all User sessions

### Cleanup Operations
1. **Expired token cleanup** (runs hourly or after 24+ hours):
   ```sql
   DELETE FROM verification_tokens WHERE expires_at < NOW() - INTERVAL '24 hours';
   DELETE FROM password_reset_tokens WHERE expires_at < NOW() - INTERVAL '24 hours';
   DELETE FROM password_reset_attempts WHERE attempted_at < NOW() - INTERVAL '1 day';
   ```

2. **Verification statistics** (audit/monitoring):
   ```sql
   SELECT COUNT(*) as total_users, 
          COUNT(*) FILTER (WHERE email_verified = true) as verified_users,
          COUNT(*) FILTER (WHERE email_verified = false) as pending_users
   FROM users;
   ```

3. **Recent verification rate** (monitoring):
   ```sql
   SELECT COUNT(*) as verified_in_last_24h
   FROM users
   WHERE verified_at > NOW() - INTERVAL '24 hours';
   ```

---

## Performance Considerations

### Indexes Justification
- **token_hash indexes (UNIQUE)**: Every token verification requires looking up by hash; must be fast
- **(user_id, created_at DESC)**: Finding latest token for resend scenario
- **expires_at indexes**: Cleanup queries to find and delete expired tokens
- **email indexes on PasswordResetAttempt**: Rate limit check queries (COUNT WHERE email AND time range)

### Query Performance Targets
- **Token verification**: `SELECT * FROM token_table WHERE token_hash = ? AND expires_at > NOW()` → <10ms (using UNIQUE index)
- **Rate limit check**: `SELECT COUNT(*) FROM password_reset_attempts WHERE email = ? AND attempted_at > NOW() - INTERVAL '1 hour'` → <50ms (using composite index)
- **Latest token lookup**: `SELECT * FROM token_table WHERE user_id = ? ORDER BY created_at DESC LIMIT 1` → <10ms (using composite index)
- **Cleanup deletion**: `DELETE FROM token_table WHERE expires_at < NOW()` → <100ms for typical volume

### Database Volume Estimates
- **Verification tokens**: ~N * 1.5 (considering resends) where N = total users (small table, quick cleanup)
- **Password reset tokens**: ~N * 0.1 (fewer reset requests than verification; short-lived)
- **Password reset attempts**: ~N * 5 - 10 (tracks last 24 hours; cleanup maintains size)

---

## Security Implications

### Token Storage Security
- **Stored as hash**: If database compromised, attacker cannot extract tokens directly
- **Never logged**: Tokens removed from logs before storage/display
- **Timing-safe comparison**: Prevents timing attacks that could leak token information

### Rate Limiting Security
- **Per-email not per-IP**: Prevents blocking legitimate multi-device users
- **No user enumeration**: Same response for existing/non-existing emails
- **Sliding window**: Prevents reset storms (distribution of requests over time)

### Expiration Security
- **24-hour window**: Balances security (limited time window) with UX (users likely to check email within 24h)
- **UTC timezone**: Prevents timezone-based confusion; all times consistent globally
- **Hard expiration**: Expired tokens completely unusable; no grace period

### Cascading Deletes
- **User deletion**: All associated tokens deleted automatically (user no longer has account)
- **Practical implication**: User deleted → account deleted → all reset/verification flows become invalid (database enforces)

