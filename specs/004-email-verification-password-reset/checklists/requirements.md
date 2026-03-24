# Spec 004 Requirements Verification Checklist

**Feature**: Email Verification and Password Recovery  
**Spec**: [spec.md](../spec.md) | **Plan**: [plan.md](../plan.md)  
**Last Updated**: March 11, 2026

Use this checklist to verify that implementation meets all specification requirements.

---

## Part 1: Specification Requirements from Input

### Email Verification Features

- [ ] **REQ-001**: User receives verification email after registration
  - **Source**: Spec requirement "users receive email verification link after registration"
  - **Verification**: Check that POST /auth/send-verification-email sends email to user
  - **Test**: Register new user → verify inbox contains email with verification link

- [ ] **REQ-002**: Email verification must be completed before account is fully active
  - **Source**: Spec requirement "user must verify email"
  - **Verification**: Protected endpoints (send message, create chat) reject unverified users
  - **Test**: Register → try to send message without verification → 403 error with message

- [ ] **REQ-003**: Verification link works when clicked
  - **Source**: Spec requirement / user testing scenario
  - **Verification**: Token from email can be used to verify account via POST /auth/verify-email
  - **Test**: Click link in email → account marked as verified → can now send messages

### Password Recovery Features

- [ ] **REQ-004**: Users can initiate password recovery via "Forgot Password" button
  - **Source**: Spec requirement "password reset via email link" / "Forgot Password button"
  - **Verification**: Login screen has "Forgot Password" button → navigates to recovery screen
  - **Test**: Login screen → click "Forgot Password" → password recovery form displayed

- [ ] **REQ-005**: Users receive password reset email with secure link
  - **Source**: Spec requirement "receive password reset email with secure link"
  - **Verification**: POST /auth/send-password-reset-email sends email with reset token
  - **Test**: Enter email → check inbox for password reset email with token

- [ ] **REQ-006**: Users can set new password via reset link
  - **Source**: Spec requirement "set new password via reset link"
  - **Verification**: POST /auth/reset-password accepts token and new password → updates account
  - **Test**: Click reset link → enter new password → confirmation → login with new password

### Security Requirements

- [ ] **REQ-007**: Verification links expire after 24 hours
  - **Source**: Spec requirement "verification... links should expire after 24 hours"
  - **Verification**: Database token has expires_at = created_at + 24 hours
  - **Test**: Create token → verify timestamp logic → generate query for 24h future

- [ ] **REQ-008**: Password reset links expire after 24 hours
  - **Source**: Spec requirement "reset links should expire after 24 hours"
  - **Verification**: Database token has expires_at = created_at + 24 hours
  - **Test**: Create token → verify expiration on backend

- [ ] **REQ-009**: Rate limiting on password reset attempts (max 5 per hour)
  - **Source**: Spec requirement "rate limiting on password reset attempts (max 5 per hour)"
  - **Verification**: RateLimiterService tracks attempts → returns 429 after 5
  - **Test**: Request reset 6 times within 60 minutes → 6th request denied with 429

### Acceptance Test Scenarios

- [ ] **ACC-001**: Register a new account
  - **Verification**: New user record created with email_verified = false
  - **Status**: PASS / FAIL / BLOCKED

- [ ] **ACC-002**: Verify verification email is sent
  - **Verification**: Email in inbox with verification link
  - **Status**: PASS / FAIL / BLOCKED

- [ ] **ACC-003**: Click verification link and confirm account activation
  - **Verification**: Account marked as verified → can use restricted features
  - **Status**: PASS / FAIL / BLOCKED

- [ ] **ACC-004**: Use "Forgot password"
  - **Verification**: Navigate to password recovery, enter email
  - **Status**: PASS / FAIL / BLOCKED

- [ ] **ACC-005**: Receive reset email
  - **Verification**: Email in inbox with reset link
  - **Status**: PASS / FAIL / BLOCKED

- [ ] **ACC-006**: Set a new password via reset link
  - **Verification**: Password updated, account accessible with new password
  - **Status**: PASS / FAIL / BLOCKED

- [ ] **ACC-007**: Confirm login works with new password
  - **Verification**: Login succeeds with new credentials
- **Status**: PASS / FAIL / BLOCKED

---

## Part 2: Implementation Completeness

### Backend Implementation

#### Database Migrations

- [ ] **DB-001**: Migration 007 creates verification_tokens table
  - [ ] Table has correct columns (id, user_id, token_hash, expires_at, used_at, created_at)
  - [ ] UNIQUE index on token_hash
  - [ ] Indexes on user_id and expires_at
  - [ ] Foreign key constraint to users

