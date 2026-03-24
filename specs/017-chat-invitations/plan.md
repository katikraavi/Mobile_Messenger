# Implementation Plan: Chat Invitations

**Branch**: `017-chat-invitations` | **Date**: 2026-03-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/017-chat-invitations/spec.md`

**Status**: ✅ Phase 1 Complete - Design artifacts generated 2026-03-15

## Summary

Enable users to send formal invitations to initiate 1-to-1 conversations. Users can view pending/sent invitations in a dedicated "Invitations" tab with real-time badge notifications. Users cannot invite existing contacts or themselves. Accepted invitations automatically create chats. Implementation spans Flutter frontend (new Invitations tab + state management), Serverpod backend (invite endpoints + validation logic), and PostgreSQL (ChatInvite table with status tracking).

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Dart 3.5 (Flutter 3.41.4 frontend + Serverpod backend)
**Primary Dependencies**: Flutter SDK, Riverpod (state management), Serverpod, PostgreSQL database driver, http, image_picker, permission_handler
**Storage**: PostgreSQL (primary) + in-memory Riverpod state (frontend)
**Testing**: Flutter test framework (unit) + Mockito (mocking) + integration tests (local backend)
**Target Platform**: Android 9+ / iOS 12.0+, Dart backend server (Docker containerized)
**Project Type**: Mobile app (Flutter) + Backend microservice (Serverpod)
**Performance Goals**: Send invite <500ms, Accept/decline <300ms, Load 100+ invites <1s, Badge update <3s
**Constraints**: Offline: cached view only; actions require connectivity. Data: invites persist indefinitely. Concurrency: mutual invites handled gracefully.
**Scale/Scope**: Millions of users (existing auth), ~1 invite/user/week, 2 new UI screens

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

✅ **Principle I - Security-First**
- Invites contain user IDs (no sensitive data in transit)
- Accept/decline operations authenticated via JWT
- No personal info exposed in invite payloads
- **Status**: COMPLIANT

✅ **Principle II - End-to-End Architecture Clarity**
- Frontend (Flutter): Invitations UI + Riverpod state management
- Backend (Serverpod): Invite CRUD endpoints + business logic
- Database (PostgreSQL): ChatInvite table + indexes
- **Status**: COMPLIANT - clear layer separation

✅ **Principle III - Testing Discipline (NON-NEGOTIABLE)**
- Unit tests: Invite validation, status transitions, duplicate prevention
- UI tests: Send/accept/decline flows, empty state, badge updates
- Integration tests: 2-user invite acceptance → chat creation workflow
- **Status**: COMPLIANT - three-tier testing required

✅ **Principle IV - Code Consistency & Naming**
- File names: `invite_service.dart`, `chat_invite_provider.dart`, `invitations_screen.dart`
- Classes: `ChatInvite`, `InviteService`, `InvitationsProvider`
- Functions: `sendInvite()`, `acceptInvite()`, `fetchPendingInvites()`
- **Status**: COMPLIANT

✅ **Principle V - Delivery Readiness**
- Backend: Added to existing docker-compose.yml (no new containers)
- Database: Migration file already present (`006_create_invites_table.dart`)
- APK: Rebuilt and included in feature PR
- README: Step-by-step for testing 2-user invite flow
- **Status**: COMPLIANT

**Constitution Check Result**: ✅ ALL GATES PASSED

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
backend/
├── lib/src/
│   ├── endpoints/
│   │   └── invites_endpoint.dart          # REST endpoints for invite operations
│   ├── services/
│   │   └── invite_service.dart            # Business logic & validation
│   └── models/
│       └── chat_invite.dart               # Serverpod data model
├── migrations/
│   └── 006_create_invites_table.dart      # PostgreSQL schema
└── test/
    ├── services/
    │   └── invite_service_test.dart       # Service unit tests
    └── endpoints/
        └── invites_endpoint_test.dart     # Endpoint integration tests

frontend/
├── lib/features/invitations/
│   ├── screens/
│   │   ├── invitations_screen.dart        # Main Invitations tab UI
│   │   └── send_invite_picker_screen.dart # User discovery + sending
│   ├── services/
│   │   └── invite_api_service.dart        # HTTP client for endpoints
│   ├── models/
│   │   └── chat_invite_model.dart         # Freezed data models
│   └── providers/
│       ├── invites_provider.dart          # Riverpod query providers
│       ├── send_invite_provider.dart      # Send mutation
│       ├── accept_invite_provider.dart    # Accept mutation
│       └── decline_invite_provider.dart   # Decline mutation
└── test/
    ├── services/
    │   └── invite_api_service_test.dart   # API service tests
    ├── providers/
    │   └── invites_provider_test.dart     # Provider tests
    └── widget/
        ├── invitations_screen_test.dart   # Widget tests
        └── send_invite_picker_test.dart   # UI flow tests

Database:
└── PostgreSQL `chat_invites` table (created via migration)
```

**Structure Decision**: Option 3 - Mobile + API

**Backend** (Serverpod):
- `backend/lib/src/endpoints/invite_endpoint.dart` - REST endpoints for invite operations
- `backend/lib/src/services/invite_service.dart` - Business logic
- `backend/migrations/006_create_invites_table.dart` - Database schema

**Frontend** (Flutter):
- `frontend/lib/features/invitations/` - Feature module
  - `screens/invitations_screen.dart` - Main invitations UI
  - `screens/send_invite_picker_screen.dart` - User discovery + sending
  - `services/invite_api_service.dart` - HTTP client for endpoints
  - `providers/invites_provider.dart` - Riverpod state management
  - `models/chat_invite_model.dart` - Data models
- `frontend/test/` - Unit + widget tests for invitations feature

Database: PostgreSQL `chat_invites` table (already exists per schema)

## FR-009 Scope Clarification

**Status**: User discovery picker assumed available (integrated in T014).

If user discovery/search interface is not yet available in the project, add 5-7 additional discovery implementation tasks to Phase 1. Verify with product team whether discovery is:
1. **Already built** → T014-T015 scope: integrate existing picker (2-3 tasks)
2. **In progress elsewhere** → T014-T015 scope: connect to discovery service (3 tasks)
3. **Not started** → Expand Phase 1 to include discovery screens + search logic (5-7 tasks)

Current task plan assumes option 1 or 2.

## Delivery Artifacts

✅ **Phase 0**: research.md - All design decisions documented  
✅ **Phase 1**: 
- data-model.md - Entity definitions, database schema, migrations
- contracts/invite_api.yaml - OpenAPI 3.0 specification
- contracts/state_models.md - Frontend Riverpod state & provider contracts
- Agent context updated with technology stack

📋 **Phase 2** (next): tasks.md - Task generation via speckit.tasks (NOT created by this command)
