---
description: "Detailed task list for Email Verification and Password Recovery feature"
---

# Tasks: Email Verification and Password Recovery

**Feature**: `015-email-verification-recovery`  
**Input**: Design documents from `/specs/015-email-verification-recovery/`  
**Prerequisites**: plan.md ✅, spec.md ✅, data-model.md ✅, quickstart.md ✅, contracts/verification-endpoints.yaml ✅

**Tests**: Comprehensive testing included - 50+ test scenarios per checklist (see checklists/requirements.md)

**Organization**: Tasks organized by implementation phase, then by user story (P1 stories first, then P2). Each user story can be tested independently.

---

## Format: `- [ ] [TaskID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no blocking dependencies on incomplete tasks)
- **[Story]**: Which user story this belongs to: [US1], [US2], [US3], [US4]
- **File paths**: Exact locations for implementation (backend/, frontend/, or database migrations/)

---

## Phase 1: Setup (Shared Infrastructure & Database)

**Purpose**: Database migrations, email service, core utilities

**Duration**: 1-2 days

- [ ] T001 Create database migration for VerificationToken table in `backend/migrations/007_create_verification_tokens_table.dart`
- [ ] T002 [P] Create database migration for PasswordResetToken table in `backend/migrations/008_create_password_reset_tokens_table.dart`
- [ ] T003 [P] Create database migration for PasswordResetAttempt table in `backend/migrations/009_create_password_reset_attempts_table.dart`
- [ ] T004 [P] Create database migration to add `verified_at` column to Users table in `backend/migrations/010_add_verified_at_to_users.dart`
- [ ] T005 Create run_migrations script entry for new migrations in `backend/scripts/run_migrations.dart`
- [ ] T006 Verify all migrations run successfully against PostgreSQL test database

---

## Phase 2: Foundational (Backend Services & Utilities)

**Purpose**: Core services that all endpoints depend on

**Duration**: 2-3 days

**⚠️ CRITICAL**: These must be complete before any endpoint can be implemented

### Core Token Management
- [ ] T007 Implement TokenService in `backend/lib/src/services/token_service.dart` with:
  - [ ] Generate 256-bit cryptographically secure token (Base64URL encoded)
  - [ ] SHA256 hash token before storage
  - [ ] Verify token with timing-safe comparison
  - [ ] Mark token as used (single-use enforcement)
  - [ ] 90%+ unit test coverage in `backend/test/services/token_service_test.dart`

### Email Service
- [ ] T008 Implement EmailService in `backend/lib/src/services/email_service.dart` with:
  - [ ] Configure SMTP or SendGrid integration
  - [ ] Build verification email template (HTML + plain text)
  - [ ] Build password reset email template (HTML + plain text)
  - [ ] Include secure deep links in emails
  - [ ] Handle email delivery errors gracefully
  - [ ] 90%+ unit test coverage in `backend/test/services/email_service_test.dart`

### Rate Limiting & Security
- [ ] T009 Implement RateLimitService in `backend/lib/src/services/rate_limit_service.dart` with:
  - [ ] Check 5 password reset attempts per email per 1-hour sliding window
  - [ ] Return remaining attempts and retry-after duration
  - [ ] Prevent user enumeration (same response for existing/non-existing emails)
  - [ ] 90%+ unit test coverage in `backend/test/services/rate_limit_service_test.dart`

### Verification & Password Reset Flows
- [ ] T010 Implement VerificationService in `backend/lib/src/services/verification_service.dart` with:
  - [ ] Consume verification token and update user.email_verified
  - [ ] Check token expiration (24 hours)
  - [ ] Prevent double-verification
  - [ ] Invalidate previous verification tokens when resending
  - [ ] Handle timezone correctly (UTC only)
  - [ ] 90%+ unit test coverage in `backend/test/services/verification_service_test.dart`

