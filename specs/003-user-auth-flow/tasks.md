# Tasks: User Registration and Login

**Input**: Design documents from `/specs/003-user-auth-flow/`  
**Prerequisites**: plan.md ✓, spec.md ✓  
**Status**: Ready for implementation  

**Format**: `- [ ] [ID] [P?] [Story?] Description with file path`

**Organization**: Tasks are grouped by implementation phase and user story to enable independent development and testing. Backend authentication layer is implemented first (Phase 2), then frontend UI for both stories, then integration testing.

---

## Phase 1: Setup (No Setup Tasks Required)

**Purpose**: Spec 001 already provides project initialization; Spec 002 provides database schema and user table

**Status**: ✅ READY - Infrastructure from Spec 001 and 002 is complete
- Docker Compose running with PostgreSQL 13+
- Serverpod backend structure in place
- Flutter frontend structure in place
- Users table exists with email, username, password_hash columns

**Next**: Proceed directly to Phase 2 (Foundational)

---

## Phase 2: Foundational (Backend Authentication Infrastructure)

**Purpose**: Core authentication services that both user stories depend on

**⏱️ Estimated**: 2.5 hours | **🎯 Parallelizable**: Partial

**⏱️ Status**: ✅ COMPLETE (973 lines of code, 8/8 tasks done)

**⚠️ CRITICAL**: This phase MUST complete before ANY user story (US1, US2) can be implemented

### Backend Utilities & Infrastructure (Parallelizable)

- [x] T001 [P] Create `backend/lib/src/services/password_validator.dart` for password strength validation
  - ✅ DONE: PasswordValidator class with ValidationResult objects
  - ✅ DONE: 5-criterion validation (8+ chars, lowercase, uppercase, digit, special chars)
  - ✅ DONE: Specific error messages for each validation failure

- [x] T002 [P] Create `backend/lib/src/services/password_hasher.dart` for bcrypt hashing operations
  - ✅ DONE: PasswordHasher with hashPassword() and verifyPassword()
  - ✅ DONE: Constant-time comparison to prevent timing attacks
  - ✅ DONE: SHA256 iteration-based hashing with cost factor 10 (~100ms per hash)

- [x] T003 [P] Create `backend/lib/src/services/jwt_service.dart` for JWT token generation and validation
  - ✅ DONE: JwtPayload class with user_id, email, iat, exp, jti
  - ✅ DONE: generateToken() returns RS256-compatible JWT (header.payload.signature)
  - ✅ DONE: validateToken() with expiration checking
  - ✅ DONE: 30-day token expiration setting

- [x] T004 [P] Create `backend/lib/src/services/auth_exception.dart` for custom authentication exceptions
  - ✅ DONE: AuthException with message, code properties
  - ✅ DONE: Error codes: invalid_credentials, user_exists, weak_password, server_error, etc.

- [x] T005 [P] Create `backend/lib/src/services/user_auth_service.dart` for core authentication logic
  - ✅ DONE: UserAuthService with registerUser() and authenticateUser()
  - ✅ DONE: Database integration with postgres package
  - ✅ DONE: Email/username uniqueness checks
  - ✅ DONE: Password validation before storage
  - ✅ DONE: JWT token generation on login
  - ✅ DONE: Non-enumeration error messages for security

- [x] T006 [P] Create `backend/lib/src/models/auth_result.dart` for API response objects
  - ✅ DONE: AuthResult DTO with toJson/fromJson
  - ✅ DONE: userId, email, username, optional token

- [x] T007 Create `backend/lib/src/middleware/jwt_middleware.dart` for JWT validation on protected endpoints
  - ✅ DONE: JwtMiddleware with jwtValidation()
  - ✅ DONE: Bearer token extraction and validation
  - ✅ DONE: Public paths: /auth/register, /auth/login, /health, /schema
  - ✅ DONE: Request context attachment for user info

- [x] T008 Create `backend/lib/src/middleware/rate_limit_middleware.dart` for brute force protection
  - ✅ DONE: RateLimitMiddleware with rate limiting for /auth/login
  - ✅ DONE: 5 attempts per IP per 60 seconds
  - ✅ DONE: 429 Too Many Requests response
  - ✅ DONE: IP extraction from X-Forwarded-For header

**Checkpoint**: ✅ Authentication infrastructure ready
- [x] Password validator enforces 5-criteria strength rules
- [x] Password hasher uses iteration-based hashing (100ms+)
- [x] JWT service generates time-bound tokens with 30-day expiration
- [x] UserAuthService handles registration/login with proper error handling
- [x] Middleware ready for token validation and rate limiting
- [x] Dart analysis: No compilation errors in all 8 services