- [ ] **DB-002**: Migration 008 creates password_reset_tokens table
  - [ ] Identical structure to verification_tokens
  - [ ] All indexes present
  - [ ] Foreign key constraint to users

- [ ] **DB-003**: Migration 009 creates password_reset_attempts table
  - [ ] Columns: id, email, attempted_at
  - [ ] Composite index on (email, attempted_at DESC)

- [ ] **DB-004**: Migration 010 adds verified_at to users table
  - [ ] NEW Column type: TIMESTAMP WITH TIME ZONE, nullable
  - [ ] Indexes on email_verified and verified_at

#### Backend Services

- [ ] **SVC-001**: TokenService implemented
  - [ ] `generateToken()` produces 32-byte Base64URL tokens
  - [ ] `hashToken()` produces SHA256 hash
  - [ ] `verifyTokenHash()` uses timing-safe comparison
  - [ ] `isTokenExpired()` checks expiration

- [ ] **SVC-002**: EmailService implemented
  - [ ] `sendVerificationEmail()` sends via SendGrid or SMTP
  - [ ] `sendPasswordResetEmail()` sends reset link
  - [ ] Retry logic with exponential backoff
  - [ ] Error handling without credential leakage

- [ ] **SVC-003**: RateLimiterService implemented
  - [ ] `trackResetAttempt()` records attempt in database
  - [ ] `isRateLimited()` returns true after 5 attempts/hour
  - [ ] `cleanupExpiredAttempts()` removes old entries

- [ ] **SVC-004**: PasswordResetService implemented
  - [ ] `initiatePasswordReset()` generates token and sends email
  - [ ] `resetPassword()` validates token, hashes password, invalidates sessions
  - [ ] Rate limit enforcement

#### Backend Endpoints

- [ ] **EP-001**: POST /auth/send-verification-email
  - [ ] Accepts authenticated request with user_id
  - [ ] Generates token and sends email
  - [ ] Returns 200 on success
  - [ ] Returns 400 if already verified
  - [ ] Rate limiting implemented

- [ ] **EP-002**: POST /auth/verify-email
  - [ ] Accepts token from request
  - [ ] Validates token exists and not expired
  - [ ] Marks user as verified
  - [ ] Returns 200 with user data on success
  - [ ] Returns 400 for invalid/expired token

- [ ] **EP-003**: POST /auth/send-password-reset-email
  - [ ] Accepts email from request
  - [ ] Rate limit enforcement (429 on limit)
  - [ ] Generic response (user enumeration prevention)
  - [ ] Sends email with reset token

- [ ] **EP-004**: POST /auth/reset-password
  - [ ] Accepts token and new password
  - [ ] Validates token not expired
  - [ ] Validates password strength
  - [ ] Updates password and invalidates sessions
  - [ ] Returns 200 on success with user data

#### Backend Middleware

- [ ] **MW-001**: Rate limit middleware
  - [ ] Tracks password reset attempts per email
  - [ ] Returns 429 Too Many Requests on limit
  - [ ] Includes Retry-After header

### Frontend Implementation

#### Services

- [ ] **FE-SVC-001**: VerificationService
  - [ ] `isEmailVerified()` checks current user status
  - [ ] `resendVerificationEmail()` calls backend endpoint
  - [ ] `verifyEmailWithToken()` submits token and updates auth state

- [ ] **FE-SVC-002**: PasswordRecoveryService
  - [ ] `requestPasswordReset()` sends email to backend
  - [ ] `resetPasswordWithToken()` submits token and new password
  - [ ] Error handling for rate limits

#### Screens

- [ ] **FE-SCR-001**: EmailVerificationScreen
  - [ ] Displays pending verification message
  - [ ] "Resend Verification Email" button
  - [ ] Loading state during resend
  - [ ] Shows error on failure
  - [ ] Redirects on success

- [ ] **FE-SCR-002**: PasswordRecoveryScreen
  - [ ] Email input field
  - [ ] Form validation (email format)
  - [ ] "Send Reset Link" button
  - [ ] Shows generic success message
  - [ ] Handles rate limit (429) errors

- [ ] **FE-SCR-003**: PasswordResetScreen
  - [ ] Token validation on load
  - [ ] New password input with strength indicator
  - [ ] Confirm password input
  - [ ] Shows token expiration warning
  - [ ] "Reset Password" button
  - [ ] Redirects to login on success

#### Navigation

- [ ] **FE-NAV-001**: Deep linking configured
  - [ ] Email verification link → PasswordResetScreen
  - [ ] Password reset link → PasswordResetScreen with token pre-filled
  - [ ] Android AndroidManifest.xml updated
  - [ ] iOS Info.plist updated

- [ ] **FE-NAV-002**: Login screen updated
  - [ ] "Forgot Password" button visible
  - [ ] Button navigates to PasswordRecoveryScreen