- [ ] T011 Implement PasswordResetService in `backend/lib/src/services/password_reset_service.dart` with:
  - [ ] Validate new password (8+ chars, uppercase, lowercase, digit, special char)
  - [ ] Hash new password using bcrypt (same as Spec 003 login)
  - [ ] Consume reset token and update user password
  - [ ] Invalidate all user JWT sessions after password change
  - [ ] Clear rate limit counter on successful reset
  - [ ] 90%+ unit test coverage in `backend/test/services/password_reset_service_test.dart`

**Checkpoint**: All services complete, tested, and ready for endpoint implementation

---

## Phase 3: User Story 1 - Email Verification After Registration (Priority: P1) 🎯 MVP

**Goal**: New users receive verification email after registration and must verify before accessing features

**Independent Test**: Register → receive email → click link → account becomes "verified" → user can access features

### Backend Implementation - US1
- [ ] T012 [P] [US1] Implement SendVerificationEmailHandler in `backend/lib/src/handlers/send_verification_handler.dart`:
  - [ ] Accept authenticated POST /auth/send-verification-email request
  - [ ] Generate verification token via TokenService
  - [ ] Send verification email via EmailService
  - [ ] Return success response with retry instructions
  - [ ] Handle user already verified case gracefully

- [ ] T013 [P] [US1] Implement VerifyEmailHandler in `backend/lib/src/handlers/verify_email_handler.dart`:
  - [ ] Accept public POST /auth/verify-email with token
  - [ ] Call VerificationService to consume token
  - [ ] Return success with "Email verified" message
  - [ ] Return error for expired/invalid tokens
  - [ ] Return error for already-verified accounts
  - [ ] No token exposure in error messages (prevent enumeration)

- [ ] T014 [US1] Integrate verification endpoints into `backend/lib/server.dart`:
  - [ ] Add routes for /auth/send-verification-email (authenticated)
  - [ ] Add routes for /auth/verify-email (public)
  - [ ] Connect handlers to database
  - [ ] Add CORS headers for email links

- [ ] T015 [P] [US1] Integration test for email verification flow in `backend/test/integration/email_verification_flow_test.dart`:
  - [ ] Test: Register user → send verification email → receive success
  - [ ] Test: Verify email with token → user marked as verified
  - [ ] Test: Verify email with expired token → get error (maintain 24-hour window)
  - [ ] Test: Already-verified user requests resend → get message they're already verified
  - [ ] Test: User without verification shouldn't access core features (tested in Phase 3 US2)
  - [ ] Expect >95% endpoint response time <500ms

### Frontend Implementation - US1
- [ ] T016 [P] [US1] Create VerificationPendingScreen in `frontend/lib/features/email_verification/pages/verification_pending_screen.dart`:
  - [ ] Display message "Verification email sent to [email]"
  - [ ] Show "Resend verification email" button
  - [ ] Show "Wrong email? Register again" button
  - [ ] Disable resend button for 60 seconds after sending email
  - [ ] Show success/error messages from API calls

- [ ] T017 [P] [US1] Create VerificationSuccessScreen in `frontend/lib/features/email_verification/pages/verification_success_screen.dart`:
  - [ ] Display success message "Email verified!"
  - [ ] Show "Continue to messaging" button
  - [ ] Redirect to main app after success

- [ ] T018 [P] [US1] Implement EmailVerificationService in `frontend/lib/features/email_verification/services/email_verification_service.dart`:
  - [ ] HTTP POST /auth/send-verification-email (authenticated, with JWT token)
  - [ ] HTTP POST /auth/verify-email with token (public)
  - [ ] Parse responses and handle errors
  - [ ] Return structured response objects

- [ ] T019 [P] [US1] Implement VerificationProvider in `frontend/lib/features/email_verification/providers/verification_provider.dart`:
  - [ ] State: `pending`, `success`, `error`, `loading`
  - [ ] Methods: `resendVerificationEmail()`, `verifyToken(token)`
  - [ ] Handle deep link token from email
  - [ ] Persist verification state

