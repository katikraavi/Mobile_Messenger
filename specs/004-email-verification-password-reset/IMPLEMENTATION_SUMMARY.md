# Spec 004 Implementation Plan Summary

**Feature**: Email Verification and Password Recovery  
**Branch**: `004-email-verification-password-reset`  
**Date**: March 11, 2026  
**Status**: ✅ Phase 1 Planning Complete

## Overview

Comprehensive implementation plan for secure email verification and password recovery flows in the Mobile Messenger application. This specification builds upon Spec 001 (project init), Spec 002 (database models), and Spec 003 (user authentication) to add email verification requirements and password reset functionality.

## Artifacts Generated

### 📋 Planning Documents

1. **[plan.md](plan.md)** - Main implementation plan
   - Summary and technical context
   - Constitution check (security, architecture, testing, consistency)
   - Project structure for backend and frontend
   - Data model design and schema additions
   - API contract design (4 endpoints)
   - Backend architecture and services
   - Frontend architecture and screens
   - Implementation phases (Phase 1-3 with tasks)
   - Testing strategy (unit, integration, E2E)
   - Security implementation details
   - Success metrics and acceptance criteria
   - **Length**: 1,200+ lines of detailed specifications

2. **[data-model.md](data-model.md)** - Schema design details
   - 4 new entities: VerificationToken, PasswordResetToken, PasswordResetAttempt, Users extension
   - Entity relationships and constraints
   - Database migration SQL scripts
   - Data access patterns
   - Performance considerations
   - Security implications
   - **Length**: 600+ lines of schema documentation

3. **[quickstart.md](quickstart.md)** - Developer quickstart guide
   - Backend setup instructions (migrations, services, endpoints)
   - Frontend setup (screens, services, deep linking)
   - End-to-end testing procedures
   - Troubleshooting guide
   - Code examples for all major services
   - **Length**: 400+ lines of practical implementation guidance

### 🔌 API Contracts

4. **[contracts/verification-endpoints.yaml](contracts/verification-endpoints.yaml)** - OpenAPI 3.0 specification
   - Complete REST API specification
   - 4 endpoints (send-verification, verify-email, send-password-reset, reset-password)
   - Request/response schemas with examples
   - Error scenarios and rate limiting
   - Security requirements (bearer token, etc.)
   - HTTP status codes and headers

## Key Design Decisions

### Security
- ✅ **Token Security**: 256-bit randomly generated tokens, SHA256 hashing, timing-safe comparison
- ✅ **Rate Limiting**: 5 password reset attempts per email per hour (prevents brute force)
- ✅ **Session Invalidation**: All JWT tokens revoked on password change
- ✅ **User Enumeration Prevention**: Identical responses for existing/non-existing emails
- ✅ **Account Status Enforcement**: Protected operations require email verification

### Architecture
- ✅ **Backend**: 4 new endpoints, 4 new services (Token, Email, RateLimiter, PasswordReset)
- ✅ **Frontend**: 2 new screens (EmailVerification, PasswordRecovery), 2 new services
- ✅ **Database**: 4 new tables, 1 user table extension
- ✅ **Expiration**: 24-hour token lifetime with automatic cleanup

### Integration
- ✅ **Seamless with Spec 003**: Extends existing auth flow without breaking changes
- ✅ **Deep Linking**: Email links redirect to frontend reset/verification screens
- ✅ **Deployment**: Docker-based deployment via docker-compose

## Implementation Roadmap

### Phase 1: Backend Infrastructure (3-4 days)
```
├─ Create database migrations (4 migrations)
├─ Implement services (TokenService, EmailService, RateLimiterService, PasswordResetService)
├─ Create API endpoints (4 endpoints)
├─ Implement rate-limit middleware
└─ Backend integration tests (token, email, rate limit, endpoint tests)
```

### Phase 2: Frontend UI (3-4 days)
```
├─ Implement services (VerificationService, PasswordRecoveryService)
├─ Create screens (EmailVerificationScreen, PasswordRecoveryScreen, PasswordResetScreen)
├─ Update navigation and routing
├─ Configure deep linking (Android + iOS)
└─ Frontend widget and integration tests
```

### Phase 3: Integration Testing & Deployment (2-3 days)
```
├─ Full E2E tests (registration → verification → login)
├─ Password recovery flow tests
├─ Rate limiting enforcement verification
├─ Security testing (token manipulation, timing attacks)
├─ Docker deployment verification
└─ Documentation and demo
```

## Testing Coverage

### Unit Tests
- ✅ TokenService: Generation, hashing, timing-safe comparison, expiration
- ✅ RateLimiterService: Attempt tracking, window logic, limit enforcement
- ✅ EmailService: Template rendering, retry logic, error handling
- ✅ Form validation: Password strength, email format

### Integration Tests
- ✅ Endpoint testing: All success and error paths
- ✅ Database constraints: UNIQUE tokens, expiration, cascade deletes
- ✅ Rate limiting: 5 attempts/hour enforcement
- ✅ Email delivery: Mock and real SendGrid integration

### E2E Tests
- ✅ Full registration → verification → login flow
- ✅ Password recovery → reset → new login
- ✅ Session invalidation after password reset
- ✅ Deep linking from email to app

### Acceptance Criteria
- ✅ 100% of Spec requirements met
- ✅ All endpoints tested and working
- ✅ Rate limiting enforced
- ✅ Tokens expire after 24 hours
- ✅ Account operations require verification
- ✅ Sessions invalidated on password reset

