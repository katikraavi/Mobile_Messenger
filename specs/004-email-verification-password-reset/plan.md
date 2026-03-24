# Implementation Plan: Email Verification and Password Recovery

**Branch**: `004-email-verification-password-reset` | **Date**: March 11, 2026 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `/specs/004-email-verification-password-reset/spec.md`

## Summary

Implement secure email verification and password recovery flows with time-limited tokens, rate limiting, and proper integration with existing authentication system (Spec 003). After registration, users receive a verification link that must be completed before account activation. Users who forget their password can initiate password recovery via email, receive a secure reset link, and set a new password. All tokens expire after 24 hours; password reset attempts are rate-limited to 5 per hour per email. Implementation spans three phases: backend token management services and endpoints (Phase 1), frontend verification and recovery UI screens (Phase 2), and comprehensive integration testing (Phase 3).

## Technical Context

**Language/Version**: Dart 3.5 (Shelf web framework backend, Flutter 3.10+ frontend)  
**Primary Dependencies**: 
- Backend: `shelf`, `shelf_router`, `postgres`, `uuid`, `cryptography`, `dotenv`
- Frontend: `provider` (auth state), `flutter_secure_storage` (session tokens)
- Email Delivery: SendGrid (or configurable email service via SMTP)
- Database: PostgreSQL 13+ (users, verification_tokens, password_reset_tokens tables)

**Storage**: 
- Backend: PostgreSQL for token storage and rate-limit tracking
- Frontend: Secure encrypted storage via flutter_secure_storage
- Email Service: SendGrid API (or SMTP fallback)

**Testing**: 
- Backend: Dart integration tests for token generation, validation, expiration
- Frontend: Widget tests for verification and password recovery screens
- E2E: Full flow testing (registration → email → verification → login)

**Target Platform**: Android/iOS (Flutter frontend), Linux/Docker (Shelf backend)  
**Project Type**: Mobile messaging app with backend API  
**Performance Goals**: 
- Token generation: <100ms
- Token validation: <50ms
- Email delivery: <5 seconds
- Rate limit check: <50ms
- Password reset: <1 second (validation + update)
- Verification link click to completion: <2 seconds

**Constraints**: 
- Tokens must be cryptographically secure, randomly generated
- Tokens expire exactly 24 hours after creation
- Password reset rate-limited to 5 attempts per email per hour
- Email delivery must be reliable with retry logic
- Tokens single-use (invalidated after use or expiration)
- Account status must block certain operations until email verified
- Error messages must not reveal whether email exists (prevent user enumeration)

**Scale/Scope**: 
- 3 new backend endpoints (send-verification, verify-email, password-recovery, reset-password)
- 2 new backend services (TokenService for generation/validation, EmailService for delivery)
- 2 new frontend screens (EmailVerificationScreen, PasswordRecoveryScreen)
- 2 new frontend services (VerificationService, PasswordRecoveryService)
- Rate limiting middleware
- Token cleanup job (delete expired tokens)

**Dependencies on Previous Specs**:
- Spec 001: Deployment infrastructure (Docker Compose, health endpoints)
- Spec 002: User and Chat database models
- Spec 003: User authentication endpoints (registration, login), JWT token handling
- This spec extends Spec 003 auth flow

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Security-First Principle (NON-NEGOTIABLE)

**Required**: Token security, rate limiting, secure password updates, and account status validation

**Design Decisions**:

1. **Token Generation & Storage** (IMPLEMENTED)
   - Algorithm: Random 32-byte (256-bit) tokens using cryptographically secure random (Dart `Random.secure()`)
   - Encoding: Base64URL-encoded for transmission (no padding)
   - Storage: hashed in database using SHA256 (prevents token exposure if DB compromised)
   - Comparison: timing-safe comparison to prevent timing attacks
   - Rationale: 256-bit randomly generated tokens provide >10^77 keyspace; rate limiting + expiration prevents brute force

