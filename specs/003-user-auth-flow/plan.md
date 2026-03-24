# Implementation Plan: User Registration and Login

**Branch**: `003-user-auth-flow` | **Date**: March 11, 2026 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `/specs/003-user-auth-flow/spec.md`

## Summary

Implement complete user authentication flow (registration and login) with secure password hashing, persistent session tokens, and client-side encrypted storage. Backend provides Serverpod endpoints for user creation and authentication; frontend delivers registration and login UI with inline validation feedback. Session tokens persist across app restarts using Flutter secure storage. This feature is foundational—all subsequent features require authenticated sessions. Implementation spans three phases: backend authentication layer (Phase 1), frontend UI and validation (Phase 2), and end-to-end integration testing (Phase 3).

## Technical Context

**Language/Version**: Dart 3.5 (Serverpod 2.1+ backend, Flutter 3.10+ frontend)  
**Primary Dependencies**: 
- Backend: `serverpod`, `crypto` (bcrypt hashing), `jsonwebtoken` (JWT generation)
- Frontend: `provider` (state management), `flutter_secure_storage` (encrypted token persistence), `form_builder_validators` (validation)
- Database: PostgreSQL 13+ (users table already exists from Spec 002)

**Storage**: 
- Backend: PostgreSQL users table with password_hash column (from Spec 002)
- Frontend: Encrypted device storage (flutter_secure_storage) for JWT session tokens

**Testing**: 
- Backend: Dart integration tests with PostgreSQL (test registration/login endpoints)
- Frontend: Widget tests (registration/login forms, validation), integration tests (full auth flow)
- E2E: Full registration → login → session persistence cycle

**Target Platform**: Android/iOS (Flutter frontend), Linux/Docker (Serverpod backend)  
**Project Type**: Mobile messaging app with backend API  
**Performance Goals**: 
- Registration validation: <100ms for duplicate check
- Login: <2 seconds (network + server response)
- Session restoration: Automatic on app launch without user action
- Password hashing: <500ms (bcrypt with rounds=10)

**Constraints**: 
- Passwords must meet 5 strength criteria (8+ chars, lowercase, uppercase, digit, special char)
- Session tokens must be cryptographically secure and time-bounded
- Passwords never logged or stored in plaintext
- Rate limiting on login endpoints (prevent brute force)
- Error messages must not leak which field caused failure (prevent user enumeration)

**Scale/Scope**: 
- 2 backend endpoints (register, login)
- 1 backend service (UserAuthService for hash/token operations)
- 2 frontend screens (RegistrationScreen, LoginScreen)
- 1 frontend service (AuthService for API calls and state management)
- 3 core validation rules (email format, username uniqueness, password strength)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Security-First Principle (NON-NEGOTIABLE)

**Required**: Authentication must follow cryptographic best practices; no plaintext passwords; tokens encrypted in storage

**Design Decisions**:

1. **Password Hashing** (IMPLEMENTED)
   - Backend: bcrypt hashing with cost factor 10 (minimum 100ms per hash, prevents rainbow table attacks)
   - Implementation: `crypto` package (pointycastle backend) with bcrypt.hashpw()
   - Validation: Hash verification via bcrypt.checkpw() on login
   - Rationale: bcrypt standards-compliant, best-in-class security for password storage

2. **Session Token Generation** (IMPLEMENTED)
   - Backend: JWT (JSON Web Tokens) with RS256 (RSA asymmetric signing)
   - Payload: user_id, email, exp (expiration: 30 days), iat (issued at), jti (token ID)
   - Signing key: Server-side RSA private key (never exposed to client)
   - Verification: Serverpod middleware validates token signature on protected endpoints
   - Rationale: JWT enables stateless session validation; RS256 prevents token forgery