- [ ] T020 [US1] Configure deep linking for email verification in `frontend/lib/core/routing/deep_link_handler.dart`:
  - [ ] Parse `messenger://verify?token=XXX` links from verify email
  - [ ] Route to VerificationScreen with token pre-filled
  - [ ] Handle deep links on both cold start and running app
  - [ ] Support both Android and iOS schemes

- [ ] T021 [US1] Update AuthProvider to check email_verified status in `frontend/lib/features/auth/providers/auth_provider.dart`:
  - [ ] After login, check if user email_verified = true
  - [ ] If not verified, show VerificationPendingScreen instead of main app
  - [ ] Restore verification state from secure storage

- [ ] T022 [P] [US1] Create VerificationProvider tests in `frontend/test/email_verification/providers/verification_provider_test.dart`:
  - [ ] Test state transitions during verification
  - [ ] Test API error handling
  - [ ] Test deep link token parsing

- [ ] T023 [P] [US1] Create DeepLinkHandler tests in `frontend/test/core/routing/deep_link_handler_test.dart`:
  - [ ] Test parsing verification links
  - [ ] Test navigation to correct screen
  - [ ] Test app_links integration (if available)

**Checkpoint**: User Story 1 complete - new users can verify email and access app

---

## Phase 4: User Story 2 - Forgotten Password Recovery (Priority: P1)

**Goal**: Users who forgot password can reset it via email link

**Independent Test**: Click "Forgot Password" → enter email → receive reset email → click link → enter new password → login succeeds

### Backend Implementation - US2
- [ ] T024 [P] [US2] Implement SendPasswordResetHandler in `backend/lib/src/handlers/send_password_reset_handler.dart`:
  - [ ] Accept public POST /auth/send-password-reset-email with email
  - [ ] Check rate limit (5 per email per hour)
  - [ ] Generate password reset token via TokenService
  - [ ] Send password reset email via EmailService
  - [ ] Return identical response whether email exists or not (prevent enumeration)
  - [ ] Log attempt for rate limiting regardless of email existence

- [ ] T025 [P] [US2] Implement ResetPasswordHandler in `backend/lib/src/handlers/reset_password_handler.dart`:
  - [ ] Accept public POST /auth/reset-password with token and new password
  - [ ] Call PasswordResetService to validate and update password
  - [ ] Invalidate all user's JWT sessions
  - [ ] Return success message
  - [ ] Return error for expired/invalid tokens
  - [ ] No token exposure in error messages

- [ ] T026 [US2] Integrate password reset endpoints into `backend/lib/server.dart`:
  - [ ] Add routes for /auth/send-password-reset-email (public)
  - [ ] Add routes for /auth/reset-password (public)
  - [ ] Connect handlers to RateLimitService and PasswordResetService
  - [ ] Add Retry-After header for rate limit errors

- [ ] T027 [P] [US2] Integration test for password reset flow in `backend/test/integration/password_reset_flow_test.dart`:
  - [ ] Test: Request password reset → receive success message
  - [ ] Test: Request password reset 5 times → all succeed
  - [ ] Test: Request password reset 6th time → get rate limit error (429)
  - [ ] Test: Rate limit counter resets after 1 hour
  - [ ] Test: Non-existent email returns same response (no enumeration)
  - [ ] Test: Reset password with token → password updated
  - [ ] Test: Old password no longer works after reset
  - [ ] Test: Reset with expired token → error
  - [ ] Test: Successful reset clears rate limit counter
  - [ ] Expect >95% endpoint response time <500ms

### Frontend Implementation - US2
- [ ] T028 [P] [US2] Create ForgotPasswordScreen in `frontend/lib/features/password_recovery/pages/forgot_password_screen.dart`:
  - [ ] Email input field with validation
  - [ ] "Send reset email" button
  - [ ] "Back to login" link
  - [ ] Show success message "Check your email for reset link"
  - [ ] Show error messages from API (rate limit, network errors)
  - [ ] Disable button while loading

