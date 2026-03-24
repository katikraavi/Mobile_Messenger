# Feature Specification: Email Verification and Password Recovery

**Feature Branch**: `015-email-verification-recovery`  
**Created**: 2026-03-11  
**Status**: Draft  
**Input**: Users receive email verification link after registration. Email verification must be completed before account is fully active. Password recovery flow via "Forgot Password" button. Users receive password reset email with secure link. Users can set new password via reset link. Security: verification and reset links should expire after 24 hours. Rate limiting on password reset attempts (max 5 per hour)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Email Verification After Registration (Priority: P1)

A newly registered user completes the registration process and must verify their email address before accessing features. They receive a verification email with a secure link, click the link within 24 hours, and their account becomes fully active.

**Why this priority**: Email verification is critical for account security and validity. It prevents spam registrations, ensures users have access to their registered email, and provides a channel for future account recovery communications. This should be completed immediately after registration.

**Independent Test**: Can be fully tested by: registering a new account, receiving a verification email, clicking the verification link, and confirming account is now in active state. Delivers core value of validated, trustworthy user accounts.

**Acceptance Scenarios**:

1. **Given** user completes registration with valid credentials, **When** registration is confirmed, **Then** system sends verification email to registered email address and marks account as "pending verification"
2. **Given** account in pending verification state with valid verification link sent, **When** user clicks verification link within 24 hours, **Then** account transitions to "verified" and user receives success confirmation message
3. **Given** user in pending verification state, **When** they attempt to access app features (not login screen), **Then** system displays message "Please verify your email to continue" and prevents access to core features
4. **Given** pending verification user, **When** they resend verification email request, **Then** system sends new verification email and previous links are invalidated
5. **Given** user with verified account, **When** they log out and log in again, **Then** they have full access to all app features without re-verification

---

### User Story 2 - Forgotten Password Recovery (Priority: P1)

A registered user forgets their password and cannot log in. They click "Forgot Password", enter their email, receive a password reset email with a secure link, click the link, and set a new password. Their account is immediately accessible with the new password.

**Why this priority**: P1 because password recovery is essential for user retention and account security. Without this flow, users with forgotten passwords are permanently locked out, creating negative experience and potential account abandonment.

**Independent Test**: Can be fully tested by: requesting password reset, receiving reset email, clicking reset link, entering new password, and logging in with new credentials. Delivers core value of account recovery and user accessibility.

**Acceptance Scenarios**:

1. **Given** user on login screen with forgotten password, **When** user clicks "Forgot Password" button, **Then** system displays email input form with clear instructions
2. **Given** forgot password form with valid registered email, **When** user enters email and submits, **Then** system displays "Check your email for reset link" message and sends password reset email
3. **Given** user with valid password reset link sent, **When** user clicks reset link within 24 hours, **Then** system displays secure password reset form (without requiring current password entry)
4. **Given** password reset form displayed, **When** user enters new valid password (meeting strength requirements) and confirms it, **Then** password is updated and user receives success message with prompt to log in
5. **Given** user with newly reset password, **When** they log in with email and new password, **Then** login succeeds and user is fully authenticated
6. **Given** user with reset account, **When** they log in with email and old password, **Then** login fails with "Invalid email or password" error

---

### User Story 3 - Reset Link Expiration and Re-request (Priority: P2)

A user attempts to use a password reset link but finds it expired after 24 hours. The system clearly indicates the link is expired and provides an easy way to request a new reset link without struggling.

**Why this priority**: P2 because while critical for security (expiration), most users will complete reset within 24 hours. However, handling expired gracefully is important for user experience.

**Independent Test**: Can be independently tested by: requesting reset, waiting/simulating 24+ hour passage, attempting to use expired link, and verifying user can easily request a new one. Delivers security value.

**Acceptance Scenarios**:

1. **Given** user with password reset link sent 24+ hours ago, **When** they click the expired reset link, **Then** system displays "This link has expired" message with clear reason (expires after 24 hours)
2. **Given** user on expired reset link page, **When** they click "Request new reset link" button, **Then** system sends a fresh password reset email immediately
3. **Given** user tries to use old reset link twice, **When** link becomes invalid from first use attempt, **Then** subsequent uses display expired/invalid link message

---

### User Story 4 - Rate Limited Password Reset Requests (Priority: P2)

A user attempts multiple password reset requests in quick succession. After 5 reset attempts within 1 hour, the system temporarily blocks additional reset requests to prevent abuse while clearly communicating the limit and when they can try again.

**Why this priority**: P2 because while important for security against brute force and spam, it doesn't block successful reset flow for legitimate users who follow normal process.

**Independent Test**: Can be tested by: submitting 5 password reset requests within 1 hour, verifying 6th request is blocked, and confirming user can try again after 1 hour. Delivers security value.

**Acceptance Scenarios**:

1. **Given** user submits password reset request, **When** they submit 5 successful reset requests within a 1-hour window, **Then** all 5 emails are sent normally
2. **Given** user has submitted 5 reset requests in the past hour, **When** they attempt a 6th reset request, **Then** system displays "Too many reset requests. Please try again in [X minutes]" message
3. **Given** user is rate-limited, **When** 1 hour passes since the oldest reset request, **Then** the rate limit counter resets and user can submit a new reset request
4. **Given** rate limit tracking, **When** user successfully completes a password reset (creates new password), **Then** rate limit counter is cleared for that user

### Edge Cases

- What happens when verification or reset email fails to send (mail server down)? (System should retry and display error to user)
- How does system handle user clicking verification link multiple times within valid period? (Should succeed each time or show already-verified)
- What if user emails themselves the reset link and forwards it to someone else before clicking? (Link should work once, then invalidate)
- What happens if user changes email address during pending verification - does old email still verify? (Should only verify current email on account)
- How does system handle verification/reset token database storage - should tokens be hashed like passwords? 
- What if user tries to verify with email but email is now registered to different account? (Should fail or explain clearly)
- What happens when user's device lacks internet to receive verification/reset emails?
- What if user receives reset email but doesn't have email client configured on device? (Should provide option to copy link or use recovery codes)
- How does system handle timezone differences in token expiration? (Should use UTC consistently)
- If user requests verification email multiple times, should they receive multiple emails or have a rate limit?
- What if user tries to set the same password they're currently locked out with? (Should allow or prevent?)

## Requirements *(mandatory)*

### Functional Requirements

**Email Verification Flow**

- **FR-001**: System MUST send verification email to user's registered email address immediately after successful registration
- **FR-002**: System MUST include secure, unique verification link in verification email
- **FR-003**: System MUST mark newly registered accounts as "pending verification" and prevent access to core messaging features until verified
- **FR-004**: System MUST transition account to "verified" state when verification link is successfully clicked within expiration window
- **FR-005**: System MUST invalidate all previous verification links when a new verification email is sent
- **FR-006**: System MUST display clear success message upon successful email verification
- **FR-007**: System MUST allow users to request resend of verification email if original verification link is lost
- **FR-008**: System MUST prevent access to chat/messaging features for accounts in "pending verification" state with clear messaging about verification requirement

**Password Recovery Flow**

- **FR-009**: System MUST provide "Forgot Password" button or link on login screen
- **FR-010**: System MUST display email input form when "Forgot Password" is accessed
- **FR-011**: System MUST accept email address in forgot password form and validate format
- **FR-012**: System MUST send password reset email to provided email address if account exists (without revealing whether email is registered for security)
- **FR-013**: System MUST include secure, unique password reset link in reset email
- **FR-014**: System MUST accept password reset link clicks and display secure password reset form
- **FR-015**: System MUST NOT require user to enter current password in password reset form (link itself is proof of identity)
- **FR-016**: System MUST apply same password strength requirements to reset password as registration password (8+ chars, lowercase, uppercase, digit, special character)
- **FR-017**: System MUST validate password reset token before allowing password change
- **FR-018**: System MUST update user's password hash (according to same security standards as registration) upon successful reset
- **FR-019**: System MUST invalidate all previous password reset links for a user when password is successfully reset
- **FR-020**: System MUST display success message upon successful password reset with prompt to log in with new password

**Token Expiration**

- **FR-021**: System MUST set expiration time of 24 hours (86,400 seconds) for both verification and password reset tokens
- **FR-022**: System MUST reject any attempt to use verification or password reset token after 24 hours with clear "link expired" message
- **FR-023**: System MUST display expiration time in user-friendly format in emails (e.g., "This link expires in 24 hours")
- **FR-024**: System MUST use consistent UTC timezone for all token expiration calculations
- **FR-025**: System MUST include "Request new link" option when token is expired, allowing user to get fresh token without returning to login screen

**Rate Limiting**

- **FR-026**: System MUST track password reset requests per user account
- **FR-027**: System MUST allow up to 5 password reset emails per user per 1-hour sliding window
- **FR-028**: System MUST display rate limit error message when user exceeds 5 requests per hour with specific wait time (e.g., "Try again in 42 minutes")
- **FR-029**: System MUST NOT send password reset email if user has exceeded rate limit, but must display clear message
- **FR-030**: System MUST reset rate limit counter after 1 hour from the oldest reset request in the window
- **FR-031**: System MUST clear rate limit counter when user successfully resets password and logs in

**Security & Data Handling**

- **FR-032**: System MUST use cryptographically secure random token generation for verification and reset links (unguessable, minimum 256-bit entropy)
- **FR-033**: System MUST not log or expose verification/reset tokens in any logs or error messages
- **FR-034**: System MUST use HTTPS/secure protocols for all verification and reset link endpoints
- **FR-035**: System MUST handle failed verification/reset attempts securely without revealing whether email is registered (timing attack resistance)
- **FR-036**: System MUST implement CSRF protection for password reset form
- **FR-037**: System MUST not allow account access during verification completion (no automatic login upon verification click)

### Key Entities