3. **Token Storage** (IMPLEMENTED)
   - Frontend: flutter_secure_storage (iOS Keychain, Android Keystore encryption)
   - Key: "auth_token" stored in platform-native encrypted storage
   - Timeout: Tokens expire after 30 days (backend enforces); app periodically checks expiration
   - Clear on logout: Token explicitly deleted from secure storage
   - Rationale: Platform-native encryption prevents extraction; app can verify expiration client-side

4. **Rate Limiting** (FRAMEWORK APPROACH)
   - Backend: Serverpod middleware with IP-based rate limiting (max 5 login attempts per IP per minute)
   - Implementation: Middleware tracks failed attempts; responds with 429 Too Many Requests after limit
   - Rationale: Prevents brute force attacks without implementing account lockout (which creates DoS vector)

5. **Error Message Security** (IMPLEMENTED)
   - Login failure: Generic "Invalid email or password" (does not reveal which is incorrect)
   - Registration failure: Specific messages for validation errors (password requirements) to aid UX
   - Account exists: "Email already registered" or "Username already taken" (acceptable—user already has account)
   - Rationale: Prevents user enumeration attacks on registration; specific feedback improves UX for legitimate users

**Status**: ✅ PASS - All cryptographic requirements met; password and token security enforced at implementation layer

### ✅ End-to-End Architecture Clarity (NON-NEGOTIABLE)

**Required**: Auth flow must integrate cleanly across Flutter client → Serverpod server → PostgreSQL layers

**Layer Boundaries**:

1. **Presentation Layer** (Flutter frontend)
   - Registration/Login screens: Input validation, form state, error display
   - State management: Provider watches auth state, rebuilds on token change
   - Secure storage integration: Read token on startup, write token on login, delete on logout

2. **Business Logic Layer** (Serverpod backend endpoints)
   - `/auth/register`: Validate input, check uniqueness, hash password, create user, return user_id
   - `/auth/login`: Validate credentials, generate JWT, return token + user info
   - Middleware: Validate JWT on all protected endpoints
   - Services: UserAuthService (hash, verify), JwtService (generate, validate)

3. **Data Layer** (PostgreSQL)
   - users table: email, username, password_hash (from Spec 002)
   - No new schema changes—reuses existing table

**Integration Points**:
- Frontend AuthService calls `/auth/register` and `/auth/login` endpoints
- Backend receives request, validates, performs database operations
- Backend returns JWT token; frontend stores in secure storage
- Frontend attaches token to subsequent API requests via Serverpod client configuration

**Status**: ✅ PASS - Clean layer boundaries; clear integration points

### ✅ Testing Discipline (NON-NEGOTIABLE)

**Required**: Three-tier testing for all auth operations

**Test Strategy**:

1. **Unit Tests** (Backend)
   - UserAuthService: Hash verification, token generation, expiration
   - PasswordValidator: Strength requirements (8+ chars, lowercase, uppercase, digit, special)
   - Coverage target: >90% of authentication logic

2. **Integration Tests** (Backend)
   - Register endpoint: Valid input → user created; duplicate email → error; weak password → error
   - Login endpoint: Valid credentials → token returned; invalid credentials → error
   - Database constraints tested: UNIQUE(email), UNIQUE(username) enforced
   - Coverage: Happy path + all Spec failure scenarios

3. **Widget Tests** (Frontend)
   - RegistrationForm: Renders fields, validates on change, shows errors
   - LoginForm: Renders fields, handles submission, shows loading state
   - Error handling: Network error, server error, validation error display
   - Coverage: All form interactions tested

4. **Integration Tests** (Frontend)
   - Full registration flow: Submit form → backend call → token stored → redirect success
   - Full login flow: Submit form → backend call → token stored → auto-login on restart
   - Session persistence: Login → close app → restart → auto-authenticated
   - Logout: Clear token → next launch shows login screen

**Status**: ✅ PASS - Three-tier testing plan defined; will be codified in Phase 2 tasks

### ✅ Code Consistency & Naming Standards