- [ ] **FE-NAV-003**: Registration flow updated
  - [ ] After successful registration → EmailVerificationScreen
  - [ ] Cannot proceed until email verified

---

## Part 3: Security Verification

### Cryptographic Security

- [ ] **SEC-001**: Token storage security
  - [ ] Raw tokens never stored in database
  - [ ] Only SHA256 hashes stored
  - [ ] Tokens transmitted via HTTPS only
  - [ ] Tokens never logged in debug output

- [ ] **SEC-002**: Token comparison security
  - [ ] Timing-safe comparison used (not simple ==)
  - [ ] Constant-time algorithm prevents timing attacks
  - [ ] No early exit on mismatch

- [ ] **SEC-003**: Password hashing security
  - [ ] bcrypt with cost factor 10 used (minimum 100ms per hash)
  - [ ] Passwords never stored in plaintext
  - [ ] Passwords never logged

### Rate Limiting & DoS Prevention

- [ ] **SEC-004**: Password reset rate limiting
  - [ ] Limit: 5 attempts per email per hour
  - [ ] Per-email tracking (not IP-based)
  - [ ] Allows legitimate multi-device users
  - [ ] Returns 429 with Retry-After header

- [ ] **SEC-005**: Verification email rate limiting (optional)
  - [ ] Resend limited (e.g., 5 per user per hour)
  - [ ] Prevents email spam from bot accounts

### User Enumeration Prevention

- [ ] **SEC-006**: Email validation doesn't leak users
  - [ ] "Email not found" response identical to "Email found"
  - [ ] Same HTTP status code (200) whether email exists
  - [ ] Same generic response message

- [ ] **SEC-007**: Account verification prevents bots
  - [ ] New accounts cannot send messages until verified
  - [ ] New accounts cannot join chats until verified
  - [ ] Prevents mass bot account creation

### Account Status Enforcement

- [ ] **SEC-008**: Email verification enforcement
  - [ ] All unverified accounts have email_verified = false
  - [ ] Protected operations check email_verified status
  - [ ] Return 403 Forbidden with clear message if unverified

- [ ] **SEC-009**: Session invalidation on password change
  - [ ] All existing JWT tokens revoked on password reset
  - [ ] User must log in again with new password
  - [ ] Old sessions cannot make API calls

### Email Service Security

- [ ] **SEC-010**: Credentials protection
  - [ ] API keys stored in environment variables
  - [ ] `.env` file not committed to git
  - [ ] No credentials visible in logs
  - [ ] HTTPS/TLS used for all email service calls

---

## Part 4: Testing Verification

### Unit Tests

- [ ] **UT-001**: TokenService tests
  - [ ] generateToken produces valid Base64URL strings
  - [ ] hashToken is deterministic
  - [ ] verifyTokenHash returns true for matching tokens
  - [ ] verifyTokenHash returns false for different tokens
  - [ ] isTokenExpired works correctly

- [ ] **UT-002**: RateLimiterService tests
  - [ ] trackResetAttempt inserts record
  - [ ] Attempts counted within 60-minute window
  - [ ] Limit enforced at 5 attempts
  - [ ] Window resets after 60 minutes

- [ ] **UT-003**: PasswordValidator tests
  - [ ] All strength requirements checked
  - [ ] Weak passwords rejected
  - [ ] Strong passwords accepted

### Integration Tests

- [ ] **IT-001**: Verification endpoint tests
  - [ ] send-verification-email creates token and sends email
  - [ ] verify-email with valid token marks user as verified
  - [ ] verify-email with invalid token returns error
  - [ ] verify-email with expired token returns error
  - [ ] verify-email is idempotent (already verified)

- [ ] **IT-002**: Password recovery endpoint tests
  - [ ] send-password-reset-email sends email with token
  - [ ] send-password-reset-email enforces rate limit (5/hour)
  - [ ] reset-password with valid token updates password
  - [ ] reset-password with invalid token returns error
  - [ ] reset-password invalidates all existing sessions

- [ ] **IT-003**: Database constraint tests
  - [ ] UNIQUE token_hash constraint enforced
  - [ ] Foreign key constraints work
  - [ ] Cascade deletes function properly
  - [ ] CHECK constraints validate data

### Widget Tests

- [ ] **WT-001**: EmailVerificationScreen
  - [ ] Displays pending message
  - [ ] Resend button works
  - [ ] Loading state shown during resend
  - [ ] Error message displayed on failure

- [ ] **WT-002**: PasswordRecoveryScreen
  - [ ] Email field accepts input
  - [ ] Email validation works
  - [ ] Form submission works
  - [ ] Generic success message shown
  - [ ] Rate limit error handled

