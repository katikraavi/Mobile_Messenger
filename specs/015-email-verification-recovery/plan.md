# Implementation Plan: Email Verification & Password Recovery

**Branch**: `015-email-verification-recovery` | **Date**: 2026-03-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/015-email-verification-recovery/spec.md`

**Note**: This plan is executed by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Email verification and password recovery flows enabling users to verify email addresses after registration and securely reset forgotten passwords. The system uses time-limited (24-hour) cryptographically secure tokens stored as SHA256 hashes in the database, enforces rate limiting (5 requests/hour for password reset), and provides secure email-based verification without exposing verification status or registered email addresses. Implementation spans backend service layer (TokenService, VerificationService, PasswordResetService, RateLimitService) with 4 new database tables, 4 API endpoints, and frontend screens for verification and password recovery flows.

## Technical Context

**Language/Version**: Dart (backend), Flutter (frontend) | **Backend Framework**: Serverpod/Shelf | **Frontend Framework**: Flutter (Riverpod for state management)  
**Primary Dependencies**: 
- Backend: `shelf_router`, `postgres`, `mailer` (or SendGrid), `crypto` (for token hashing)
- Frontend: `flutter_riverpod`, `go_router`, `http`

**Storage**: PostgreSQL (existing database from Spec 002-003) + 4 new tables (VerificationToken, PasswordResetToken, PasswordResetAttempt, User extension)  
**Testing**: Dart `test` package (backend unit/integration), Flutter `flutter_test` (frontend widget tests)  
**Target Platform**: Android/iOS via Flutter, Serverpod backend via Docker  
**Project Type**: Mobile app (Flutter) + REST API backend (Dart/Shelf)  
**Performance Goals**: Email delivery <2 min, token verification <300ms, password reset flow completion <3 min  
**Constraints**: 24-hour token expiration (single-use), 5 password resets per 1-hour sliding window per user/email, no plaintext token storage  
**Scale/Scope**: Spec 002-003 users (shared User table), 2 new UI screens (VerificationScreen, PasswordRecoveryScreen, PasswordResetScreen), 4 service classes, 4 endpoints

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Security-First (NON-NEGOTIABLE)
**Status**: ✅ PASS (with design verification needed)
- ✅ Cryptographically secure token generation (256-bit entropy minimum): TokenService class required
- ✅ Token hashing before database persistence: SHA256 hashing in TokenService + database schema CHECK constraint
- ✅ No plaintext tokens in logs: Service layer logging restrictions
- ✅ HTTPS/secure protocols: Inherited from Spec 003 auth middleware
- ✅ Timing-attack resistant comparison: Dart `crypto` package provides constant-time comparison
- **Design verification needed**: Email service integration (SendGrid/SMTP) security, CSRF token validation

### Principle III: Testing Discipline (NON-NEGOTIABLE)
**Status**: ✅ PASS (tasks to be generated in Phase 2)
- ✅ Unit tests: TokenService, VerificationService, PasswordResetService, RateLimitService (minimum 40 test cases)
- ✅ Integration tests: 4 endpoints (send verification, verify, send reset, reset password) 
- ✅ E2E tests: Full verification flow, full password recovery flow, rate limiting validation
- ✅ Manual UI testing: VerificationScreen, PasswordRecoveryScreen, PasswordResetScreen

### Principle II: End-to-End Architecture Clarity
**Status**: ✅ PASS
- ✅ Clear service layer separation: TokenService, VerificationService, PasswordResetService, RateLimitService
- ✅ API contract clarity: 4 endpoints defined with request/response schemas
- ✅ Frontend/backend communication via HTTP REST (no new WebSocket patterns)
- ✅ Database schema clearly defined: 4 new tables with explicit constraints

### Principle IV: Code Consistency & Naming Standards
**Status**: ✅ PASS
- Follows existing Spec 002-003 patterns (service-based, model serialization, endpoint handlers)
- Naming conventions: camelCase (Dart), consistent with project

### Principle V: Delivery Readiness
**Status**: ✅ PASS
- All deliverables documented in this plan (Phase 1 outputs: data-model.md, contracts/, quickstart.md)
- Tasks will be generated in Phase 2 with clear acceptance criteria

## Project Structure

### Documentation (this feature)

```text
specs/015-email-verification-recovery/
├── spec.md              # Feature specification (user stories, requirements)
├── plan.md              # This file (technical implementation plan)
├── research.md          # Phase 0 output (research findings, decisions)
├── data-model.md        # Phase 1 output (database schema, migrations)
├── quickstart.md        # Phase 1 output (code templates, implementation guide)
├── contracts/           # Phase 1 output (API contracts, data models)
│   ├── verification-endpoints.yaml    # OpenAPI 3.0 spec (4 endpoints)
│   └── token-data-models.md           # VerificationToken, PasswordResetToken schemas
└── checklists/          # Phase 4 output (test checklists, acceptance criteria)
    └── requirements.md  # 50+ test scenarios & acceptance criteria