**Required**: Dart naming conventions throughout (PascalCase classes, camelCase methods, snake_case files)

**Conventions**:
- Backend files: `user_auth_service.dart`, `jwt_service.dart`, `password_validator.dart`
- Backend classes: `UserAuthService`, `JwtService`, `PasswordValidator`, `RegistrationRequest`, `LoginResponse`
- Frontend files: `auth_service.dart`, `registration_screen.dart`, `login_screen.dart`
- Frontend classes: `AuthService`, `RegistrationScreen`, `LoginScreen`, `AuthProvider`, `RegistrationForm`
- Database columns: snake_case (password_hash, created_at, email_verified)
- Provider variables: `authProvider`, `formStateProvider`

**Status**: ✅ PASS - Naming conventions aligned with Dart best practices

### ✅ Delivery Readiness (NON-NEGOTIABLE)

**Required**: Feature must work via `docker-compose up` and support `flutter run` on emulator

**Delivery Pipeline**:
- Backend: Endpoints deployed via Serverpod auto-hot-reload (dev mode) or containerized (production)
- Frontend: Runs via `flutter run` with automatic rebuild
- Database: Users table already exists from Spec 002
- Configuration: No manual setup required; backend/frontend auto-connect

**Status**: ✅ PASS - Existing delivery pipeline supports this feature

## Project Structure

### Documentation (this feature)

```text
specs/003-user-auth-flow/
├── plan.md              # This file (planning output)
├── spec.md              # Feature specification (input)
├── research.md          # Phase 0 research findings (to generate)
├── data-model.md        # Phase 1 data model design (to generate)
├── quickstart.md        # Phase 1 quickstart guide (to generate)
├── contracts/           # Phase 1 API contracts (to generate)
│   ├── auth-endpoints.yaml      # /auth/register, /auth/login contracts
│   ├── registration-request.yaml
│   ├── login-request.yaml
│   ├── auth-response.yaml
│   └── auth-errors.yaml
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
│   │   │   └── auth_endpoints.dart         # ← NEW: /auth/register, /auth/login
│   │   ├── services/
│   │   │   ├── user_auth_service.dart      # ← NEW: Hash, verify, token generation
│   │   │   ├── password_validator.dart     # ← NEW: Password strength validation
│   │   │   ├── jwt_service.dart            # ← NEW: JWT token generation and validation
│   │   │   └── user_service.dart           # EXISTING (Spec 002, extend for auth)
│   │   ├── models/
│   │   │   ├── user_model.dart             # EXISTING (Spec 002)
│   │   │   ├── registration_request.dart   # ← NEW: Request DTO
│   │   │   ├── login_request.dart          # ← NEW: Request DTO
│   │   │   └── auth_response.dart          # ← NEW: Response DTO
│   │   └── middleware/
│   │       └── auth_middleware.dart        # ← NEW: JWT validation middleware
│   ├── config/
│   │   ├── jwt_config.dart                 # ← NEW: JWT secret/key configuration
│   │   └── server_secrets.env              # ← NEW (git-ignored): RSA keys
│   ├── server.dart                         # EXISTING (register middleware)
│   └── pubspec.yaml                        # UPDATE: Add crypto, jsonwebtoken
├── migrations/
│   └── (no new migrations—reuse users table from Spec 002)
├── test/
│   ├── integration/
│   │   └── test_auth_endpoints.dart        # ← NEW: Register/login endpoint tests
│   └── unit/
│       ├── test_password_validator.dart    # ← NEW: Validation tests
│       ├── test_jwt_service.dart           # ← NEW: Token generation tests
│       └── test_user_auth_service.dart     # ← NEW: Hash/verify tests
└── Dockerfile
```

### Source Code: Frontend