- **User Account**: Extended state to include "verified_at" timestamp and "pending_verification" flag; initially empty/null until verification
- **Email Verification Token**: Unique cryptographic token tied to user, includes creation timestamp, expiration (24 hours), one-time use flag
- **Password Reset Token**: Unique cryptographic token tied to user, includes creation timestamp, expiration (24 hours), one-time use flag
- **Reset Request Log**: Tracks password reset requests per user for rate limiting; includes timestamp for sliding 1-hour window calculation
- **Email Queue/Log**: System record of sent verification and reset emails; supports retry logic and troubleshooting without exposing sensitive tokens

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 90% of users successfully verify their email within 24 hours of registration
- **SC-002**: User receives verification email within 2 minutes of registration completion
- **SC-003**: Verification link is valid and functional for full 24-hour expiration window
- **SC-004**: Users are unable to access messaging features in pending verification state (core feature access blocked 100%)
- **SC-005**: Password reset email is received within 2 minutes of "Forgot Password" request
- **SC-006**: Users successfully reset forgotten passwords on first attempt 85% of the time
- **SC-007**: Password reset process completes from link click to new login in under 3 minutes for successful attempts
- **SC-008**: Rate limit (5 attempts/hour) successfully blocks excess password reset requests while allowing legitimate use
- **SC-009**: All verification/reset tokens expire within 24-25 hours from generation (no tokens remain usable after 24 hours)
- **SC-010**: System prevents use of invalid/expired tokens 100% of the time with clear user communication
- **SC-011**: Password strength validation is consistent between registration and password reset (no bypass possible through reset)
- **SC-012**: Unregistered email addresses in password recovery form receive no indication email is not registered (security: timing attack resistant)

## Assumptions

- **Email Service**: System has access to reliable email sending service (e.g., SendGrid, AWS SES, etc.) with ability to send 100+ emails per second
- **User Email Validity**: Users provide valid, deliverable email addresses during registration. Bounced emails are out of scope for verification retry.
- **HTTPS Infrastructure**: All endpoints are served over HTTPS; non-HTTPS links in emails will cause failures
- **Database Persistence**: Email verification/reset tokens are persisted in database with automatic cleanup of expired tokens (or cleanup is handled later)
- **Timezone Handling**: Backend uses UTC internally; expiration is consistently calculated in UTC regardless of user's local timezone
- **No SMS Option**: Specification assumes email-only verification/reset; SMS is not in scope
- **Token Length**: Reset/verification tokens are designed to be unguessable; minimum 256-bit entropy assumed achievable
- **Existing Auth State**: Assumes Spec 003 (User Authentication Flow) is implemented with secure session management and password hashing
- **Email Resend UI**: User can request resend of verification email from non-verified state (UI supports this flow)
- **Rate Limiting Scope**: Rate limit is per-account; doesn't consider IP-level abuse (IP-level DoS prevention out of scope)
- **Backward Compatibility**: Users with accounts created before this feature exist in "verified" state by migration/default
- **No Account Lock**: Failed verification attempts don't lock account; user can always request new verification email

## Security Considerations

- **Token Generation**: Tokens MUST be generated using cryptographically secure random functions (e.g., `SecureRandom` in Java, `secrets` in Python, `crypto.randomBytes` in Node.js). Non-secure randomization is a critical vulnerability.
- **Token Storage**: Tokens MUST be hashed in database similar to passwords - never stored in plain text. This prevents attackers who compromise database from using tokens directly.
- **CSRF Protection**: Password reset form MUST include CSRF tokens to prevent cross-site request forgery attacks
- **Timing Attack Resistance**: Forgot password endpoint should not reveal whether email is registered by responding differently (same response time/content for registered and unregistered emails)
- **Token Reuse Prevention**: Once a token is used (either successfully or unsuccessfully), it is invalidated immediately and cannot be reused
- **No Automatic Login**: Email verification should NOT automatically log user in; user should verify then explicitly log in to confirm new password works
- **Rate Limiting**: Rate limit prevents brute force password reset attacks. Sliding window implementation preferred over fixed windows to prevent reset storms
- **Email Content**: Reset and verification emails should NOT contain sensitive information like password hints, previous passwords, or temporary passwords
- **Link Construction**: Links should be constructed on backend, not client, to prevent parameter tampering
- **Token Scope**: Verification tokens and reset tokens should be separate entity types; a compromised verification token should not enable password reset
- **Logging**: Do not log or display verification/reset tokens in any system logs. Log successful/failed verification/reset attempts without tokens.

## Remaining Clarifications

The following aspects were determined by reasonable defaults based on common security practices in messenger applications:

1. **Email Service Integration**: Assumed to use industry-standard email service provider
2. **Token Format**: Tokens will be cryptographically random, unguessable strings (exact format to be determined at implementation)
3. **Automatic Cleanup**: Expired tokens will be cleaned from database (schedule TBD at implementation)
4. **User Notification**: User will be notified of password resets; exact notification mechanism (in-app alert vs email) to be determined
5. **Account Access During Verification**: Non-verified accounts will see messaging features blocked; exact UI treatment (splash screen, disabled buttons, empty state) to be determined at implementation