```

### Source Code (repository root)

```text
backend/
├── lib/src/
│   ├── models/
│   │   ├── verification_token.dart      # VerificationToken model + serialization
│   │   ├── password_reset_token.dart    # PasswordResetToken model + serialization
│   │   └── password_reset_attempt.dart  # PasswordResetAttempt model (rate limiting)
│   ├── services/
│   │   ├── token_service.dart           # Secure token generation + SHA256 hashing
│   │   ├── verification_service.dart    # Verify token logic, email resend
│   │   ├── password_reset_service.dart  # Password reset token lifecycle
│   │   ├── rate_limit_service.dart      # 5/hour sliding window tracking
│   │   ├── email_service.dart           # Send verification + reset emails
│   │   └── database_service.dart        # (MODIFIED - add 4 new tables)
│   ├── middleware/
│   │   └── auth_middleware.dart         # (MODIFIED - verify before password reset)
│   ├── endpoints/
│   │   ├── verification_handler.dart    # POST /verify/send, POST /verify/confirm
│   │   └── password_reset_handler.dart  # POST /password/reset/request, POST /password/reset/confirm
│   └── server.dart                      # (MODIFIED - register new endpoints)
├── migrations/
│   ├── 013_create_verification_token_table.dart
│   ├── 014_create_password_reset_token_table.dart
│   ├── 015_create_password_reset_attempt_table.dart
│   └── 016_extend_user_table_add_verified_at.dart
└── test/
    ├── unit/
    │   ├── token_service_test.dart       # Token generation, validation, hashing
    │   ├── rate_limit_service_test.dart  # 5/hour sliding window, counter reset
    │   └── verification_service_test.dart # Token expiration, single-use enforcement
    └── integration/
        ├── verification_integration_test.dart     # Send, resend, verify flows
        └── password_reset_integration_test.dart   # Request, rate limit, reset flows

frontend/
├── lib/features/verification/
│   ├── screens/
│   │   ├── email_verification_screen.dart       # Display verification status + resend button
│   │   ├── password_recovery_screen.dart        # Email input form for forgot password
│   │   └── password_reset_screen.dart           # Password reset form (token-gated)
│   ├── providers/
│   │   ├── verification_provider.dart           # Riverpod provider for verification status
│   │   ├── password_recovery_provider.dart      # Password recovery form state
│   │   └── password_reset_provider.dart         # Password reset form state
│   ├── services/
│   │   ├── verification_service.dart            # HTTP wrapper for verification endpoints
│   │   └── password_reset_service.dart          # HTTP wrapper for password reset endpoints
│   └── widgets/
│       ├── resend_verification_button.dart      # Resend verification email button
│       └── countdown_timer.dart                 # Timer showing seconds until button active
└── test/
    ├── features/verification/screens/
    │   ├── email_verification_screen_test.dart
    │   ├── password_recovery_screen_test.dart
    │   └── password_reset_screen_test.dart
    └── features/verification/providers/
        └── verification_provider_test.dart
```

**Structure Decision**: Option 2 (Backend API + Flutter Mobile frontend). Spec 015 follows existing Spec 002-003 patterns with service-layer abstraction, database integration via migrations, REST endpoints, and Riverpod state management on frontend.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