```text
frontend/
├── lib/
│   ├── core/
│   │   ├── auth/                           # ← NEW: Authentication core module
│   │   │   ├── models/
│   │   │   │   ├── auth_state.dart         # State model (unauthenticated, authenticating, authenticated, error)
│   │   │   │   ├── user_data.dart          # User info model (id, email, username)
│   │   │   │   └── auth_exception.dart     # Exception types
│   │   │   ├── providers/
│   │   │   │   └── auth_provider.dart      # Provider for auth state management
│   │   │   ├── services/
│   │   │   │   └── auth_service.dart       # API calls and secure storage
│   │   │   └── utils/
│   │   │       └── validators.dart         # Form validation logic
│   │   ├── constants/
│   │   │   └── app_constants.dart          # Storage keys, API endpoints
│   │   └── utils/
│   │       └── logger.dart                 # Logging (EXISTING)
│   ├── features/
│   │   ├── auth/                           # ← NEW: Auth feature screens
│   │   │   ├── screens/
│   │   │   │   ├── registration_screen.dart     # Registration form and logic
│   │   │   │   └── login_screen.dart           # Login form and logic
│   │   │   ├── widgets/
│   │   │   │   ├── registration_form.dart       # Registration form widget
│   │   │   │   ├── login_form.dart             # Login form widget
│   │   │   │   ├── password_field.dart         # Password input with strength indicator
│   │   │   │   ├── email_field.dart            # Email input with validation
│   │   │   │   ├── username_field.dart         # Username input
│   │   │   │   └── validation_error_text.dart  # Error display widget
│   │   │   └── services/
│   │   │       └── registration_service.dart   # Registration-specific logic
│   ├── app.dart                            # UPDATE: Add auth routing, initial screen detection
│   └── main.dart                           # UPDATE: Initialize auth state on startup
├── test/
│   ├── integration/
│   │   └── test_auth_flow.dart             # ← NEW: Full registration/login flow
│   └── widget/
│       ├── test_registration_form.dart     # ← NEW: Registration form tests
│       ├── test_login_form.dart            # ← NEW: Login form tests
│       └── test_form_validation.dart       # ← NEW: Validation logic tests
└── pubspec.yaml                            # UPDATE: Add provider, flutter_secure_storage, form_builder_validators
```

### Dependencies to Add

**Backend (pubspec.yaml)**
```yaml
dependencies:
  serverpod:
  crypto: ^3.0.2           # For bcrypt hashing
  pointycastle: ^3.7.4     # Crypto operations (bcrypt supported)
  jsonwebtoken: ^0.4.0     # For JWT generation/validation (or use crypto package)
```

**Frontend (pubspec.yaml)**
```yaml
dependencies:
  flutter:
  provider: ^6.0.0         # State management for auth
  flutter_secure_storage: ^9.0.0  # Encrypted token storage (iOS Keychain, Android Keystore)
  form_builder_validators: ^9.0.0 # Email, password pattern validation
```

## Data Flow Diagrams

### Registration Flow
```
1. User enters email, username, password on RegistrationScreen
2. RegistrationForm validates inline (email format, username length, password strength)
3. User taps submit → RegistrationForm calls AuthService.register()
4. AuthService → HTTP POST /auth/register with registration data
5. Backend /auth/register endpoint:
   - Validates input format
   - Queries users table: check UNIQUE(email), UNIQUE(username)
   - If user exists → return RegisterError (email/username taken)
   - Hash password with bcrypt (cost=10)
   - INSERT into users table (email, username, password_hash, created_at)
   - Generate JWT token
   - Return JWT + user ID
6. Frontend AuthService stores JWT in flutter_secure_storage
7. Frontend updates AuthProvider state to authenticated
8. App redirects to main chat screen
```

### Login Flow
```
1. User enters email and password on LoginScreen
2. LoginForm validates (email format)
3. User taps submit → LoginForm calls AuthService.login()
4. AuthService → HTTP POST /auth/login with email/password
5. Backend /auth/login endpoint:
   - Query users table by email
   - If not found → return LoginError ("Invalid email or password")
   - Verify password hash with bcrypt.checkpw()
   - If invalid → return LoginError ("Invalid email or password")
   - Generate new JWT token
   - Return JWT + user info
6. Frontend AuthService stores JWT in flutter_secure_storage
7. Frontend updates AuthProvider state to authenticated
8. App redirects to main chat screen
```