- [ ] T029 [P] [US2] Create PasswordResetScreen in `frontend/lib/features/password_recovery/pages/password_reset_screen.dart`:
  - [ ] New password input field with visibility toggle
  - [ ] Confirm password field
  - [ ] Password strength indicator (visual feedback on requirements)
  - [ ] "Reset password" button
  - [ ] Show validation errors as user types
  - [ ] Show success message upon completion
  - [ ] Redirect to login screen after success

- [ ] T030 [P] [US2] Create ResetSuccessScreen in `frontend/lib/features/password_recovery/pages/reset_success_screen.dart`:
  - [ ] Display "Password reset successful!"
  - [ ] Show "Return to login" button
  - [ ] Redirect to login screen

- [ ] T031 [P] [US2] Implement PasswordRecoveryService in `frontend/lib/features/password_recovery/services/password_recovery_service.dart`:
  - [ ] HTTP POST /auth/send-password-reset-email (public)
  - [ ] HTTP POST /auth/reset-password with token and password (public)
  - [ ] Parse responses and handle errors
  - [ ] Return structured response objects

- [ ] T032 [P] [US2] Implement PasswordRecoveryProvider in `frontend/lib/features/password_recovery/providers/password_recovery_provider.dart`:
  - [ ] State: `initial`, `loading`, `sent`, `resetting`, `success`, `error`
  - [ ] Methods: `requestPasswordReset(email)`, `resetPassword(token, newPassword)`
  - [ ] Handle deep link token from reset email
  - [ ] Store reset flow state

- [ ] T033 [US2] Add "Forgot Password?" button to LoginScreen in `frontend/lib/features/auth/screens/login_screen.dart`:
  - [ ] Button navigates to ForgotPasswordScreen
  - [ ] Button clearly visible near login form

- [ ] T034 [US2] Update deep link handler to support password reset in `frontend/lib/core/routing/deep_link_handler.dart`:
  - [ ] Parse `messenger://reset?token=XXX` links from password reset email
  - [ ] Route to PasswordResetScreen with token pre-filled
  - [ ] Handle both cold start and running app scenarios

- [ ] T035 [P] [US2] Create PasswordRecoveryProvider tests in `frontend/test/password_recovery/providers/password_recovery_provider_test.dart`:
  - [ ] Test state transitions during reset flow
  - [ ] Test API error handling and rate limit response
  - [ ] Test deep link token parsing

- [ ] T036 [P] [US2] Create ForgotPasswordScreen tests in `frontend/test/password_recovery/pages/forgot_password_screen_test.dart`:
  - [ ] Test email input validation
  - [ ] Test form submission
  - [ ] Test error message display
  - [ ] Test success message display

- [ ] T037 [P] [US2] Create PasswordResetScreen tests in `frontend/test/password_recovery/pages/password_reset_screen_test.dart`:
  - [ ] Test password input validation
  - [ ] Test password strength indicator
  - [ ] Test form submission
  - [ ] Test password confirmation matching
  - [ ] Test validation error messages

**Checkpoint**: User Story 2 complete - users can recover forgotten passwords

---

## Phase 5: User Story 3 - Reset Link Expiration and Re-request (Priority: P2)

**Goal**: Expired password reset links are handled gracefully with easy re-request flow

**Independent Test**: Request reset → wait 24+ hours (simulate) → try to use link → see "expired" message → re-request link → new link works

### Backend Implementation - US3
- [ ] T038 [P] [US3] Add GET /auth/check-reset-token endpoint in `backend/lib/src/handlers/check_reset_token_handler.dart`:
  - [ ] Accept public GET request with token
  - [ ] Return token validity status without consuming token
  - [ ] Used by frontend to display "token expired" message before form submission
  - [ ] Help prevent user frustration with invalid form submission