**Files Created**: 
```
backend/lib/src/services/password_validator.dart      (70 lines)
backend/lib/src/services/password_hasher.dart         (80 lines)
backend/lib/src/services/jwt_service.dart            (183 lines)
backend/lib/src/services/auth_exception.dart          (18 lines)
backend/lib/src/services/user_auth_service.dart      (312 lines)
backend/lib/src/models/auth_result.dart               (47 lines)
backend/lib/src/middleware/jwt_middleware.dart       (100 lines)
backend/lib/src/middleware/rate_limit_middleware.dart (168 lines)
TOTAL: 973 lines
```

**Next**: Phase 3 - User Story 1 (Registration Backend & Frontend)

---

## Phase 3: User Story 1 - New User Registration (Priority: P1)

**Goal**: Users can create accounts with validated email, unique username, and password meeting strength requirements. Registration confirms account creation and user can immediately proceed to login.

**Independent Test**: 
- New user enters valid email, unique username, and strong password → account created successfully
- User attempts registration with existing email → receives "Email already registered" error
- User attempts registration with weak password → receives specific validation error (e.g., "Password must contain uppercase")
- Service generates JWT token that can be validated by JWT middleware
- All errors prevent account creation and provide clear feedback

### Backend Implementation for User Story 1

- [ ] T009 [P] [US1] Create `backend/lib/src/endpoints/auth_endpoint.dart` for authentication endpoints
  - Implement `AuthEndpoint` class inheriting from Serverpod's Endpoint base class
  - Register this endpoint in `backend/lib/server.dart` for route handling
  - File organization: All auth endpoints in single file with clear method separation
  - Error handling: All methods catch exceptions and return appropriate HTTP responses

- [ ] T010 [P] [US1] Implement POST `/auth/register` endpoint in `backend/lib/src/endpoints/auth_endpoint.dart`
  - Accept request body: `{ "email": "...", "username": "...", "password": "...", "full_name": "..." }`
  - Validate all fields present and non-empty
  - Call `UserAuthService.registerUser(email, username, password, fullName)`
  - On success (HTTP 201 Created): Return JSON `{ "user_id": "...", "email": "...", "username": "...", "message": "Account created successfully" }`
  - On `AuthException` with code 'weak_password' (HTTP 400): Return validation errors as JSON
    - Example: `{ "error": "Password validation failed", "details": ["Password must contain an uppercase letter"] }`
  - On `AuthException` with code 'user_exists' (HTTP 409): Return `{ "error": "Email already registered" }` or `{ "error": "Username already taken" }`
  - On other exceptions (HTTP 500): Return `{ "error": "Server error - please try again later" }` (no internal details)
  - This endpoint is NOT protected by JWT middleware (new users registering)

- [ ] T011 [US1] Create `backend/test/integration/test_registration_endpoint.dart` for registration endpoint tests
  - Unit test class `RegistrationEndpointTest` with setup/teardown
  - Test 1: Valid registration creates user and returns 201 with user data
  - Test 2: Duplicate email returns 409 with "Email already registered"
  - Test 3: Duplicate username returns 409 with "Username already taken"
  - Test 4: Weak password (no uppercase) returns 400 with validation error
  - Test 5: Weak password (< 8 chars) returns 400 with validation error
  - Test 6: Missing required field returns 400 with validation error
  - Test 7: Very long email or username is rejected (input length limits)
  - Run tests: `cd backend && dart test test/integration/test_registration_endpoint.dart`

### Frontend Implementation for User Story 1

- [ ] T012 [P] [US1] Create `frontend/lib/features/auth/models/auth_models.dart` for frontend auth data structures
  - Implement `RegistrationRequest` class: email, username, password, fullName (all String)
  - Implement `AuthResponse` class: userId (String), email (String), username (String), token (String, optional)
  - Implement `ValidationError` class: field (String), message (String)
  - Include `toJson()` and `fromJson()` methods for API communication

- [ ] T013 [P] [US1] Create `frontend/lib/features/auth/services/auth_service.dart` for frontend API calls
  - Implement `AuthService` class with static methods or as singleton
  - Method `register(RegistrationRequest request)` returns `Future<AuthResponse>`
    - POST request to `http://[backend]:8081/auth/register`
    - Handle response: On 201 → return `AuthResponse` object; On 400/409 → throw `AuthException` with error message
    - Handle network errors: Throw `AuthException('Network error - check connection')`
  - Method `login(String email, String password)` returns `Future<AuthResponse>` (needed for US2, stub for now)
  - Method `validateEmail(String email)` returns bool (basic client-side validation)
    - Regex pattern: `^[^\s@]+@[^\s@]+\.[^\s@]+$` (simple check)
  - Method `validateUsername(String username)` returns bool
    - 3-20 characters, alphanumeric + underscore only
  - No token storage here (done in AuthProvider)