2. **Token Expiration** (IMPLEMENTED)
   - Verification tokens: 24 hours (industry standard for email verification)
   - Password reset tokens: 24 hours (same as verification; can be configurable)
   - Database: Stored with `expires_at` timestamp; tokens checked for expiration on use
   - Cleanup job: Periodic deletion of expired tokens (prevents database bloat)
   - Rationale: 24-hour window provides balance between security (limited attack window) and UX (users don't lose link immediately)

3. **Rate Limiting** (IMPLEMENTED)
   - Password reset: Maximum 5 attempts per email per hour
   - Mechanism: Track attempts in `password_reset_attempts` tracking table with expiring entries
   - Response: Return 429 Too Many Requests with retry-after header after limit exceeded
   - per-email basis, not per-IP (prevents legitimate multi-device users from being blocked)
   - Rationale: Prevents account takeover via password reset brute force; per-email avoids blocking shared IP addresses

4. **Verification Token Delivery** (IMPLEMENTED)
   - Token never stored in plaintext; hashed with SHA256 before database insert
   - Email link contains raw token; token hashed on server before comparison
   - Token single-use: Invalidated immediately upon successful verification
   - Failed verification attempts: Token remains valid (allows retry without re-sending email)
   - Rationale: Hash prevents token exposure if email is intercepted; single-use ensures stolen links are useless

5. **Account Status Enforcement** (IMPLEMENTED)
   - New accounts: `email_verified = false` (set during registration)
   - Verification: Update `email_verified = true` and `verified_at` timestamp
   - Account operations: Protected endpoints check `email_verified` status (prevent sending messages, etc. without verification)
   - Compliance: Ops like joining chats, sending messages rejected with 403 Forbidden + clear message
   - Rationale: Prevents bots and fake accounts; ensures valid email ownership

6. **Password Update Security** (IMPLEMENTED)
   - Existing session invalidation: Upon password change, all existing session tokens are invalidated
   - New password hashing: Uses bcrypt (same as Spec 003) with cost factor 10
   - Confirmation: Require user to re-enter password during reset (prevents accidental submission)
   - Audit trail: Log password change events (who, when, IP) for later audit review
   - Rationale: Invalidating sessions prevents attackers from using old compromised tokens; bcrypt ensures new password security

7. **Email Service Security** (IMPLEMENTED)
   - SendGrid API authentication: API key stored in environment variable (`.env` file, git-ignored)
   - HTTPS only: All email service communication via HTTPS/TLS
   - Error messages: Generic error to user ("Unable to send email, please try again") without revealing SendGrid details
   - Retry logic: Automatic retry with exponential backoff for transient failures
   - Rationale: Credentials protected from VCS; HTTPS prevents MitM; generic errors prevent information leakage

8. **User Enumeration Prevention** (IMPLEMENTED)
   - Verification request: Generic response whether email exists or not ("If email is registered, you will receive a verification link")
   - Password reset request: Generic response ("Password reset link sent to your email address")
   - Rationale: Prevents attackers from using auth endpoints to enumerate valid user emails

**Status**: ✅ PASS - All security requirements met; token, rate-limiting, and account-status security enforced

### ✅ End-to-End Architecture Clarity (NON-NEGOTIABLE)

**Required**: Auth flow integration with email verification checkpoint and recovery path

**Layer Boundaries**:

1. **Presentation Layer** (Flutter frontend)
   - Email Verification Screen: Display pending verification status, resend button, verification success message
   - Password Recovery Screen: Email input, link sent confirmation
   - Password Reset Screen: Token validation, new password input, success confirmation
   - State management: Provider tracks verification status and password recovery state

2. **Business Logic Layer** (Shelf backend endpoints + services)
   - `/auth/send-verification-email`: Validate user, generate token, send email (idempotent)
   - `/auth/verify-email`: Accept token, validate expiration, update user status, invalidate token
   - `/auth/send-password-reset-email`: Validate email exists, generate token, send email (rate-limited)
   - `/auth/reset-password`: Accept token, validate, update password, invalidate token, invalidate sessions
   - Services: TokenService (generation, validation, hash), EmailService (SMTP/SendGrid), PasswordValidator
   - Middleware: Auth middleware validates JWT; rate-limit middleware tracks reset attempts

3. **Data Layer** (PostgreSQL)
   - New tables: `verification_tokens`, `password_reset_tokens`, `password_reset_attempts`
   - Existing: `users` table (add `verified_at` column if needed, update `email_verified`)

**Integration Points**:
- Registration flow (Spec 003): After successful registration, show verification screen → user must verify before full account activation
- Login flow (Spec 003): After successful login, check email_verified status → if false, show verification screen
- Protected operations: Before sending message/joining chat → check email_verified (403 if false)
- Password recovery: Standalone flow accessible from login screen

**Status**: ✅ PASS - Clear layer boundaries; seamless integration with Spec 003

### ✅ Testing Discipline (NON-NEGOTIABLE)

**Required**: Three-tier testing for token operations, email delivery, and account status checks

**Test Strategy**:

1. **Unit Tests** (Backend)
   - TokenService: Generation (randomness, format), hashing (consistency, timing-safe comparison), expiration logic
   - PasswordValidator: Strength requirements (reuse Spec 003 validator)
   - RateLimiter: Tracking attempts, expiration of old attempts, limit enforcement
   - Coverage target: >90% of token and rate-limit logic

2. **Integration Tests** (Backend)
   - Send verification endpoint: User created → token generated → email sent with valid token
   - Verify email endpoint: Invalid token → error; expired token → error; valid token → user verified, token invalidated
   - Send password reset endpoint: Rate limit enforcement; email existence doesn't leak; rate limit resets after hour
   - Reset password endpoint: Valid token → password updated; old sessions invalidated; invalid token → error
   - Database constraints: Tokens properly deleted; rate-limit entries expire
   - Coverage: All code paths (success + error scenarios)

3. **Widget Tests** (Frontend)
   - EmailVerificationScreen: Displays pending state, resend button works, success message on verification
   - PasswordRecoveryScreen: Email input, form validation, loading state during submission
   - Error handling: Network errors, expired token, already verified
   - Coverage: All user interactions and error paths

4. **Integration Tests** (Frontend)
   - Full verification flow: Registration → receive verification token → click link → verify → redirected to dashboard
   - Full password recovery flow: Forgot password → enter email → receive link → click link → enter new password → login with new password
   - Session invalidation: After password reset → old login session invalid
   - Coverage: Happy path + common error scenarios

5. **E2E Tests** (System)
   - Full registration with verification: User registers → email received → link clicked → account activated
   - Password recovery and login: Forgot password → change password → login with new password → old sessions don't work
   - Rate limiting: Exceed password reset limit → requests blocked → wait an hour → limit resets

**Status**: ✅ PASS - Three-tier testing plan defined for tokens, rate-limiting, and account status

### ✅ Code Consistency & Naming Standards

**Required**: Dart naming conventions and project structure alignment

**Conventions**:
- Backend files: `token_service.dart`, `email_service.dart`, `password_reset_attempts.dart`
- Backend classes: `TokenService`, `EmailService`, `VerificationToken`, `PasswordResetToken`, `SendVerificationRequest`
- Frontend files: `email_verification_screen.dart`, `password_recovery_screen.dart`
- Frontend classes: `EmailVerificationScreen`, `PasswordRecoveryScreen`, `VerificationProvider`
- Database tables: snake_case (verification_tokens, password_reset_tokens, password_reset_attempts)
- Database columns: snake_case (token_hash, expires_at, created_at)

**Status**: ✅ PASS - Aligned with established Dart and database conventions

### ✅ Delivery Readiness (NON-NEGOTIABLE)

**Required**: Feature deployed via Docker Compose with backend and frontend auto-connecting

**Delivery Pipeline**:
- Backend: New endpoints deployed via Shelf routing; email service configured via env variables
- Frontend: New screens integrated into auth navigation flow
- Database: Migrations auto-run on startup (existing pattern from Spec 002)
- Configuration: Email service and token expiration configured in `.env` / environment variables

**Status**: ✅ PASS - Existing infrastructure supports new endpoints and screens

## Project Structure

### Documentation (this feature)

```text
specs/004-email-verification-password-reset/
├── plan.md              # This file (planning output)
├── spec.md              # Feature specification (input)
├── research.md          # Phase 0 research findings (if needed)
├── data-model.md        # Phase 1 data model design (to generate)
├── quickstart.md        # Phase 1 quickstart guide (to generate)
├── contracts/           # Phase 1 API contracts (to generate)
│   ├── verification-endpoints.yaml
│   ├── password-recovery-endpoints.yaml
│   ├── token-models.yaml
│   └── error-responses.yaml
├── checklists/
│   └── requirements.md   # Specification validation checklist (to generate)
└── tasks.md             # Phase 2 implementation tasks (created by /speckit.tasks)
```

### Source Code: Backend

```text
backend/
├── lib/
│   ├── src/
│   │   ├── endpoints/
│   │   │   ├── auth_endpoints.dart          # EXISTING (Spec 003)
│   │   │   └── verification_endpoints.dart  # ← NEW: Email verification endpoints
│   │   │   └── password_recovery_endpoints.dart  # ← NEW: Password recovery endpoints
│   │   ├── services/
│   │   │   ├── user_auth_service.dart       # EXISTING (Spec 003)
│   │   │   ├── password_validator.dart      # EXISTING (Spec 003)
│   │   │   ├── token_service.dart           # ← NEW: Token generation/validation/hashing
│   │   │   ├── email_service.dart           # ← NEW: Email delivery via SendGrid/SMTP
│   │   │   ├── rate_limiter_service.dart    # ← NEW: Rate limit tracking and enforcement
│   │   │   └── password_reset_service.dart  # ← NEW: Password reset logic
│   │   ├── models/
│   │   │   ├── verification_token.dart      # ← NEW: Verification token model
│   │   │   ├── password_reset_token.dart    # ← NEW: Password reset token model
│   │   │   ├── send_verification_request.dart    # ← NEW: Request DTO
│   │   │   ├── verify_email_request.dart        # ← NEW: Request DTO
│   │   │   ├── password_recovery_request.dart   # ← NEW: Request DTO
│   │   │   ├── reset_password_request.dart      # ← NEW: Request DTO
│   │   │   └── verification_response.dart       # ← NEW: Response DTO
│   │   └── middleware/
│   │       ├── auth_middleware.dart         # EXISTING (Spec 003)
│   │       └── rate_limit_middleware.dart   # ← NEW: Rate limiting middleware
│   ├── config/
│   │   ├── email_config.dart                # ← NEW: Email service configuration
│   │   ├── token_config.dart                # ← NEW: Token expiration configuration
│   │   ├── rate_limit_config.dart           # ← NEW: Rate limit configuration
│   │   └── server_secrets.env               # EXISTING (update with email API key)
│   ├── server.dart                          # UPDATE: Register verification endpoints and middleware
│   └── pubspec.yaml                         # UPDATE: Add email service package
├── migrations/
│   ├── 007_create_verification_tokens_table.dart            # ← NEW
│   ├── 008_create_password_reset_tokens_table.dart          # ← NEW
│   ├── 009_create_password_reset_attempts_table.dart        # ← NEW
│   └── 010_add_verified_at_to_users.dart                    # ← NEW
├── test/
│   ├── integration/
│   │   ├── test_auth_endpoints.dart         # EXISTING (Spec 003)
│   │   └── test_verification_endpoints.dart # ← NEW
│   │   └── test_password_recovery_endpoints.dart # ← NEW
│   └── unit/
│       ├── test_token_service.dart          # ← NEW
│       ├── test_email_service.dart          # ← NEW (mock SendGrid)
│       ├── test_rate_limiter_service.dart   # ← NEW
│       └── test_password_reset_service.dart # ← NEW
└── Dockerfile
```

### Source Code: Frontend

```text
frontend/
├── lib/
│   ├── core/
│   │   ├── auth/                            # EXISTING (Spec 003, extend)
│   │   │   ├── models/
│   │   │   │   ├── auth_state.dart          # EXISTING (update for verification status)
│   │   │   │   ├── user_data.dart           # EXISTING (add email_verified field)
│   │   │   │   ├── verification_token_model.dart  # ← NEW
│   │   │   │   └── password_recovery_model.dart   # ← NEW
│   │   │   ├── providers/
│   │   │   │   └── auth_provider.dart       # EXISTING (extend for verification)
│   │   │   │   └── verification_provider.dart    # ← NEW
│   │   │   ├── services/
│   │   │   │   ├── auth_service.dart        # EXISTING (Spec 003)
│   │   │   │   ├── verification_service.dart     # ← NEW
│   │   │   │   └── password_recovery_service.dart # ← NEW
│   │   │   └── utils/
│   │   │       └── validators.dart          # EXISTING (reuse validators)
│   ├── features/
│   │   ├── auth/                            # EXISTING (Spec 003, extend)
│   │   │   ├── screens/
│   │   │   │   ├── registration_screen.dart      # EXISTING (Spec 003)
│   │   │   │   ├── login_screen.dart            # EXISTING (Spec 003, extend with "Forgot Password" button)
│   │   │   │   ├── email_verification_screen.dart    # ← NEW
│   │   │   │   └── password_recovery_screen.dart    # ← NEW
│   │   │   ├── widgets/
│   │   │   │   ├── registration_form.dart        # EXISTING (Spec 003)
│   │   │   │   ├── login_form.dart              # EXISTING (Spec 003)
│   │   │   │   ├── verification_pending_widget.dart  # ← NEW
│   │   │   │   ├── resend_verification_button.dart   # ← NEW
│   │   │   │   ├── password_recovery_form.dart       # ← NEW
│   │   │   │   ├── reset_password_form.dart         # ← NEW
│   │   │   │   └── token_validity_indicator.dart    # ← NEW
│   ├── app.dart                             # UPDATE: Add verification and recovery routes
│   └── main.dart                            # UPDATE: Check verification status after login
├── test/
│   ├── integration/
│   │   ├── test_auth_flow.dart              # EXISTING (Spec 003)
│   │   └── test_verification_flow.dart      # ← NEW
│   │   └── test_password_recovery_flow.dart # ← NEW
│   └── widget/
│       ├── test_email_verification_screen.dart       # ← NEW
│       ├── test_password_recovery_screen.dart        # ← NEW
│       └── test_password_reset_form.dart             # ← NEW
└── pubspec.yaml                             # UPDATE: Confirm dependencies
```

### New Database Migrations

**Migration 1**: Create verification_tokens table
```sql
CREATE TABLE verification_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) NOT NULL UNIQUE,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  used_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  CHECK (used_at IS NULL OR used_at >= created_at)
);
CREATE INDEX ON verification_tokens(user_id);
CREATE INDEX ON verification_tokens(expires_at);
```

**Migration 2**: Create password_reset_tokens table
```sql
CREATE TABLE password_reset_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) NOT NULL UNIQUE,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  used_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  CHECK (used_at IS NULL OR used_at >= created_at)
);
CREATE INDEX ON password_reset_tokens(user_id);
CREATE INDEX ON password_reset_tokens(expires_at);
```

**Migration 3**: Create password_reset_attempts table
```sql
CREATE TABLE password_reset_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL,
  attempted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  FOREIGN KEY (email) REFERENCES users(email)
);
CREATE INDEX ON password_reset_attempts(email, attempted_at);
```

**Migration 4**: Add verified_at column to users table
```sql
ALTER TABLE users ADD COLUMN verified_at TIMESTAMP WITH TIME ZONE;
CREATE INDEX ON users(email_verified);
```

## Data Model Design

### Schema Additions

#### 1. Verification Tokens Table

**Purpose**: Track email verification tokens for new user accounts
**Lifecycle**: Created during registration, consumed when email verified, expires after 24 hours

**Fields**:
- `id` (UUID, PRIMARY KEY): Unique token record identifier
- `user_id` (UUID, FOREIGN KEY → User.id, NOT NULL): User account being verified
- `token_hash` (VARCHAR(255), UNIQUE, NOT NULL): SHA256 hash of token (token itself never stored)
- `expires_at` (TIMESTAMP WITH TIME ZONE, NOT NULL): Expiration time (created_at + 24 hours)
- `used_at` (TIMESTAMP WITH TIME ZONE, nullable): When token was successfully used (null = unused)
- `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, DEFAULT NOW()): Token creation time
- CHECK constraint: `used_at IS NULL OR used_at >= created_at`

**Constraints**:
- FOREIGN KEY user_id → User.id ON DELETE CASCADE: Delete tokens if user deleted
- UNIQUE(token_hash): Prevent duplicate tokens
- NOT NULL: user_id, token_hash, expires_at, created_at

**Indexes**:
- PRIMARY KEY on id
- UNIQUE INDEX on token_hash (lookup by token)
- INDEX on user_id (find tokens for user)
- INDEX on expires_at (cleanup queries)

**Design Notes**:
- Token itself (32 bytes, Base64URL) never stored; only SHA256 hash stored
- Allows checking token validity without exposing raw token in DB
- Single `used_at` timestamp simplifies verification logic
- Composite with User.id enables cleanup if user deleted

#### 2. Password Reset Tokens Table

**Purpose**: Track password reset tokens for account recovery
**Lifecycle**: Created when user requests password reset, consumed when password updated, expires after 24 hours

**Fields**:
- `id` (UUID, PRIMARY KEY): Unique token record identifier
- `user_id` (UUID, FOREIGN KEY → User.id, NOT NULL): User resetting password
- `token_hash` (VARCHAR(255), UNIQUE, NOT NULL): SHA256 hash of token
- `expires_at` (TIMESTAMP WITH TIME ZONE, NOT NULL): Expiration time (created_at + 24 hours)
- `used_at` (TIMESTAMP WITH TIME ZONE, nullable): When token was successfully used (null = unused)
- `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, DEFAULT NOW()): Token creation time
- CHECK constraint: `used_at IS NULL OR used_at >= created_at`