- [ ] T039 [US3] Implement token expiration check in ResetPasswordHandler (from T025):
  - [ ] Already implemented in PasswordResetService
  - [ ] Verify error message clearly states "This link has expired. Please request a new reset link."
  - [ ] Include expiration timestamp in error (when they can try again)

- [ ] T040 [P] [US3] Integration test for token expiration in `backend/test/integration/token_expiration_test.dart`:
  - [ ] Test: Create reset token, wait 24+ hours (simulate with database manipulation)
  - [ ] Test: Attempt to use expired token → get "expired" error
  - [ ] Test: Check token validity of expired token → returns false
  - [ ] Test: Token invalid after 24 hours but before 25 hours
  - [ ] Test: UTC timezone handling (no local time dependencies)

### Frontend Implementation - US3
- [ ] T041 [P] [US3] Add "Link expired?" message and "Request new reset link" button to PasswordResetScreen:
  - [ ] Display when receiving expired token error from backend
  - [ ] Button navigates back to ForgotPasswordScreen
  - [ ] Clear form for new email entry

- [ ] T042 [P] [US3] Create ExpiredLinkScreen in `frontend/lib/features/password_recovery/pages/expired_link_screen.dart`:
  - [ ] Display "This password reset link has expired"
  - [ ] Show "Request a new reset link" button
  - [ ] Button navigates to ForgotPasswordScreen
  - [ ] Explain "Links expire after 24 hours for security"

- [ ] T043 [US3] Update PasswordResetScreen to detect expired token on init and route to ExpiredLinkScreen:
  - [ ] On deep link navigation with token, validate token first
  - [ ] If expired, show ExpiredLinkScreen instead
  - [ ] Call check-reset-token endpoint to verify before showing form

- [ ] T044 [P] [US3] Create ExpiredLinkScreen tests in `frontend/test/password_recovery/pages/expired_link_screen_test.dart`:
  - [ ] Test correct navigation on button press
  - [ ] Test message clarity

**Checkpoint**: User Story 3 complete - expired links handled gracefully

---

## Phase 6: User Story 4 - Rate Limited Password Reset Requests (Priority: P2)

**Goal**: System prevents abuse by limiting password reset attempts to 5 per email per hour

**Independent Test**: Submit 5 reset requests (success) → 6th request blocked (429 error) → wait 1 hour → 6th request succeeds

### Backend Implementation - US4
- [ ] T045 [P] [US4] Add rate limit check to SendPasswordResetHandler (from T024):
  - [ ] Already implemented via RateLimitService
  - [ ] Verify response includes Retry-After header with seconds remaining
  - [ ] Test that 5th attempt succeeds and 6th is blocked

- [ ] T046 [P] [US4] Integration test for rate limiting in `backend/test/integration/rate_limiting_test.dart`:
  - [ ] Test: Submit 5 reset requests for same email → all succeed
  - [ ] Test: 6th reset request returns 429 with Retry-After header
  - [ ] Test: Retry-After shows remaining time (close to 3600 seconds)
  - [ ] Test: After 1 hour passes, counter resets and 6th request succeeds
  - [ ] Test: Successful password reset clears rate limit counter
  - [ ] Test: Rate limit per email (different emails not affected)
  - [ ] Test: No timing differences in responses for blocked vs. non-existing emails

### Frontend Implementation - US4
- [ ] T047 [P] [US4] Update ForgotPasswordScreen to handle rate limit errors in `frontend/lib/features/password_recovery/pages/forgot_password_screen.dart`:
  - [ ] Parse 429 response and extract Retry-After header
  - [ ] Display message "Too many reset requests. Please try again in X minutes"
  - [ ] Convert Retry-After seconds to human-readable format
  - [ ] Disable form submission for duration