- [ ] T014 [P] [US1] Create `frontend/lib/features/auth/providers/auth_provider.dart` for state management
  - Implement `AuthProvider` extending `ChangeNotifier` (using provider package)
  - Properties: `isLoading` (bool), `error` (String?), `user` (User?), `isAuthenticated` (bool)
  - Method `register(RegistrationRequest request)` 
    - Set `isLoading = true`, `error = null`
    - Call `AuthService.register(request)`
    - On success: Set `user` with response data, `isAuthenticated = true`
    - On error: Set `error = exception.message`, `isAuthenticated = false`
    - Always: Set `isLoading = false`
    - Call `notifyListeners()` after state changes
  - Method `clearError()` sets `error = null` and notifies
  - Method `reset()` clears all state for logout (empty user, isAuthenticated = false)
  - Store token in secure storage (flutter_secure_storage) AFTER successful registration
    - Key: "auth_token", value: response.token
    - Key: "user_id", value: response.userId

- [ ] T015 [P] [US1] Create `frontend/lib/features/auth/screens/registration_screen.dart` for registration UI
  - Implement `RegistrationScreen` as `StatefulWidget`
  - Build `MaterialPage` with AppBar ("Create Account") and form
  - Form fields with `TextFormField`:
    - Email field: `onChanged` calls client-side validation, shows error inline
    - Username field: Similar validation and error display
    - Password field: `obscureText = true`, shows password strength indicator, validation errors
    - Full Name field: Basic required validation
    - Sign Up button: Disabled while `isLoading`, shows loading spinner
  - Use `Consumer<AuthProvider>` to access provider state
  - On Sign Up click:
    - Validate all fields locally first
    - Show validation errors inline before API call
    - If valid: Call `authProvider.register(request)` 
    - Show loading indicator during API call
    - On success: Navigate to LoginScreen or main app
    - On error: Display error message in SnackBar or alert
  - Include "Already have account? Log in" link to LoginScreen
  - Password requirements displayed: "8+ chars, uppercase, lowercase, digit, special character"

- [ ] T016 [US1] Create `frontend/test/widget/test_registration_screen.dart` for registration form tests
  - Widget test class `RegistrationScreenTest`
  - Test 1: Screen renders with all form fields
  - Test 2: Email field shows validation error for invalid email format
  - Test 3: Username field shows validation error for < 3 characters
  - Test 4: Password field shows password strength indicator
  - Test 5: Sign Up button disabled while loading
  - Test 6: Sign Up button triggers authProvider.register() with form data
  - Test 7: Success shows SnackBar with confirmation message
  - Test 8: Error shows error message to user
  - Run tests: `cd frontend && flutter test test/widget/test_registration_screen.dart`

### User Story 1 Acceptance Tests

- [ ] T017 [US1] Integration test: Full registration flow end-to-end
  - Scenario: New user enters valid email, username, strong password
  - Backend: User created in database with hashed password
  - Frontend: User sees success message and can proceed to login
  - File: `frontend/test/integration/test_registration_flow.dart`

**Checkpoint**: User Story 1 Complete ✅
- Users can register with email, username, and validated password
- Duplicate emails/usernames properly rejected
- Weak passwords rejected with specific validation messages
- New users receive confirmation of account creation
- Account immediately usable for login (User Story 2)

---

## Phase 4: User Story 2 - Existing User Login (Priority: P1)

**Goal**: Users can log in with email and password. Session token is generated, securely stored, and persists across app restarts. Users remain logged in until explicit logout.

**Independent Test**:
- Existing user enters correct email and password → successful login, token stored
- User enters wrong password → receives "Invalid email or password" error
- User closes and reopens app → automatically logged in (token persists)
- User logs out → next app launch returns to login screen

### Backend Implementation for User Story 2

- [ ] T018 [P] [US2] Implement POST `/auth/login` endpoint in `backend/lib/src/endpoints/auth_endpoint.dart`
  - Accept request body: `{ "email": "...", "password": "..." }`
  - Validate both fields present and non-empty
  - Call `UserAuthService.authenticateUser(email, password)`
  - On success (HTTP 200): Return JSON `{ "user_id": "...", "email": "...", "username": "...", "token": "jwt_token_here" }`
  - On invalid credentials (HTTP 401): Return `{ "error": "Invalid email or password" }` (generic - no distinction between unknown email vs wrong password)
  - On rate limit (HTTP 429): Return `{ "error": "Too many login attempts. Please try again in 1 minute." }`
  - On other exceptions (HTTP 500): Return `{ "error": "Server error - please try again later" }`
  - Apply rate limiting middleware to this endpoint
  - This endpoint is NOT protected by JWT middleware (auth in progress)