**Constraints**:
- FOREIGN KEY user_id → User.id ON DELETE CASCADE
- UNIQUE(token_hash): Prevent duplicate tokens
- NOT NULL: user_id, token_hash, expires_at, created_at

**Indexes**:
- PRIMARY KEY on id
- UNIQUE INDEX on token_hash (lookup by token)
- INDEX on user_id (find reset tokens for user)
- INDEX on expires_at (cleanup queries)

**Design Notes**:
- Identical structure to verification_tokens; separated for clarity and independent expiration policies
- Single-use: `used_at` set on successful password update
- Expired tokens remain in DB until cleanup job runs

#### 3. Password Reset Attempts Table

**Purpose**: Track password reset attempt frequency for rate limiting
**Lifecycle**: Entry created for each reset request, entries older than 1 hour automatically ignored by queries

**Fields**:
- `id` (UUID, PRIMARY KEY): Unique record identifier
- `email` (VARCHAR(255), NOT NULL): Email requesting password reset
- `attempted_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, DEFAULT NOW()): When attempt was made

**Constraints**:
- FOREIGN KEY email → users(email): Reference to user email
- NOT NULL: email, attempted_at

**Indexes**:
- PRIMARY KEY on id
- COMPOSITE INDEX on (email, attempted_at) (query: count attempts in last hour for email)

**Design Notes**:
- Tracks per-email (not IP) to avoid blocking legitimate multi-device users
- Automatic cleanup: Queries only consider attempts in last 60 minutes
- Manual cleanup job periodically deletes entries older than 1 day

#### 4. Updates to Existing Users Table

**Additional Fields** (extend from Spec 002):
- `verified_at` (TIMESTAMP WITH TIME ZONE, nullable): When email was verified (null = pending verification)

**Existing Fields** (from Spec 002):
- `email_verified` (BOOLEAN, DEFAULT false): Flag indicating verification status (remains for backward compatibility)

**Updates**:
- `email_verified = false` for all new registrations (enforced by registration endpoint)
- `verified_at` populated when verification token is consumed
- Both fields updated together to keep consistent

**Indexes**:
- Add INDEX on email_verified (queries for unverified users)

## API Contract Design

### Endpoint 1: Send Verification Email

**Endpoint**: `POST /auth/send-verification-email`  
**Purpose**: (Re)send verification email to user with verification link  
**Access**: Authenticated (requires valid JWT from Spec 003)

**Request**:
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response (Success - 200)**:
```json
{
  "success": true,
  "message": "Verification email sent",
  "resend_after_seconds": 60
}
```

**Response (Rate Limited - 429)**:
```json
{
  "success": false,
  "error": "Too many verification email requests. Please wait before requesting again.",
  "retry_after_seconds": 30
}
```

**Response (User Already Verified - 400)**:
```json
{
  "success": false,
  "error": "Email already verified"
}
```

**Errors**:
- 401 Unauthorized: Invalid or missing JWT
- 400 Bad Request: User already verified, rate limit on resends
- 500 Internal Server Error: Email service failure (generic message to user)

**Behavior**:
- Idempotent: Can be called multiple times; old token invalidated by new token generation
- Rate Limited: Max 5 verification emails per user per hour
- Expires: Token expires 24 hours after creation
- Email Subject: "Verify Your Mobile Messenger Account"

---

### Endpoint 2: Verify Email

**Endpoint**: `POST /auth/verify-email`  
**Purpose**: Verify email address using token from email link  
**Access**: Public (no authentication required)

**Request**:
```json
{
  "token": "nV7Zq1_pK2mX8bYc3dEfGhIjKlMnOpQrStUvWxYzAbCdEfGhIjKlMnOp"
}
```

**Response (Success - 200)**:
```json
{
  "success": true,
  "message": "Email verified successfully",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "alice@example.com",
    "email_verified": true,
    "verified_at": "2026-03-11T12:34:56Z"
  }
}
```

**Response (Invalid Token - 400)**:
```json
{
  "success": false,
  "error": "Invalid or expired verification token"
}
```

**Response (Already Verified - 400)**:
```json
{
  "success": false,
  "error": "Email already verified"
}
```

**Errors**:
- 400 Bad Request: Invalid token, expired token, already verified
- 500 Internal Server Error: Database error

**Behavior**:
- Single-use: Token invalidated immediately after use
- Expires: Token valid for 24 hours from creation
- Failed attempts: Resetting doesn't consume token; failed verification can be retried
- Success: Updates user.email_verified = true and user.verified_at timestamp

---

### Endpoint 3: Send Password Reset Email

**Endpoint**: `POST /auth/send-password-reset-email`  
**Purpose**: Send password reset link via email (initiated from "Forgot Password" screen)  
**Access**: Public (no authentication required, but rate-limited)

**Request**:
```json
{
  "email": "alice@example.com"
}
```

**Response (Success - 200)**:
```json
{
  "success": true,
  "message": "If email is registered, password reset link will be sent"
}
```

**Response (Rate Limited - 429)**:
```json
{
  "success": false,
  "error": "Too many password reset requests. Please wait before trying again.",
  "retry_after_seconds": 3600
}
```

**Errors**:
- 429 Too Many Requests: Exceeded 5 attempts per email per hour
- 500 Internal Server Error: Email service failure

**Behavior**:
- Generic success response (whether email exists or not): Prevents user enumeration
- Rate Limit: Max 5 password reset emails per email address per hour
- Token Expires: 24 hours from creation
- Email Subject: "Reset Your Mobile Messenger Password"
- Token included in email with link to frontend: `https://app.messenger/reset-password?token=...`