- [ ] **WT-003**: PasswordResetScreen
  - [ ] Password fields accept input
  - [ ] Password strength indicator shown
  - [ ] Password confirmation validation works
  - [ ] Form submission works
  - [ ] Token expiration warning shown

### Integration/E2E Tests

- [ ] **E2E-001**: Full registration to verification flow
  - [ ] Register new account
  - [ ] Receive verification email
  - [ ] Extract token from email
  - [ ] Click link / submit token
  - [ ] Account verified successfully
  - [ ] Can now access restricted features

- [ ] **E2E-002**: Password recovery flow
  - [ ] Click "Forgot Password"
  - [ ] Enter email
  - [ ] Receive password reset email
  - [ ] Extract token
  - [ ] Click link / navigate to reset screen
  - [ ] Enter new password
  - [ ] Password updated successfully
  - [ ] Login with new password succeeds

- [ ] **E2E-003**: Rate limit enforcement
  - [ ] Request password reset 6 times within 1 hour
  - [ ] 6th request blocked with 429 error
  - [ ] Wait 1 hour
  - [ ] New request succeeds

- [ ] **E2E-004**: Session invalidation
  - [ ] Login as user
  - [ ] Request password reset
  - [ ] Reset password
  - [ ] Original session token no longer works
  - [ ] Must login again with new password

---

## Part 5: Deployment Verification

### Docker Build & Run

- [ ] **DEP-001**: Backend Docker build
  - [ ] `docker build -t messenger-backend .` succeeds
  - [ ] Image includes all dependencies
  - [ ] Migrations run on startup

- [ ] **DEP-002**: Docker Compose execution
  - [ ] `docker-compose up` starts all services
  - [ ] Backend health check passes
  - [ ] PostgreSQL initialized
  - [ ] Migrations applied automatically
  - [ ] All 4 endpoints accessible

### Environment Configuration

- [ ] **DEP-003**: Environment variables
  - [ ] SENDGRID_API_KEY configured
  - [ ] SMTP credentials optional
  - [ ] Frontend URL set correctly
  - [ ] Backend URL set correctly
  - [ ] Token expiration configured

### Health & Monitoring

- [ ] **DEP-004**: Backend health check
  - [ ] Endpoint returns 200 with health data
  - [ ] Database connectivity verified
  - [ ] Email service accessible

---

## Part 6: Documentation Verification

### API Documentation

- [ ] **DOC-001**: OpenAPI specification
  - [ ] All 4 endpoints documented
  - [ ] Request/response schemas defined
  - [ ] Error responses documented
  - [ ] Status codes correct

### Developer Documentation

- [ ] **DOC-002**: Quickstart guide
  - [ ] Setup instructions complete
  - [ ] Code examples provided
  - [ ] Testing procedures documented
  - [ ] Troubleshooting guide included

### User Documentation

- [ ] **DOC-003**: User-facing docs (if applicable)
  - [ ] Verification flow explained
  - [ ] Password recovery explained
  - [ ] FAQ section

---

## Part 7: Sign-Off

### Code Review

- [ ] [ ] Backend code reviewed (TokenService, EmailService, RateLimiterService)
- [ ] [ ] Frontend code reviewed (Services, Screens, Navigation)
- [ ] [ ] Security review completed
- [ ] [ ] Performance review completed
- [ ] [ ] Database migrations verified

### Testing Sign-Off

- [ ] [ ] All unit tests pass
- [ ] [ ] All integration tests pass
- [ ] [ ] All E2E tests pass
- [ ] [ ] No known regressions
- [ ] [ ] No critical bugs

### Acceptance Sign-Off

- [ ] [ ] Product owner approves feature
- [ ] [ ] All acceptance test scenarios pass
- [ ] [ ] Performance metrics met
- [ ] [ ] Security requirements met
- [ ] [ ] Documentation complete

### Deployment Sign-Off

- [ ] [ ] Code merged to main branch
- [ ] [ ] Docker image built and pushed
- [ ] [ ] Deployed to staging environment
- [ ] [ ] Smoke tests pass in staging
- [ ] [ ] Ready for production deployment

---

## Notes & Issues

### Issues Found During Implementation
(To be filled during implementation)

| Issue | Severity | Status | Resolution |
|-------|----------|--------|------------|
|       |          |        |            |

### Deviations from Plan
(To be noted if any changes needed)

| Deviation | Reason | Approval |
|-----------|--------|----------|
|           |        |          |

---

## Summary

**Total Requirements**: 50+  
**Completed**: [ ] / [ ]  
**Pass Rate**: [ ]%  

**Overall Status**: [ ] PASS / [ ] FAIL / [ ] BLOCKED

**Sign-Off**: _________________________ Date: _______