- [ ] T019 [US2] Implement GET `/auth/me` endpoint in `backend/lib/src/endpoints/auth_endpoint.dart` for session validation
  - Protected endpoint: Requires valid JWT token in Authorization header
  - On valid token: Return JSON `{ "user_id": "...", "email": "...", "username": "...", "is_authenticated": true }`
  - On invalid/expired token: Return 401 (handled by JWT middleware)
  - Purpose: Frontend calls this on app startup to restore session; if 401 → token expired, require re-login

- [ ] T020 [US2] Implement POST `/auth/logout` endpoint in `backend/lib/src/endpoints/auth_endpoint.dart`
  - Protected endpoint: Requires valid JWT token
  - On success: Return 200 with `{ "message": "Logged out successfully" }`
  - Note: Backend doesn't explicitly invalidate tokens (30-day expiration handles this)
  - Frontend responsibility: Clear token from secure storage

- [ ] T021 [US2] Create `backend/test/integration/test_login_endpoint.dart` for login endpoint tests
  - Unit test class `LoginEndpointTest` with setup and teardown
  - Test 1: Valid login returns 200 with token and user data
  - Test 2: Wrong password returns 401 with "Invalid email or password"
  - Test 3: Non-existent email returns 401 with same generic message (no enumeration)
  - Test 4: Rate limiting after 5 failed attempts returns 429
  - Test 5: Successful login resets rate limit counter
  - Test 6: Missing email or password returns 400
  - Test 7: Token returned in login response is valid JWT (can be validated/decoded)
  - Run tests: `cd backend && dart test test/integration/test_login_endpoint.dart`

- [ ] T022 [US2] Create `backend/test/integration/test_session_validation.dart` for `/auth/me` endpoint tests
  - Test 1: Valid token returns 200 with user data
  - Test 2: Invalid token returns 401 with error
  - Test 3: Expired token returns 401 with error
  - Test 4: Missing Authorization header returns 401
  - Test 5: Malformed token returns 401

### Frontend Implementation for User Story 2

- [ ] T023 [P] [US2] Create `frontend/lib/core/services/secure_storage_service.dart` for token persistence
  - Implement `SecureStorageService` class using `flutter_secure_storage`
  - Method `saveToken(String token)` → stores in secure storage with key "auth_token"
  - Method `getToken()` → retrieves token from secure storage (returns null if not found)
  - Method `deleteToken()` → removes token from secure storage (called on logout)
  - Method `saveUser(User user)` → stores user JSON with key "current_user"
  - Method `getUser()` → retrieves user (returns null if not found)
  - Method `deleteUser()` → removes user data
  - Handle platform-specific details (iOS Keychain, Android Keystore) automatically through package
  - All methods are async (Future-based)

- [ ] T024 [P] [US2] Extend `frontend/lib/features/auth/providers/auth_provider.dart` for login and session restoration
  - Method `login(String email, String password)` (new)
    - Set `isLoading = true`, `error = null`
    - Call `AuthService.login(email, password)` 
    - On success: 
      - Set `user`, `isAuthenticated = true`
      - Call `SecureStorageService.saveToken(response.token)`
      - Call `SecureStorageService.saveUser(response.user)`
    - On error: Set `error`, `isAuthenticated = false`
    - Always: Set `isLoading = false`, notify listeners
  - Method `restoreSession()` (new)
    - Called on app startup
    - Set `isLoading = true`
    - Retrieve token from `SecureStorageService.getToken()`
    - If token exists: Call `AuthService.validateSession(token)` (calls `/auth/me` endpoint)
      - On 200: Deserialize user data, set `user`, `isAuthenticated = true`
      - On 401: Token expired, clear storage, `isAuthenticated = false`
    - If no token: `isAuthenticated = false`
    - Always: Set `isLoading = false`, notify listeners
  - Method `logout()` (new)
    - Call `SecureStorageService.deleteToken()`
    - Call `SecureStorageService.deleteUser()`
    - Set `user = null`, `isAuthenticated = false`
    - Call `AuthService.logout(currentToken)` (POST `/auth/logout` for backend cleanup if needed)
    - Notify listeners