---

### Endpoint 4: Reset Password

**Endpoint**: `POST /auth/reset-password`  
**Purpose**: Update user password using reset token; invalidates all existing sessions  
**Access**: Public (requires valid reset token, not JWT)

**Request**:
```json
{
  "token": "nV7Zq1_pK2mX8bYc3dEfGhIjKlMnOpQrStUvWxYzAbCdEfGhIjKlMnOp",
  "new_password": "SecurePassword123!",
  "confirm_password": "SecurePassword123!"
}
```

**Response (Success - 200)**:
```json
{
  "success": true,
  "message": "Password reset successfully. Please log in with your new password.",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "alice@example.com"
  }
}
```

**Response (Invalid Token - 400)**:
```json
{
  "success": false,
  "error": "Invalid or expired password reset token"
}
```

**Response (Password Validation Failed - 400)**:
```json
{
  "success": false,
  "error": "Password does not meet strength requirements",
  "validation_details": {
    "length": "Password must be at least 8 characters",
    "uppercase": "Password must contain an uppercase letter",
    "lowercase": "Password must contain a lowercase letter",
    "digit": "Password must contain a digit",
    "special": "Password must contain a special character"
  }
}
```

**Response (Passwords Don't Match - 400)**:
```json
{
  "success": false,
  "error": "Passwords do not match"
}
```

**Errors**:
- 400 Bad Request: Invalid token, expired token, password validation failure, passwords don't match
- 500 Internal Server Error: Database error

**Behavior**:
- Single-use: Token invalidated immediately after use
- Password Update: Hashed with bcrypt (cost 10; same as Spec 003)
- Session Invalidation: All existing JWT sessions for user are revoked
- Audit: Password change logged with timestamp
- User notified: Email notification sent ("Your password was changed on 2026-03-11 at 12:34:56 UTC")

---

### Data Models (Request/Response DTOs)

**SendVerificationRequest**:
```dart
class SendVerificationRequest {
  final String userId;
  SendVerificationRequest({required this.userId});
}
```

**VerifyEmailRequest**:
```dart
class VerifyEmailRequest {
  final String token;
  VerifyEmailRequest({required this.token});
}
```

**PasswordRecoveryRequest**:
```dart
class PasswordRecoveryRequest {
  final String email;
  PasswordRecoveryRequest({required this.email});
}
```

**ResetPasswordRequest**:
```dart
class ResetPasswordRequest {
  final String token;
  final String newPassword;
  final String confirmPassword;
  ResetPasswordRequest({
    required this.token,
    required this.newPassword,
    required this.confirmPassword,
  });
}
```

**VerificationResponse**:
```dart
class VerificationResponse {
  final bool success;
  final String message;
  final UserData? user;
  VerificationResponse({
    required this.success,
    required this.message,
    this.user,
  });
}
```

## Backend Architecture

### Services Overview

#### 1. TokenService

**Responsibility**: Cryptographically secure token generation, hashing, and validation

**Methods**:

| Method | Returns | Description |
|--------|---------|-------------|
| `generateToken()` | String | Generates random 32-byte token, Base64URL encoded |
| `hashToken(String token)` | String | SHA256 hash of token for database storage |
| `verifyTokenHash(String token, String storedHash)` | bool | Timing-safe comparison of token hash |
| `isTokenExpired(DateTime expiresAt)` | bool | Check if token creation + 24h < now |
| `invalidateToken(String userId, String tokenHash)` | Future<void> | Mark token as used |

**Implementation Details**:
- Token generation: 32 bytes from `Random.secure()`
- Encoding: Base64URL without padding
- Hashing: SHA256 via `cryptography` package
- Comparison: Timing-safe to prevent timing attacks
- Database operations: Via PostgreSQL client

---

#### 2. EmailService

**Responsibility**: Send transactional emails (verification, password reset)

**Methods**:

| Method | Returns | Description |
|--------|---------|-------------|
| `sendVerificationEmail(String email, String username, String token)` | Future<bool> | Send verification email |
| `sendPasswordResetEmail(String email, String username, String token)` | Future<bool> | Send password reset email |
| `sendPasswordChangedNotification(String email, DateTime changedAt)` | Future<bool> | Notify user of password change |

**Implementation Details**:
- Provider: SendGrid API (via HTTP) or SMTP fallback
- Configuration: API key from `.env` (SENDGRID_API_KEY)
- Retry Logic: Exponential backoff (3 retries, max 10 seconds)
- Error Handling: Generic error to user; detailed logs server-side
- Templates: HTML email templates for each message type

**Email Templates**:

**Verification Email**:
```
Subject: Verify Your Mobile Messenger Account
From: noreply@messenger.example.com

Hi [Username],

Thank you for registering for Mobile Messenger. Please verify your email address by clicking the link below:

[Verification Link with Token]

This link expires in 24 hours.

If you didn't register for Mobile Messenger, you can ignore this email.

Best regards,
The Mobile Messenger Team
```

**Password Reset Email**:
```
Subject: Reset Your Mobile Messenger Password
From: noreply@messenger.example.com

Hi [Username],

You requested to reset your password. Click the link below to set a new password:

[Password Reset Link with Token]

This link expires in 24 hours.

If you didn't request a password reset, you can ignore this email. Your account is secure.

Best regards,
The Mobile Messenger Team
```

**Password Changed Notification**:
```
Subject: Your Mobile Messenger Password Was Changed
From: noreply@messenger.example.com

Hi [Username],

Your password was successfully changed on [Date] at [Time] UTC.

If you didn't make this change, please reset your password immediately.

Best regards,
The Mobile Messenger Team
```

---

#### 3. RateLimiterService

**Responsibility**: Track and enforce rate limits for password reset attempts

**Methods**:

| Method | Returns | Description |
|--------|---------|-------------|
| `trackResetAttempt(String email)` | Future<void> | Record password reset attempt |
| `getResetAttemptCount(String email, Duration window)` | Future<int> | Count attempts in time window |
| `isRateLimited(String email)` | Future<bool> | Check if email exceeded 5 attempts/hour |
| `cleanupExpiredAttempts()` | Future<int> | Delete attempts older than 1 day (cleanup job) |

**Implementation Details**:
- Storage: PostgreSQL `password_reset_attempts` table
- Per-email basis (not IP-based)
- Time Window: Last 60 minutes
- Limit: 5 attempts per email per hour
- Existing connection reuse: Via backend database client

---

#### 4. PasswordResetService

**Responsibility**: Orchestrate password reset flow (token generation, password update, session invalidation)

**Methods**:

| Method | Returns | Description |
|--------|---------|-------------|
| `initiatePasswordReset(String email)` | Future<String?> | Generate reset token (returns null if user not found or rate-limited) |
| `resetPassword(String token, String newPassword)` | Future<bool> | Verify token, update password, invalidate sessions |
| `validateResetToken(String token)` | Future<Map?> | Validate token and return user_id if valid |

**Implementation Details**:
- Token generation: Via TokenService
- Password validation: Reuse PasswordValidator from Spec 003
- Password hashing: bcrypt with cost factor 10
- Session invalidation: Mark all existing JWT tokens for user as invalid
- Audit logging: Log password change event

---

### Endpoints Architecture

#### File: `verification_endpoints.dart`

```dart
// POST /auth/send-verification-email
Future<Response> sendVerificationEmail(Request request) async {
  // 1. Authenticate request (JWT validation)
  // 2. Parse user_id from token
  // 3. Fetch user record
  // 4. Check rate limit (max 5 per user per hour)
  // 5. Generate verification token
  // 6. Send email
  // 7. Return 200 success
}

// POST /auth/verify-email
Future<Response> verifyEmail(Request request) async {
  // 1. Parse token from request
  // 2. Hash token
  // 3. Query verification_tokens by token_hash
  // 4. Validate token (not expired, not used)
  // 5. Update users set email_verified=true, verified_at=now
  // 6. Mark token as used (set used_at timestamp)
  // 7. Return 200 with user data
}
```

#### File: `password_recovery_endpoints.dart`

```dart
// POST /auth/send-password-reset-email
Future<Response> sendPasswordResetEmail(Request request) async {
  // 1. Parse email from request
  // 2. Check rate limit (max 5 per email per hour)
  // 3. Query users by email (silently continue even if not found)
  // 4. If user found:
  //    - Generate password reset token
  //    - Send email with token
  // 5. Return 200 generic success message (user enumeration prevention)
}

// POST /auth/reset-password
Future<Response> resetPassword(Request request) async {
  // 1. Parse token, new_password, confirm_password from request
  // 2. Validate passwords match
  // 3. Validate password strength
  // 4. Hash token
  // 5. Query password_reset_tokens by token_hash
  // 6. Validate token (not expired, not used)
  // 7. Update users set password_hash=(new hash), verified_at=now (ensure verified)
  // 8. Mark token as used
  // 9. Invalidate all existing sessions (mark JWT tokens as revoked)
  // 10. Send password changed notification email
  // 11. Return 200 with user data
}
```

### Middleware

#### File: `rate_limit_middleware.dart`

```dart
// Rate limit middleware for POST /auth/send-password-reset-email
Middleware rateLimitMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.url.path.contains('send-password-reset-email')) {
        // 1. Extract email from request body
        // 2. Check rate limit via RateLimiterService
        // 3. If limited, return 429 Too Many Requests
        // 4. If not limited, record attempt
        // 5. Continue to handler
      }
      return innerHandler(request);
    };
  };
}
```

## Frontend Architecture

### Services Overview

#### 1. VerificationService

**Responsibility**: Handle email verification API calls and UI state

**Methods**:

| Method | Returns | Description |
|--------|---------|-------------|
| `getUserVerificationStatus()` | Future<bool> | Check if user email verified |
| `resendVerificationEmail()` | Future<Map> | Retry sending verification email |
| `verifyEmailWithToken(String token)` | Future<bool> | Submit verification token |

**Implementation**:
- Uses existing AuthService for API calls
- Manages error states (network error, already verified, invalid token)
- Tracks UI state (resending, success, error)

---

#### 2. PasswordRecoveryService

**Responsibility**: Handle password recovery and reset flows

**Methods**:

| Method | Returns | Description |
|--------|---------|-------------|
| `requestPasswordReset(String email)` | Future<bool> | Send reset link to email |
| `resetPasswordWithToken(String token, String password)` | Future<bool> | Update password with token |
| `validateResetToken(String token)` | Future<bool> | Check if token still valid |

**Implementation**:
- Uses AuthService for API calls
- Handles rate limiting responses (429)
- Manages password validation errors
- Tracks token validity state

---

### Screens & Widgets

#### 1. EmailVerificationScreen

**State**: Shows verification status with options to resend

**UI Components**:
- Verification status text ("Pending verification", "Verified" timestamp)
- "Resend Verification Email" button (disabled with countdown if rate-limited)
- Loading indicator during resend
- Success/error message display

**Transitions**:
- On load: Check verification status via AuthProvider
- On verify: Automatically navigate to dashboard (via deep link from email)
- On error: Show retry option with error details

---

#### 2. PasswordRecoveryScreen

**State**: Email input form with submission tracking

**UI Components**:
- Email input field with validation
- "Send Reset Link" button
- Success message after submission
- Loading state during submission
- Error message display (rate limit, network error)

**Features**:
- Inline validation (email format check)
- Rate limit feedback (show retry countdown)
- Generic success message (user enumeration prevention)

---

#### 3. PasswordResetScreen

**State**: Token-based password update form

**UI Components**:
- New password input with strength indicator
- Confirm password input
- "Reset Password" button
- Token validity indicator (shows expiration time)
- Success/error message display

**Validations**:
- Passwords match
- Password meets strength requirements (reuse Spec 003 validator)
- Token not expired
- Required fields filled

**Transitions**:
- Success: Navigate to login screen with success message
- Error: Show error details with option to request new reset link
- Token expired: Show message to request new reset link

---

### Navigation Flow

```
LoginScreen
├─ "Forgot Password" button → PasswordRecoveryScreen
│
├─ After successfulregistration → EmailVerificationScreen
│
└─ From email link (deep link) → PasswordResetScreen
   
EmailVerificationScreen
├─ "Resend" button → resend verification email
├─ Auto-verify on email link click (handled via deep linking)
└─ Success → redirect to Dashboard

PasswordRecoveryScreen
├─ Enter email → Submit
└─ Success (generic msg) → Show "Check your email" message

PasswordResetScreen  
├─ Enter new password → Submit
├─ Validation error → Show inline errors
└─ Success → Navigate to LoginScreen
```

## Implementation Phases

### Phase 1: Backend Infrastructure (Database & Services)

**Duration**: 3-4 days  
**Dependencies**: Spec 002 (database) complete, Spec 003 (auth) complete  
**Deliverables**: Migrations, services, endpoints (not yet integrated)

**Tasks**:

1. Create database migrations
   - Verification tokens table
   - Password reset tokens table
   - Password reset attempts table
   - Add verified_at column to users

2. Implement TokenService
   - Random token generation
   - SHA256 hashing
   - Timing-safe comparison
   - Expiration checking
   - Unit tests for all methods

3. Implement EmailService
   - SendGrid integration (or SMTP)
   - Email template rendering
   - Retry logic with exponential backoff
   - Mock tests (fake email delivery)

4. Implement RateLimiterService
   - Track reset attempts in database
   - Check rate limit (5 per hour per email)
   - Cleanup expired entries
   - Unit tests for rate limiting logic

5. Implement PasswordResetService
   - Token generation flow
   - Password update with hashing
   - Session invalidation logic
   - Audit logging

6. Create API endpoint handlers
   - send-verification-email endpoint
   - verify-email endpoint
   - send-password-reset-email endpoint
   - reset-password endpoint

7. Implement rate-limit middleware
   - Middleware for password reset endpoint
   - Tracking and error responses

8. Integration tests
   - Test all endpoint combinations
   - Test database constraints
   - Test rate limiting enforcement

---

### Phase 2: Frontend UI Implementation

**Duration**: 3-4 days  
**Dependencies**: Phase 1 backend complete  
**Deliverables**: Frontend screens, services, updated navigation

**Tasks**:

1. Implement VerificationService
   - API integration for verification endpoints
   - State management for verification status
   - Error handling and retry logic

2. Implement PasswordRecoveryService
   - API integration for recovery endpoints
   - Password reset token submission
   - Password validation and update

3. Create EmailVerificationScreen
   - Pending verification state display
   - Resend button with rate limit feedback
   - Loading and error states
   - Deep link handling for email click

4. Create PasswordRecoveryScreen
   - Email input form with validation
   - Form submission and loading state
   - Success message display
   - Error handling for rate limits

5. Create PasswordResetScreen
   - Token validation on load
   - Password input with strength indicator
   - Confirm password input
   - Form submission and validation
   - Token expiration handling

6. Update LoginScreen
   - Add "Forgot Password" button linking to PasswordRecoveryScreen
   - Display message about email verification requirement

7. Update registration flow
   - After successful register, show EmailVerificationScreen
   - Require verification before full account activation

8. Update navigation and routing
   - Add verification/recovery routes
   - Deep link handling for email tokens
   - Protected route updates

9. Widget tests
   - Test all form components
   - Test validation logic
   - Test error states

---

### Phase 3: Integration Testing & Deployment

**Duration**: 2-3 days  
**Dependencies**: Phase 1 & 2 complete  
**Deliverables**: Full E2E tests, deployment verification

**Tasks**:

1. Full integration tests (E2E)
   - Registration to email verification flow
   - Password recovery and reset flow
   - Session invalidation after password reset
   - Rate limiting enforcement

2. Performance testing
   - Token generation benchmarks
   - Email delivery timing
   - Rate limit query performance

3. Security testing
   - Manual token manipulation tests
   - Rate limit bypass attempts
   - User enumeration prevention verification
   - Timing attack resistance for token comparison

4. Docker deployment verification
   - Test via `docker-compose up`
   - Verify migrations run correctly
   - Test email service configuration

5. Documentation
   - Update README with email configuration steps
   - Document environment variables needed
   - Update TESTING_GUIDE with new test scenarios

6. Demo & sign-off
   - Full feature walkthrough
   - Verify acceptance criteria met

---

## Testing Strategy

### Unit Tests (Backend)

**TokenService Tests**:
```dart
test('generateToken returns 32-byte Base64URL token') { }
test('hashToken returns consistent SHA256 hash') { }
test('verifyTokenHash compares timing-safely') { }
test('isTokenExpired returns true for +24h old tokens') { }
```

**RateLimiterService Tests**:
```dart
test('trackResetAttempt increments attempt count') { }
test('getResetAttemptCount returns count in window') { }
test('isRateLimited returns true after 5 attempts') { }
test('isRateLimited returns false after window expiry') { }
```

**EmailService Tests**:
```dart
test('sendVerificationEmail formats and queues email') { }
test('retry logic exponentially backs off') { }
test('sendPasswordResetEmail includes correct token') { }
```

---

### Integration Tests (Backend)

**Verification Endpoint Tests**:
```dart
test('send-verification-email creates token and sends email') { }
test('verify-email validates token and updates user') { }
test('verify-email rejects expired token') { }
test('verify-email is idempotent (already verified)') { }
```

**Password Recovery Tests**:
```dart
test('send-password-reset-email enforces rate limit') { }
test('reset-password updates password and invalidates sessions') { }
test('reset-password rejects invalid token') { }
test('password reset email notification sent') { }
```

---

### Widget Tests (Frontend)

**EmailVerificationScreen**:
```dart
test('displays pending verification status') { }
test('resend button is disabled during request and countdown') { }
test('shows success on verification') { }
test('shows error on verification failure') { }
```

**PasswordRecoveryScreen**:
```dart
test('validates email format') { }
test('shows loading state during submission') { }
test('displays rate limit message on 429') { }
test('shows generic success message') { }
```

**PasswordResetScreen**:
```dart
test('validates password strength') { }
test('confirms passwords match') { }
test('shows token expiration warning') { }
test('displays success and navigates to login') { }
```

---

### Integration Tests (Frontend)

**Full Flows**:
```dart
test('registration → email verification → login') { }
test('login → password recovery → password reset → login with new password') { }
test('session invalidated after password reset') { }
test('deep link from email opens reset screen with token pre-filled') { }
```

---

### Acceptance Testing Scenarios

| Scenario | Steps | Expected Result |
|----------|-------|-----------------|
| User registers and verifies email | Register → receive email → click link → verify | Account fully active, can send messages |
| User forgets password | Click "Forgot Password" → enter email → receive link → click link → set new password → login | Login succeeds with new password |
| Rate limit enforcement | Request password reset 6 times in 1 hour | 6th attempt blocked with 429 error + retry-after header |
| Token expiration | Request password reset → wait 24+ hours → click link | Token invalid error, user must request new link |
| Verification token reuse | User registers → receives token → tries to verify again with same token | Success (idempotent) |
| Attacker tries wrong token | Receive password reset link → modify token → submit | Invalid token error |

---

## Security Implementation Details

### Token Security

**Generation**:
- 32 bytes of cryptographically secure random data
- Generated via `Random.secure()` in Dart
- Encoded as Base64URL without padding (URL-safe transmission)

**Storage**:
- Raw token: Never stored; only shared via email
- Hashed token: SHA256 hash stored in database
- Comparison: Timing-safe to prevent timing attacks

**Example Flow**:
```
Backend generates: 2KL9vX1pP5kY7mZ3bN8cQ0rS4tU6vW9xY2zAbCdEfGhI= (Base64URL)
Backend hashes: SHA256(token) = a3f...9z (stored in DB)
Email contains: https://app.messenger/verify?token=2KL...I=
User clicks link → Frontend sends token to backend
Backend hashes received token → compares with stored hash (timing-safe)
If match → user verified
If hash matches →token invalidated (set used_at timestamp)
```

---

### Rate Limiting

**Password Reset**:
- Limit: 5 attempts per email per hour
- Enforcement: Query `password_reset_attempts` table
- Window: Last 60 minutes from now
- Response: 429 Too Many Requests with Retry-After header
- Tracking: Email-based (not IP) to allow legitimate multi-device users

**Example Flow**:
```
User requests password reset:
  1. Query: SELECT COUNT(*) FROM password_reset_attempts 
             WHERE email='alice@example.com' AND attempted_at > NOW()-'1 hour'
  2. If count >= 5 → return 429 Too Many Requests
  3. If count < 5 → INSERT new attempt, continue
  4. After 1 hour → old attempts automatically ignored by query (no manual cleanup needed per request)
```

---

### Account Status Enforcement

**Email Verification Requirement**:
- New accounts: `email_verified = false`
- Protected operations: Check `email_verified` on every request
- Not verified: Return 403 Forbidden with message "Please verify your email before accessing this feature"
- Endpoints that require verification:
  - Send message (POST /chats/{chat_id}/messages)
  - Join chat (POST /chats/{chat_id}/join)
  - Create chat (POST /chats)
  - Send invite (POST /invites)

**Session Invalidation**:
- Password reset: All existing JWT tokens for user invalidated
- Mechanism: Backend maintains `revoked_tokens` set or token versioning
- Check: On each protected request, verify token not in revoked set
- Cleanup: Revoked tokens periodically deleted (older than expiration window)

---

### User Enumeration Prevention

**Email Verification Request**:
- Response identical whether email registered or not
- Generic message: "If your email is registered, you will receive a verification link"
- Status code: Always 200 OK

**Password Recovery Request**:
- Response identical whether email exists or not
- Generic message: "If an account exists with this email, a password reset link will be sent"
- Status code: Always 200 OK
- Note: Rate limiting is email-based (doesn't leak whether email exists, but allows enumeration via attempts timing)

---

### Email Service Security

**SendGrid Integration**:
- API Key: Stored in `SENDGRID_API_KEY` environment variable
- Storage: `.env` file (git-ignored)
- Transport: HTTPS/TLS only
- No credentials in logs: Error messages generic to user

**SMTP Fallback** (if used):
- Credentials: Environment variables (SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD)
- Encryption: TLS/STARTTLS required
- No plaintext emails

**Error Handling**:
- Transient failure (network error): Retry 3 times with exponential backoff
- Permanent failure (invalid email): Log and return generic error to user
- Service down: Inform user "Unable to send email at this time" (retry enabled)

---

### Password Reset Security

**Password Hashing**:
- Algorithm: bcrypt with cost factor 10
- Minimum time: ~100ms per hash (prevents brute force even with leaked hash)
- Reuse: Same hashing as Spec 003 login

**Validation**:
- New password must meet strength requirements (8+ chars, lowercase, uppercase, digit, special)
- Cannot reuse last 3 passwords (optional enhancement)
- Confirmation required (user must type password twice)

**Session Invalidation**:
- Mechanism: Server maintains token version per user
- On password change: Increment user's token version
- On request: Verify JWT token version matches current version
- Effect: All old JWT tokens become invalid immediately

---

## Success Metrics & Acceptance Criteria

### Implementation Completeness

- ✅ All 4 backend endpoints implemented and tested
- ✅ All 3 database migrations created and applied
- ✅ All 3 new services implemented (TokenService, EmailService, RateLimiterService)
- ✅ Frontend screens created (EmailVerificationScreen, PasswordRecoveryScreen, PasswordResetScreen)
- ✅ Deep linking enabled for email token handling
- ✅ Rate limiting enforced (5 password reset attempts per email per hour)
- ✅ All tokens expire after 24 hours
- ✅ Account status (email_verified) enforced on protected operations

### Functional Requirements Met

| Requirement | Verification |
|-------------|--------------|
| Email verification link sent after registration | Test: register new user → check inbox for verification email |
| Email verification link valid for 24 hours | Test: request verification link → wait 24h → verify link invalid |
| User cannot use app until email verified | Test: register → try to send message without verification → 403 error |
| Password recovery email sent on request | Test: click "Forgot Password" → enter email → verify email received |
| Password reset link valid for 24 hours | Test: request reset link → wait 24h → verify link invalid |
| Password reset rate-limited to 5 per hour | Test: request password reset 6 times in 1 hour → 6th request blocked |
| Existing sessions invalidated on password change | Test: login as User A → password reset on different device → original session fails on next API call |
| Resend verification email works (idempotent) | Test: register → request verification email twice → receive 2 emails with different tokens, both work |

### Performance Metrics

- Token generation: < 100ms
- Token validation: < 50ms
- Email delivery: < 5 seconds
- Rate limit check: < 50ms
- Password update: < 1 second

### Security Validation

- ✅ Tokens validated via timing-safe comparison (prevents timing attacks)
- ✅ Passwords never logged or displayed
- ✅ Token hashes stored in database (token exposure won't compromise accounts)
- ✅ Email service credentials protected (env variables, not hardcoded)
- ✅ User enumeration prevented (identical responses for existing/non-existing emails)
- ✅ Rate limiting prevents brute force attacks
- ✅ Session invalidation prevents compromise recovery

### Deployment & Infrastructure

- ✅ Migrations automatically run on Docker startup
- ✅ Email service configured via environment variables
- ✅ Deep linking configured for password reset flow
- ✅ Full flow testable via `docker-compose up`

---

## Dependencies & Assumptions

### Dependencies on Previous Specs

- **Spec 001**: Docker Compose infrastructure, health endpoints
- **Spec 002**: User table, database migrations pattern
- **Spec 003**: Authentication endpoints, JWT token generation, password hashing

### External Dependencies

- **SendGrid**: Email delivery service (or SMTP fallback)
- **Dart cryptography package**: Token hashing and validation
- **PostgreSQL**: Token and attempt tracking tables

### Assumptions

- Backend database accessible and initialized (from Spec 002)
- Authentication middleware functional (from Spec 003)
- Email service credentials provided via environment variables
- Flutter app supports deep linking (configured in AndroidManifest.xml and Info.plist)
- Users have valid email addresses (basic format validation sufficient)
- Network available for email delivery (retry logic handles transient failures)

---

## Risk Mitigation

### Risk: Email Delivery Failures

**Mitigation**:
- SendGrid provides 99.9% uptime SLA
- Retry logic with exponential backoff
- Fallback SMTP provider ready if SendGrid fails
- User informed of failure; can retry sending email

### Risk: Token Expiration Misalignment

**Mitigation**:
- Database stores explicit `expires_at` timestamp
- Server-side expiration check authoritative
- Client-side countdown informational only
- Extended window before hard expiration (warn user at 1 hour remaining)

### Risk: Rate Limit Bypass

**Mitigation**:
- Rate limiting at application layer (not infrastructure)
- Database-backed tracking prevents spoofing
- Per-email enforcement prevents proxy tricks

### Risk: Timing Attacks on Token Comparison

**Mitigation**:
- Timing-safe comparison function used
- Token hash comparison (not raw token)
- No early exits in comparison logic

---

## Open Questions & Future Enhancements

### Current Implementation Scope

- **Single-device sessions**: Sessions invalidated globally on password reset
- **Email preference**: Rate limits non-configurable (5 per hour)
- **No backup codes**: No two-factor authentication (future enhancement)
- **No account recovery questions**: Email-only recovery

### Potential Future Enhancements

1. **Two-Factor Authentication (2FA)**
   - SMS OTP in addition to email
   - Authenticator app support
   - Backup codes for account recovery

2. **Enhanced Rate Limiting**
   - Different limits for different endpoints
   - Graduated penalties (cooldown period increases)
   - Admin override capability

3. **Account Recovery Options**
   - Security questions
   - Recovery email address
   - Trusted device list

4. **Email Preference Center**
   - User controls which emails they receive
   - Unsubscribe from password change notifications
   - Digest email options

5. **Advanced Security**
   - IP-based anomaly detection
   - Suspicious login alerts
   - Device registration and management

---

## Notes for Implementation Team

- **Password Reset Email**: Notify user of suspicious activity; provide "I didn't request this" option
- **Rate Limit UX**: Show countdown timer to help users understand when limit resets
- **Deep Link Testing**: Test on both Android and iOS; ensure app opens to correct screen
- **Database Cleanup**: Set up periodic job to delete expired tokens (once per day)
- **Monitoring**: Log all password reset attempts and email failures for security audit trail
- **Localization**: Email templates should support multiple languages (future enhancement)
- **Error Recovery**: Provide clear "Contact Support" option if user unable to access account

---

## Checklist for Sign-off

- [ ] All backend endpoints tested and working
- [ ] Rate limiting enforcement verified
- [ ] Token expiration working correctly
- [ ] Email delivery tested (real SendGrid account)
- [ ] Frontend screens implemented and tested
- [ ] Deep linking functional for email links
- [ ] Session invalidation on password change verified
- [ ] Database migrations run successfully
- [ ] Docker deployment tested end-to-end
- [ ] Documentation updated
- [ ] All unit tests passing (>90% coverage)
- [ ] All integration tests passing
- [ ] E2E tests passing (registration → verification → login → password reset)
- [ ] Security review completed
- [ ] Performance metrics within targets
- [ ] Team sign-off obtained