- [ ] T048 [P] [US4] Create rate limit indicator widget in `frontend/lib/features/password_recovery/widgets/rate_limit_indicator.dart`:
  - [ ] Show countdown timer when rate limited
  - [ ] Update every second
  - [ ] Hide when countdown reaches zero
  - [ ] Enable "Send reset email" button after countdown

- [ ] T049 [P] [US4] Add rate limit error handling test in `frontend/test/password_recovery/providers/password_recovery_provider_test.dart`:
  - [ ] Test parsing Retry-After header
  - [ ] Test state updates with rate limit duration
  - [ ] Test countdown timer triggering

**Checkpoint**: User Story 4 complete - rate limiting prevents abuse

---

## Phase 7: Integration & Cross-Cutting Concerns

**Purpose**: E2E testing, security hardening, performance optimization

**Duration**: 2-3 days

### End-to-End Testing
- [ ] T050 [P] Create full registration → verification → login flow test in `backend/test/integration/e2e_auth_verification_test.dart`:
  - [ ] Register new user → receive verification email
  - [ ] Click verification link → account verified
  - [ ] Log in with verified account → get JWT token
  - [ ] Access protected endpoints

- [ ] T051 [P] Create full forgot password → reset flow test in `backend/test/integration/e2e_password_recovery_test.dart`:
  - [ ] Existing user requests password reset
  - [ ] Receives reset email with link
  - [ ] Clicks link → PasswordResetScreen shown
  - [ ] Enter new password → password updated
  - [ ] Log in with new password → succeeds
  - [ ] Old password no longer works

- [ ] T052 [P] Create multi-scenario E2E test in `backend/test/integration/e2e_comprehensive_test.dart`:
  - [ ] Scenario 1: New user registration → verification → login
  - [ ] Scenario 2: User forgets password → reset → new login
  - [ ] Scenario 3: User resends verification email → old token invalid
  - [ ] Scenario 4: User requests reset 5 times → 6th blocked → wait → succeeds
  - [ ] Scenario 5: User tries expired reset link → re-request → succeeds

### Security Hardening
- [ ] T053 [P] Add CSRF protection to frontend forms in `frontend/lib/features/**/*_screen.dart`:
  - [ ] Already handled by API layer in this mobile app (no CSRF tokens needed for mobile)
  - [ ] Verify secure storage of JWT tokens (already done in Spec 003)

- [ ] T054 [P] Verify no tokens logged in backend in `backend/lib/src/services/*.dart`:
  - [ ] Search all service files for token logging
  - [ ] Remove any debug print statements that might leak tokens
  - [ ] Add logging for successful operations but never log tokens

- [ ] T055 [P] Add timing attack prevention verification in `backend/test/services/token_service_test.dart`:
  - [ ] Test that verification takes same time for valid vs invalid tokens
  - [ ] Verify constant-time comparison is used
  - [ ] Document timing-safe comparison implementation

- [ ] T056 Add security headers middleware in `backend/lib/server.dart`:
  - [ ] Content-Security-Policy for email links
  - [ ] X-Content-Type-Options: nosniff
  - [ ] X-Frame-Options: DENY
  - [ ] Verify no tokens in URLs or headers that could leak

### Performance Optimization
- [ ] T057 [P] Add database indexes verification in `backend/scripts/run_migrations.dart`:
  - [ ] Verify all indexes from data-model.md are created
  - [ ] Test query performance for token lookups (<50ms)
  - [ ] Test email validation queries (<10ms)

- [ ] T058 [P] Performance test for rate limit checks in `backend/test/performance/rate_limit_perf_test.dart`:
  - [ ] Verify rate limit check <10ms per request (1M+ ops/sec)
  - [ ] Load test with 1000 concurrent requests
  - [ ] Verify database connection pooling

- [ ] T059 Add email send retry logic to EmailService in `backend/lib/src/services/email_service.dart`:
  - [ ] Retry failed email sends up to 3 times with exponential backoff
  - [ ] Log retry attempts for troubleshooting
  - [ ] Gracefully handle permanent email delivery failures