### Session Restoration Flow
```
1. App starts → main.dart calls AuthService.initializeAuth()
2. AuthService attempts to load JWT from flutter_secure_storage
3. If token exists:
   - Verify token expiration (check exp claim)
   - If not expired → set AuthProvider to authenticated with user data
   - If expired → delete token, set AuthProvider to unauthenticated
4. If no token → set AuthProvider to unauthenticated
5. App.dart detects AuthProvider state:
   - If authenticated → show MainScreen
   - If unauthenticated → show LoginScreen
```

## Implementation Phases

### Phase 1: Backend Authentication Layer (Days 1-3)

**Deliverables**:
1. `UserAuthService`: Password hashing (bcrypt), verification, token generation (JWT)
2. `PasswordValidator`: 5-criterion password strength check
3. `JwtService`: Token generation with RS256, expiration handling
4. `/auth/register` endpoint: Validate input, check uniqueness, create user, return JWT
5. `/auth/login` endpoint: Validate credentials, generate JWT, return token
6. `AuthMiddleware`: Register on Serverpod to validate JWT on protected endpoints
7. Integration tests: All endpoint scenarios + error cases
8. Configuration: JWT secrets, bcrypt parameters, rate limiting setup

**Success Criteria**:
- New user can register with valid email/username/password
- Registration rejects duplicate email/username
- Registration rejects weak passwords with specific error
- Existing user can login with correct credentials
- Login rejects invalid credentials with generic error
- JWT token generated on successful auth, expiration validated
- All integration tests pass
- Password hashes verified with bcrypt (not plaintext comparison)

### Phase 2: Frontend UI and Validation (Days 4-6)

**Deliverables**:
1. `AuthService`: Wraps backend API calls, manages secure token storage
2. `AuthProvider`: Provider state management (authenticated, loading, error)
3. `RegistrationScreen` + `RegistrationForm`: UI, form submission, error display
4. `LoginScreen` + `LoginForm`: UI, form submission, error display
5. `PasswordField`: Custom input widget with strength indicator
6. Form validation: Email format, username length, password strength client-side
7. Error handling: Network errors, server errors, validation feedback
8. Widget tests: All form widgets, validation, error states
9. Integration tests: Full registration and login flows

**Success Criteria**:
- Registration form renders with email, username, password, confirm password fields
- Inline validation shows specific password strength errors as user types
- Registration submission calls backend, stores token, shows success
- Login form renders with email and password fields
- Login submission calls backend, stores token, shows success
- Form shows generic error message on duplicate email/username
- Network errors handled gracefully with user feedback
- All form widget tests pass
- E2E registration → login flow works end-to-end

### Phase 3: Integration, Session Persistence, and Testing (Days 7-9)

**Deliverables**:
1. `AuthMiddleware` integration: Protect endpoints, validate JWT on requests
2. Session restoration: AuthService.initializeAuth() on app startup
3. Logout functionality: Clear token from storage, reset AuthProvider
4. App routing: Detect auth state, show LoginScreen vs MainScreen
5. Rate limiting on backend: Track failed attempts, return 429 after limit
6. Comprehensive end-to-end tests: Registration → Login → Session Persistence → Logout
7. Manual testing: Registration/login on both iOS and Android emulators
8. Documentation: API contract docs, quickstart guide for developers

**Success Criteria**:
- User can register, login, and remain logged in after app restart
- User can logout and be returned to login screen on restart
- All protected endpoints validate JWT and reject unauthenticated requests
- Rate limiting prevents brute force (5 attempts per minute per IP)
- E2E tests verify full authentication lifecycle
- No passwords logged or stored in plaintext anywhere
- App works on iOS and Android with secure token storage