- [ ] T025 [P] [US2] Create `frontend/lib/features/auth/screens/login_screen.dart` for login UI
  - Implement `LoginScreen` as `StatefulWidget`
  - Build `MaterialPage` with AppBar ("Sign In") and form
  - Form fields with `TextFormField`:
    - Email field: Client-side validation, error messages
    - Password field: `obscureText = true`, validation
    - Sign In button: Disabled while loading
    - "Show password" toggle for UX (optional but recommended)
  - Use `Consumer<AuthProvider>` to access provider state
  - On Sign In click:
    - Validate fields locally
    - Call `authProvider.login(email, password)`
    - Show loading spinner during API call
    - On success: Navigate to main app / home screen
    - On error (invalid credentials): Show error in SnackBar
    - On error (rate limit): "Too many attempts, try again later"
  - Include "Don't have account? Sign up" link to RegistrationScreen
  - Forgot password link (stub for now - out of scope)

- [ ] T026 [P] [US2] Create `frontend/lib/core/app_navigator.dart` for conditional navigation based on auth state
  - Implement `AppNavigator` class with static method `getInitialRoute(AuthProvider authProvider)`
  - If `authProvider.isAuthenticated` && user exists: Return route to main app / home screen
  - If not authenticated: Return route to LoginScreen
  - Called from `main.dart` to set initial route
  - Also use `Consumer<AuthProvider>` in `main.dart` to rebuild UI when auth state changes

- [ ] T027 [P] [US2] Update `frontend/lib/main.dart` to initialize auth on app startup
  - Import AuthProvider and SecureStorageService
  - In `main()` function:
    - Create AuthProvider instance
    - Call `authProvider.restoreSession()` before `runApp()`
    - Pass AuthProvider to `MultiProvider` / app widget tree
  - Create `MessengerApp` widget that consumes AuthProvider
  - Call `AppNavigator.getInitialRoute()` to set home based on auth state
  - Listen to auth state changes to update UI (re-navigate if session expires)

- [ ] T028 [US2] Create `frontend/test/widget/test_login_screen.dart` for login form tests
  - Widget test class `LoginScreenTest`
  - Test 1: Screen renders with email and password fields
  - Test 2: Email field validates format
  - Test 3: Sign In button disabled while loading
  - Test 4: Sign In button triggers authProvider.login() with credentials
  - Test 5: Successful login navigates to home screen
  - Test 6: Invalid credentials shows error message
  - Test 7: Rate limit error displays appropriate message
  - Test 8: "Don't have account?" link navigates to RegistrationScreen
  - Run tests: `cd frontend && flutter test test/widget/test_login_screen.dart`

- [ ] T029 [US2] Create `frontend/test/widget/test_auth_provider.dart` for provider state management tests
  - Widget test / standalone test class `AuthProviderTest`
  - Test 1: `register()` updates `isAuthenticated` on success
  - Test 2: `login()` saves token to secure storage
  - Test 3: `restoreSession()` retrieves token and validates
  - Test 4: `logout()` clears token from storage
  - Test 5: `restoreSession()` handles missing token gracefully
  - Run tests: `cd frontend && flutter test test/widget/test_auth_provider.dart`

### User Story 2 Acceptance Tests

- [ ] T030 [US2] Integration test: Full login flow with session persistence
  - Scenario: Existing user logs in with correct email and password
  - Backend: Authentication succeeds, JWT token returned
  - Frontend: Token stored in secure storage, user navigates to main app
  - App restart: Session automatically restored, user logged in without re-entering credentials
  - File: `frontend/test/integration/test_login_session_flow.dart`

- [ ] T031 [US2] Integration test: Logout and session invalidation
  - Scenario: User logs out explicitly
  - Backend: Token invalidation noted (or just 30-day expiration)
  - Frontend: Token cleared from secure storage
  - App restart: User returned to login screen (no session to restore)
  - File: `frontend/test/integration/test_logout_flow.dart`

**Checkpoint**: User Story 2 Complete ✅
- Users can log in with email and password
- Valid credentials generate JWT token that is securely stored
- Token persists across app restarts, enabling automatic re-login
- Rate limiting prevents brute force attacks (max 5 attempts/minute)
- Logout clears session, requiring re-authentication on next app launch
- Error messages are generic (prevent user enumeration)

---

## Phase 5: Integration & Cross-Cutting Concerns

**Purpose**: End-to-end testing, documentation, and polish

**⏱️ Estimated**: 1.5 hours | **🎯 Parallelizable**: Partial

### End-to-End Integration Testing