### Final Integration & Cleanup
- [ ] T060 Database cleanup: Implement automatic deletion of expired tokens in `backend/lib/src/services/token_service.dart`:
  - [ ] Add scheduled job to delete tokens expired >24 hours ago
  - [ ] Runs once per day to prevent table bloat
  - [ ] Log number of deleted records

- [ ] T061 Update documentation in `backend/ENDPOINT_PATTERNS.md`:
  - [ ] Add email verification endpoints
  - [ ] Add password recovery endpoints
  - [ ] Document deep link format
  - [ ] Document rate limit behavior

- [ ] T062 [P] Update frontend documentation in `frontend/FEATURE_PATTERNS.md`:
  - [ ] Add email verification feature pattern
  - [ ] Add password recovery feature pattern
  - [ ] Document deep linking integration
  - [ ] Document Provider usage for verification state

- [ ] T063 Verify all 50+ test scenarios from checklists/requirements.md in `backend/test/integration/comprehensive_requirements_test.dart`:
  - [ ] Cover all email verification tests (15 tests)
  - [ ] Cover all password recovery tests (15 tests)
  - [ ] Cover all token expiration tests (8 tests)
  - [ ] Cover all rate limiting tests (8 tests)
  - [ ] Cover all security tests (7 tests)

- [ ] T064 Final smoke test: Manual test complete user flows:
  - [ ] Register → email verification → messaging access
  - [ ] Login → forget password → forgot password email → reset password → new login
  - [ ] Verify rate limiting (5 resets per hour)
  - [ ] Verify token expiration (24 hour window)
  - [ ] Test on physical devices (if available) or emulator
  - [ ] Verify deep links work correctly

**Checkpoint**: All user stories tested and integrated; ready for staging deployment

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements, accessibility, documentation

### Accessibility & UX Polish
- [ ] T065 [P] Accessibility review of all screens:
  - [ ] Screen reader support for all form fields
  - [ ] Keyboard navigation for all buttons and inputs
  - [ ] Color contrast meets WCAG AA standards
  - [ ] Form labels properly associated with inputs

- [ ] T066 [P] Error message clarity review:
  - [ ] All error messages are user-friendly (no error codes)
  - [ ] All error messages suggest next actions
  - [ ] No technical jargon in user-facing messages

- [ ] T067 [P] Loading state consistency:
  - [ ] All async operations show loading spinner
  - [ ] Buttons disabled during submission
  - [ ] No double-submissions possible

### Documentation & Troubleshooting
- [ ] T068 [P] Create troubleshooting guide in `specs/015-email-verification-recovery/TROUBLESHOOTING.md`:
  - [ ] "Email not received" - common causes and solutions
  - [ ] "Link expired" - explanation and re-request flow
  - [ ] "Rate limit error" - what is 5 requests per hour and why
  - [ ] "Token invalid" - why tokens expire and security rationale
  - [ ] Testing with fake email service (for development)

- [ ] T069 [P] Create implementation checklist in `specs/015-email-verification-recovery/IMPLEMENTATION_CHECKLIST.md`:
  - [ ] Database migrations applied
  - [ ] Backend services deployed
  - [ ] Email service configured
  - [ ] Frontend screens implemented
  - [ ] Deep linking configured
  - [ ] All 50+ tests passing

- [ ] T070 Document API response examples in `specs/015-email-verification-recovery/API_EXAMPLES.md`:
  - [ ] /auth/send-verification-email request/response
  - [ ] /auth/verify-email request/response
  - [ ] /auth/send-password-reset-email request/response
  - [ ] /auth/reset-password request/response
  - [ ] All error responses (400, 401, 429, 500)