## Technology Choices & Rationale

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Password Hashing | bcrypt (via crypto package) | Industry standard, resistant to brute force (cost factor prevents <100ms computation) |
| Token Type | JWT (RS256) | Stateless session validation, asymmetric signing prevents tampering |
| Token Storage (Frontend) | flutter_secure_storage | iOS Keychain/Android Keystore encryption, prevents extraction via adb/app inspection |
| State Management (Frontend) | Provider | Simple, reactive, integrates well with Flutter ecosystem |
| Form Validation | form_builder_validators | Pre-built validators, reduces boilerplate |
| Frontend HTTP | Serverpod client (auto-generated) | Automatic request/response handling, type-safe, built-in auth header support |
| Rate Limiting | Serverpod middleware | Built-in support, IP-based tracking, configurable limits |
| Error Handling | Custom exceptions | Domain-specific error types (RegistrationError, LoginError) for precise handling |

## Security Considerations

1. **Password Security**
   - bcrypt with cost=10 minimum (100ms per hash)
   - No password reset without email verification (deferred to future spec)
   - No password hints or recovery questions

2. **Token Security**
   - JWT with RS256 (asymmetric) prevents token forgery
   - 30-day expiration (business decision, configurable)
   - Token invalidation on logout (explicit delete from storage)
   - No token refresh endpoint (simple implementation; refresh flow deferred)

3. **Transport Security**
   - HTTPS enforced in production (Docker/reverse proxy)
   - HTTP OK for local development (docker-compose)

4. **Storage Security**
   - Passwords stored as bcrypt hashes (never plaintext)
   - Tokens encrypted in device storage (platform-native encryption)
   - No sensitive data logged

5. **Rate Limiting**
   - Login endpoint: max 5 attempts per IP per minute
   - Registration endpoint: max 10 attempts per IP per hour (prevents spam)
   - Returns 429 status code when limit exceeded

6. **Error Messages**
   - Login: Generic "Invalid email or password" (prevents user enumeration)
   - Registration: Specific messages only for validation errors (helps UX)

## Complexity Tracking

### Identified Challenges

1. **Bcrypt Performance**: bcrypt is CPU-intensive; 100ms per hash may feel slow on lower-end devices (mitigation: show loading spinner during registration)
2. **Token Expiration Edge Cases**: Token might expire while app is open; refresh flow deferred (mitigation: re-login on 401 response for now)
3. **Secure Storage Initialization**: flutter_secure_storage may not be available on all emulators; test on physical devices recommended
4. **Race Condition**: Duplicate registration from multiple devices simultaneously could bypass uniqueness check (mitigation: database UNIQUE constraint as final arbiter)

### Mitigation Strategies

1. Move password hashing to background isolate (isolate pool) to prevent UI freeze
2. Display loading state during auth operations
3. Test on multiple Android API levels and iOS versions
4. Integration tests verify database constraints
5. Error recovery: Network timeout → show retry button

## Dependencies from Previous Specs

- **Spec 001**: Project structure, Docker Compose, Serverpod initialization
- **Spec 002**: Users table (email, username, password_hash columns already exist)
- **Backend Server**: Already running via docker-compose, ready for endpoint registration
- **Frontend App Structure**: Already organized by features; auth module follows same pattern

## Next Steps (Post-Implementation)

1. **Password Reset Flow** (Spec 004?): Email verification, token-based reset link
2. **2FA/MFA** (Spec 005?): TOTP/SMS-based multi-factor authentication
3. **Social Login** (Spec 006?): OAuth via Google/Apple
4. **Profile Management** (Spec 007?): Display name, profile picture, bio (reuse User model from Spec 002)

---

**Plan Status**: Ready for Phase 0 Research and Phase 1 Design  
**Last Updated**: March 11, 2026