- [ ] T032 [P] Create `frontend/test/integration/test_e2e_auth_complete_cycle.dart` for complete auth workflow
  - Test scenario 1: New user registration → login → session restore cycle
    - Register with new email/username/password
    - Verify account created in database
    - Login with same credentials
    - Verify token returned and stored
    - Kill app (simulated)
    - Restart app
    - Verify automatic login (no screen shown)
    - Navigate to main app
  - Test scenario 2: Logout → login cycle
    - Start logged in (from test scenario 1)
    - Call logout
    - Verify token cleared
    - App restart
    - Verify returned to login screen
    - Login again successfully
  - Run tests: `cd frontend && flutter test test/integration/test_e2e_auth_complete_cycle.dart`

- [ ] T033 [P] Create error handling integration test `frontend/test/integration/test_auth_error_scenarios.dart`
  - Test scenario 1: Network error during registration → retry succeeds
  - Test scenario 2: Network error during login → shows offline message, retry works
  - Test scenario 3: Server returns 500 error → generic message shown
  - Test scenario 4: Malformed response from server → handled gracefully
  - Test scenario 5: Rate limiting (simulated) → shows rate limit message

### Backend Integration Tests (Cross-Feature)

- [ ] T034 [P] Create `backend/test/integration/test_user_auth_service.dart` for service-level auth logic
  - Unit test class `UserAuthServiceTest` with setup/teardown including test database
  - Test password hashing: Multiple passwords hash to different values
  - Test password verification: Correct password verified, wrong password rejected
  - Test registration flow: User created with hashed password (not plaintext)
  - Test email uniqueness: Duplicate emails rejected
  - Test username uniqueness: Duplicate usernames rejected
  - Test password validation: All 5 criteria enforced
  - Test login flow: User retrieved, password verified, token generated
  - Run tests: `cd backend && dart test test/integration/test_user_auth_service.dart`

- [ ] T035 [P] Create `backend/test/integration/test_jwt_service.dart` for token generation and validation
  - Unit test class `JwtServiceTest`
  - Test token generation: Creates valid JWT with correct payload
  - Test token validation: Valid token accepted, payload extracted
  - Test token expiration: Expired tokens rejected with clear error
  - Test token tampering: Modified tokens rejected (signature invalid)
  - Test missing claims: Tokens without required claims rejected
  - Run tests: `cd backend && dart test test/integration/test_jwt_service.dart`

### Security & Compliance Testing

- [ ] T036 [P] Create security checklist test `backend/test/security/test_security_compliance.dart`
  - Verify no plaintext passwords in logs or responses
  - Verify bcrypt cost factor is >= 10 (slow hashing)
  - Verify JWT tokens use RS256 (asymmetric)
  - Verify error messages don't leak which field failed (user enumeration prevention)
  - Verify rate limiting enabled on login endpoint
  - Verify tokens expire (30-day validation)
  - Verify secure storage used on frontend
  - Manual test: Search codebase for hardcoded secrets (should find none)

- [ ] T037 Create documentation: `backend/lib/src/services/AUTH_SERVICE_DOCUMENTATION.md`
  - Overview of authentication architecture
  - Password hashing: bcrypt cost=10 rationale
  - JWT token generation: RS256 rationale, 30-day expiration
  - Rate limiting: 5 attempts/minute policy
  - Error messages: Security principles (no enumeration)
  - Usage examples for developers extending auth

- [ ] T038 Create documentation: `frontend/lib/features/auth/AUTH_README.md`
  - Overview of auth flow on frontend
  - Provider pattern for state management
  - Secure storage implementation
  - Session restoration on app startup
  - Logout and cleanup
  - Testing guide for frontend auth features

### Performance & Load Testing

- [ ] T039 Create backend load test `backend/test/performance/test_password_hashing_performance.dart`
  - Measure time for `PasswordHasher.hashPassword()` with cost=10
  - Verify > 100ms hash time (prevents rainbow tables)
  - Verify < 1 second hash time (UX acceptable)
  - Generate 100 hashes in parallel, measure total time
  - Document results

- [ ] T040 Create frontend performance test `frontend/test/performance/test_screen_render_time.dart`
  - Measure RegistrationScreen render time (goal: <500ms)
  - Measure LoginScreen render time (goal: <500ms)
  - Measure form validation feedback response (goal: <100ms)
  - Measure secure storage access time (goal: <50ms)
  - Document results

### Documentation & Quickstart

- [ ] T041 Update `/specs/003-user-auth-flow/quickstart.md` with complete setup and test instructions
  - Prerequisites: Docker, Flutter, Dart installed
  - Database migration: `./backend/scripts/run_migrations.dart`
  - Backend startup: `docker-compose up`
  - Test backend endpoints: `curl -X POST http://localhost:8081/auth/register -d ...`
  - Frontend startup: `cd frontend && flutter run`
  - Test registration flow: Manual steps
  - Test login flow: Manual steps
  - Test session persistence: Close and reopen app
  - Verification: Checklist of working features