### Final Verification
- [ ] T071 Code review checklist:
  - [ ] All task IDs have corresponding implementation (T001-T070)
  - [ ] All files mentioned in tasks actually exist and contain code
  - [ ] Test coverage >90% for all services
  - [ ] No hardcoded credentials or secrets in code
  - [ ] All endpoints documented in OpenAPI/Swagger format

- [ ] T072 Security verification checklist:
  - [ ] Tokens never logged or exposed in error messages
  - [ ] Password reset invalidates all sessions
  - [ ] Rate limiting prevents brute force attacks
  - [ ] User enumeration is not possible
  - [ ] All tokens expire after 24 hours
  - [ ] Timing-safe comparison prevents timing attacks

- [ ] T073 Final deployment verification:
  - [ ] All migrations run successfully
  - [ ] All endpoints respond correctly
  - [ ] Email service configured and tested
  - [ ] Deep linking works on both Android and iOS
  - [ ] Database backups in place
  - [ ] Monitoring/alerting configured for failed email sends

**Checkpoint**: Feature complete and production-ready

---

## Summary

**Total Tasks**: 73 tasks across 8 phases  
**Duration**: 8-11 days (with parallelization opportunities)  
**Team Size**: 2 backend + 2 frontend developers recommended

### Task Distribution

| Phase | Tasks | Duration | Focus |
|-------|-------|----------|-------|
| Phase 1: Setup | T001-T006 | 1-2 days | Database migrations |
| Phase 2: Foundational | T007-T011 | 2-3 days | Core services (blocking) |
| Phase 3: US1 Email Verification | T012-T023 | 3-4 days | Registration verification |
| Phase 4: US2 Password Recovery | T024-T037 | 3-4 days | Forgotten password flow |
| Phase 5: US3 Link Expiration | T038-T044 | 1-2 days | Handle expired links |
| Phase 6: US4 Rate Limiting | T045-T049 | 1 day | Prevent abuse |
| Phase 7: Integration | T050-T064 | 2-3 days | E2E testing & hardening |
| Phase 8: Polish | T065-T073 | 1-2 days | UX & documentation |

### Parallelization Opportunities

**Phase 2 (Foundational)**:
- T007-T011: All 5 services can be implemented in parallel (different files, no dependencies)
- T007-T011: Tests can also be written in parallel

**Phase 3-6 (User Stories)**:
- All US1, US2, US3, US4 backend tasks can run in parallel after Phase 2 completes
- All US1, US2, US3, US4 frontend tasks can run in parallel after backend APIs defined

**Suggested Team Organization**:
- **Backend Team**: Complete Phase 1 → Phase 2 (all 5 services) → Phase 3-6 endpoints
- **Frontend Team**: Study Phase 2 design → Implement Phase 3-6 screens in parallel with backend work

### MVP Scope (First 5 Days)

Fastest path to MVP (core functionality):
1. Phase 1: Database setup (1 day)
2. Phase 2: Core services (2 days)
3. Phase 3: Email verification complete (2 days)
4. Phase 4: Password recovery - backend only (1 day)

This delivers core value: new users can verify email, verified users have access to features.

---

## Integration Dependencies

- **Spec 003 (Auth)**: Required - email verification and password reset build on existing login/registration
- **Spec 002 (Database Models)**: Required - Users table extension and new entities
- **Database**: PostgreSQL 13+ with functioning migrations framework
- **Email Service**: SendGrid, SMTP, or equivalent must be configured before Phase 1 completes

---

## Testing Summary (50+ Test Scenarios)

See `checklists/requirements.md` for complete testing specification.

**Test Categories**:
- Email Verification: 15 tests
- Password Recovery: 15 tests
- Token Expiration: 8 tests
- Rate Limiting: 8 tests
- Security: 7 tests
- Integration & E2E: 5 tests
- UI/UX: 6 tests
- Edge Cases: 13 tests
- Performance: 6 tests
- Database Integrity: 6 tests

**Total**: 99 test scenarios across unit, integration, E2E, and manual categories.