## Database Schema Summary

### New Tables
| Table | Rows | Purpose |
|-------|------|---------|
| `verification_tokens` | 1-2 per user | Email verification tokens |
| `password_reset_tokens` | Multiple | Password reset tokens |
| `password_reset_attempts` | ~10K/day | Rate limit tracking |
| `users.verified_at` | Extension | Audit trail for verification |

### Total Schema Overhead
- Per user: +24 bytes (verified_at)
- Per attempt: +50 bytes (tracking)
- Negligible compared to existing schema

## Security Checklist

- [x] Token generation uses cryptographically secure random
- [x] Tokens hashed with SHA256 before database storage
- [x] Timing-safe comparison prevents timing attacks
- [x] Rate limiting prevents brute force attacks
- [x] User enumeration prevention (identical responses)
- [x] Account status enforcement
- [x] Session invalidation on password change
- [x] Email service credentials protected (env variables)
- [x] HTTPS/TLS enforced for all communications
- [x] Passwords never logged or displayed

## Performance Targets

| Operation | Target | Notes |
|-----------|--------|-------|
| Token generation | <100ms | Acceptable for async task |
| Token validation | <50ms | Database UNIQUE index lookup |
| Rate limit check | <50ms | Composite index on email/time |
| Password update | <1s | Includes bcrypt hashing |
| Email delivery | <5s | SendGrid rate: ~5ms/email |
| Verification UI response | <2s | Network + server |

## Dependencies & Prerequisites

### External Services
- SendGrid API account (or SMTP server)
- PostgreSQL 13+ database
- Docker & Docker Compose

### Dart Packages
- **Backend**: `shelf`, `shelf_router`, `postgres`, `uuid`, `crypto`, `dotenv`
- **Frontend**: `provider`, `flutter_secure_storage`, form validators

### Configuration
- Email service API key or SMTP credentials
- Backend URL for token links
- Frontend URL for deep linking
- Token expiration duration
- Rate limit thresholds

## Future Enhancements

### Short-term (Next Sprint)
- Two-factor authentication (SMS OTP)
- Backup recovery codes
- IP-based anomaly detection

### Medium-term
- Email preference center
- Multiple recovery email addresses
- Advanced audit logging

### Long-term
- Device management and registration
- Compromised password detection
- Subscription and compliance features

## Known Limitations

### Current Implementation
- Email-only recovery (no SMS backup in v1)
- No backup codes (TFA deferred)
- Rate limits non-configurable per endpoint
- No account lockout (relies on rate limiting)

### Design Trade-offs
- Per-email rate limiting allows enumeration via timing (acceptable vs blocking legitimate users)
- 24-hour expiration may lose links across time zones (acceptable for security)
- Single password change invalidates all sessions (strong security, UX impact)

## Handoff Checklist

- [x] Complete specification document (plan.md)
- [x] Data model design (data-model.md)  
- [x] Developer quickstart (quickstart.md)
- [x] API contracts (OpenAPI YAML)
- [x] Security analysis and threat model
- [x] Performance targets and benchmarks
- [x] Testing strategy and test cases
- [x] Database migrations (SQL scripts)
- [x] Code examples (services, endpoints, screens)
- [x] Deployment instructions
- [x] Troubleshooting guide
- [x] Implementation timeline

## Success Criteria

**Phase 1 Complete When:**
- ✅ All database migrations created and tested
- ✅ All 4 backend services implemented
- ✅ All 4 API endpoints implemented and accessible
- ✅ Rate limiting middleware functional
- ✅ Email service integration working (mock or real)
- ✅ All backend unit and integration tests passing
- ✅ Documentation complete

**Feature Complete When:**
- ✅ All Phase 1-3 tasks completed
- ✅ E2E tests passing (registration → verification → login → password reset)
- ✅ Security review approved
- ✅ Performance benchmarks met
- ✅ Docker deployment tested
- ✅ Team sign-off obtained

## Next Steps (After Planning Phase)

1. **Create Tasks**: Run `.specify/tasks` to generate Phase 2 implementation tasks
2. **Backend Implementation**: Developers begin Phase 1 backend work
3. **Frontend Implementation**: Parallel Phase 2 frontend development
4. **Testing**: Execute comprehensive test suite
5. **Review**: Security and architecture review
6. **Deployment**: Deploy to staging, then production

## Files Included

```
specs/004-email-verification-password-reset/
├── plan.md                           # Main implementation plan
├── data-model.md                     # Schema and entity design
├── quickstart.md                     # Developer quickstart
├── spec.md                           # Original specification (input)
└── contracts/
    ├── verification-endpoints.yaml   # OpenAPI specification
    └── README.md                     # (to be created during Phase 2)
```

## Questions or Issues?

This plan is the deliverable for **Spec 004 Phase 1: Planning**. 

For implementation details, refer to:
- **Security questions**: See "Security Implementation" section in plan.md
- **API details**: See "API Contract Design" section in plan.md
- **Database schema**: See data-model.md for complete schema
- **Code examples**: See quickstart.md for implementation examples
- **Testing strategy**: See "Testing Strategy" section in plan.md

---

**Plan Status**: ✅ **COMPLETE**  
**Ready for**: Phase 2 implementation tasks generation
**Target Completion**: Phase 1 backend + Phase 2 frontend in 6-8 days
**Phase 3 (Testing/Deploy)**: 2-3 additional days