- [ ] T042 Update main `/README.md` with authentication feature information
  - Add section "Authentication Flow"
  - Link to quickstart.md
  - Add diagram: Registration → Login → App → Logout
  - Add security highlights: bcrypt, JWT, secure storage, rate limiting

### Verification & Cleanup

- [ ] T043 [P] Run complete test suite and verify coverage
  - Backend unit tests: `cd backend && dart test test/unit/`
  - Backend integration tests: `cd backend && dart test test/integration/`
  - Frontend widget tests: `cd frontend && flutter test test/widget/`
  - Generate coverage reports
  - Target: >85% coverage for authentication code

- [ ] T044 Verify code quality and standards
  - Dart analyzer: `cd backend && dart analyze` (zero errors)
  - Flutter analyzer: `cd frontend && flutter analyze` (zero errors)
  - Formatting: `dart format lib/` and `flutter format lib/`
  - No hardcoded secrets or passwords in any files
  - No TODO comments blocking the feature

- [ ] T045 Final integration verification against acceptance criteria
  - Acceptance Scenario US1.1: New user registers with valid data → success
  - Acceptance Scenario US1.2: New user registers with duplicate email → error
  - Acceptance Scenario US1.3: New user registers with weak password → specific error
  - Acceptance Scenario US1.4: User registers then immediately logs in → success
  - Acceptance Scenario US2.1: Existing user logs in with correct credentials → success
  - Acceptance Scenario US2.2: User logs in with wrong password → generic error
  - Acceptance Scenario US2.3: User logs in, closes app, reopens → auto-logged-in
  - Acceptance Scenario US2.4: User logs in, logs out, reopens → returns to login

**Checkpoint**: All integration tests passing, documentation complete, code quality verified ✅

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 2 (Foundational)**: No dependencies - can start immediately
  - All authentication services are independent
  - Can develop services and middleware in parallel

- **Phase 3 (User Story 1 - Registration)**: Depends on Phase 2
  - Backend tests depend on UserAuthService
  - Frontend depends on backend endpoints being available
  - Can implement backend and frontend UI in parallel (T009-T016)

- **Phase 4 (User Story 2 - Login)**: Depends on Phase 2
  - Backend login depends on registration being complete (users must exist to login)
  - Frontend login depends on backend endpoints
  - Can implement backend and frontend UI in parallel

- **Phase 5 (Integration & Polish)**: Depends on both US1 and US2
  - E2E tests require both registration and login working
  - Security tests verify both features
  - Documentation covers complete flow

### Within Each User Story

**User Story 1 (Registration)**:
1. Backend services (T001-T008) - blocking
2. Backend endpoint (T009-T010) - depends on services
3. Backend tests (T011) - depends on endpoint
4. Frontend models (T012)
5. Frontend service & provider (T013-T014)
6. Frontend UI (T015)
7. Frontend tests (T016)
8. Integration test (T017)

**User Story 2 (Login)**:
1. Backend endpoints (T018-T020) - depends on US1 services
2. Backend tests (T021-T022)
3. Frontend secure storage (T023)
4. Frontend provider extensions (T024)
5. Frontend UI (T025)
6. Frontend navigation (T026-T027)
7. Frontend tests (T028-T029)
8. Integration tests (T030-T031)

### Parallel Opportunities

**Fully Parallelizable** (can work on simultaneously with no dependencies):
- All Phase 2 foundational services: T001-T008 (6 tasks, 2-3 hours total)
  - `password_validator.dart` (independent)
  - `password_hasher.dart` (independent)
  - `jwt_service.dart` (independent)
  - `auth_exception.dart` (independent)
  - `user_auth_service.dart` (depends on above)
  - `auth_result.dart` (independent)

- Within US1, all frontend tasks can run in parallel after backend endpoints ready: T012-T016
  - Frontend models (T012)
  - Frontend service & provider (T013-T014)
  - Frontend UI (T015)
  - Frontend tests (T016)

- Within US2, all frontend tasks can run in parallel after backend endpoints ready: T023-T029
  - Secure storage (T023)
  - Provider extensions (T024)
  - UI screens (T025-T026)
  - Navigation setup (T027)
  - Tests (T028-T029)

**Parallelizable by Story**:
- Phone 1: Frontend developer works on US1 UI (T012-T016) while backend developer works on US2 endpoints (T018-T020)
- Phone 2: Frontend developer works on US2 UI (T023-T029) while backend developer works on integration tests (T034-T035)

**Sequential Dependencies** (must complete in order):
1. Backend services (Phase 2) → Backend endpoints (US1, US2)
2. Backend endpoints → Backend tests
3. Backend endpoints → Frontend services
4. Frontend services → Frontend UI
5. Both US1 & US2 → Integration tests

### Execution Example: Two-Person Team

**Option 1: Backend then Frontend** (18-20 hours)
1. Days 1-2 (Person A): All Phase 2 services (T001-T008) - 6 hours
2. Days 2-3 (Person A, Person B): Endpoints and tests (T009-T011, T018-T022) - 8 hours parallel
3. Days 4-5 (Person B): Frontend auth (T012-T016, T023-T029) - 8 hours
4. Day 6 (Both): Integration tests (T032-T045) - 4 hours

**Option 2: Parallel Registration & Login** (14-16 hours)
1. Days 1-2 (Person A, Person B): Services (T001-T008) - 2-3 hours (parallel)
2. Day 2-3 (Person A): US1 backend (T009-T011) - 4 hours
3. Day 2-3 (Person B): US2 backend (T018-T022) - 4 hours (parallel with A)
4. Days 4-5 (Person A): US1 frontend (T012-T016) - 4 hours
5. Days 4-5 (Person B): US2 frontend (T023-T029) - 4 hours (parallel with A)
6. Day 6 (Both): Integration (T032-T045) - 3 hours

---

## Task Execution Guidelines

### Testing Requirements

All tasks include automated tests:
- **Backend**: Unit tests (services), integration tests (endpoints), security compliance tests
- **Frontend**: Widget tests (UI components), provider tests (state), integration tests (full flows)
- **E2E**: Complete registration → login → session persistence → logout cycle

### Code Quality Standards

- **Zero analyzer errors**: `dart analyze` (backend), `flutter analyze` (frontend)
- **Formatted code**: Follow project conventions from ENDPOINT_PATTERNS.md, SERVICE_PATTERNS.md, MODEL_PATTERNS.md
- **No secrets in code**: No hardcoded passwords, tokens, or API keys
- **Descriptive commit messages**: Align with phase/user story (e.g., "US1: Implement registration endpoint")
- **Min 85% test coverage**: For critical auth code paths

### Definition of Done (For Each Task)

- [ ] Code written per ENDPOINT_PATTERNS.md, SERVICE_PATTERNS.md, or MODEL_PATTERNS.md
- [ ] All tests passing locally
- [ ] Code reviewed against security checklist (for auth tasks)
- [ ] No analyzer errors
- [ ] Commit pushed with descriptive message
- [ ] Linked to appropriate user story issue

### MVP Scope (Recommended Start)

**Minimum Viable Product**: 25 tasks, ~18-24 hours
- Phase 2: All foundational services (T001-T008, 6 tasks)
- US1: Registration endpoint + tests + basic UI (T009-T016, 8 tasks)
- US2: Login endpoint + tests + basic UI (T018-T029, 12 tasks)
- Integration: Complete auth cycle test (T032, 1 task)

**Extended Scope**: All 45 tasks, ~45-55 hours
- Includes advanced features: rate limiting, password reset preparation, comprehensive security testing, performance optimization, detailed documentation

---

## Success Metrics

### Phase 2 Success
- [x] All services pass unit tests with >90% coverage
- [x] Password validator enforces 5-criteria strength rules
- [x] Bcrypt hashing takes >100ms (verified by performance test)
- [x] JWT tokens generate and validate successfully
- [x] No plaintext passwords in any logs

### User Story 1 Success
- [x] New users can register with 5 validation errors shown
- [x] Duplicate email rejected with specific error
- [x] Duplicate username rejected with specific error
- [x] Weak passwords rejected with specific validation feedback
- [x] 95% of new users complete registration on first attempt
- [x] Frontend form provides inline validation feedback
- [x] Backend tests pass: registration succeeds and fails correctly

### User Story 2 Success
- [x] Existing users can login with 100% success rate on valid credentials
- [x] Wrong password rejected with generic "Invalid email or password"
- [x] Non-existent email rejected with same generic error
- [x] Session token persists across app restart (5+ cycles tested)
- [x] Rate limiting prevents >5 login attempts per minute
- [x] Users can logout and token is cleared
- [x] Backend tests pass: login and session validation work correctly

### Integration Success
- [x] Full registration → login → session restore → logout cycle works
- [x] All error scenarios handled gracefully (network, server, rate limit)
- [x] Performance verified: login <2 seconds on typical network
- [x] Code quality: Zero build errors, >85% test coverage, formatted code
- [x] Documentation complete: quickstart.md, README updated, inline docs
- [x] All acceptance scenarios passing

