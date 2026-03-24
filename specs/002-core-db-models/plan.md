# Implementation Plan: Core Database Models

**Branch**: `002-core-db-models` | **Date**: 2026-03-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-core-db-models/spec.md`

**Note**: This plan guides development of database schema migrations and model definitions for User, Chat, ChatMember, Message, and Invite entities.

## Summary

Define and implement Postgres database schema supporting core messenger entities (User, Chat, ChatMember, Message, Invite) with encrypted message storage, referential integrity, and performance indexes. Migrations will follow Serverpod patterns and support idempotent rollback. This foundation enables all user registration, chat management, messaging, and invitation features.

## Technical Context

**Language/Version**: Dart 3.5 (backend uses Serverpod framework, frontend uses Flutter)  
**Primary Dependencies**: Serverpod (backend framework), PostgreSQL (database), Dart runtime  
**Storage**: PostgreSQL 13+ with UUID extensions  
**Testing**: Dart `test` package with integration tests against PostgreSQL  
**Target Platform**: Linux/Docker backend (docker-compose), iOS/Android/Linux client (Flutter)  
**Project Type**: Mobile messaging app with backend API  
**Performance Goals**: Sub-100ms query time for typical operations, support 1000+ concurrent connections  
**Constraints**: Encrypted message storage, referential integrity enforced at database level, migrations must be idempotent  
**Scale/Scope**: 5 core entities, 5 migrations, indexes on email/username/chat_id/sender_id/status

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Security-First Principle (NON-NEGOTIABLE)

**Required**: Schema MUST support encrypted message storage, encrypted media metadata, and secure key derivation  
**Design Decisions**: 

1. **Message Content Encryption** (IMPLEMENTED)
   - Message.encrypted_content stored as TEXT (application layer handles encryption via cryptography package AES-256-GCM)
   - EncryptionService enforces symmetric key management best practices (no logging of keys)

2. **Media Metadata Storage** (CLARIFIED)
   - media_url and media_type stored as plaintext VARCHAR (security boundary: media files themselves stored in secure object storage)
   - Media URL construction (full URL assembly) occurs at application layer to enable CDN/SAS token injection
   - Future enhancement: Support for encrypted media metadata if business requirements evolve
   - Rationale: Media metadata (type classification) does NOT contain sensitive user data; encryption overhead unjustified for current scope

3. **User Deletion & Message History Preservation** (CLARIFIED)
   - Design decision: Message sender_id has FOREIGN KEY → User.id ON DELETE RESTRICT
   - Rationale: Preserves message history for audit and UX (users see "[deleted user]" rather than orphaned messages)
   - When user deletes account, message service must implement application-level soft-delete (mark sender as deleted, preserve message record)
   - ChatMember and Invite use CASCADE DELETE (ephemeral membership/invitation records)
   - This prevents data loss while maintaining referential integrity

4. **Password Security** (DEFERRED TO APPLICATION LAYER)
   - password_hash stored as TEXT; bcrypt hashing applied by UserService.createUser() before persistence
   - No plaintext storage at any layer

**Status**: PASS - Schema accommodates encryption requirements; media metadata approach justified for v1 scope

### ✅ Testing Discipline Principle (NON-NEGOTIABLE)

**Required**: Three-tier testing strategy for database model changes  
**Plan**:
- Unit tests: Migration script validation, schema definition tests, index existence verification
- Integration tests: CRUD operations on each entity, foreign key constraint validation
- Manual tests: User-facing workflows (registration, chat creation, messaging)

**Status**: PASS - Testing strategy will be codified in Phase 2 tasks

### ✅ Architecture Clarity Principle

**Required**: Schema MUST reflect three-layer architecture (Flutter client, WebSocket real-time, Serverpod+PostgreSQL)  
**Design Decision**:
- ChatMember junction table enables WebSocket subscription by chat_id
- Message status field enables real-time status updates (sent → delivered → read)
- Chat.archived_by_users enables client-side filtering without separate table

**Status**: PASS - Schema design supports clean layer boundaries and contracts

### ✅ Code Consistency Principle

**Required**: Migration files and model names follow Dart naming conventions (snake_case files, PascalCase models)  
**Plan**:
- Migration files: `001_create_users_table.dart`, `002_create_chats_table.dart` etc.
- Model classes: `User`, `Chat`, `ChatMember`, `Message`, `Invite` (PascalCase)
- Database columns: snake_case (user_id, chat_id, created_at, etc.)

**Status**: PASS - Naming conventions confirmed

### ✅ Delivery Readiness Principle

**Required**: Schema MUST work with `docker-compose up` single command  
**Plan**:
- Migrations run automatically on Serverpod startup
- PostgreSQL container initializes from docker-compose.yml
- Schema tests verify database connectivity and table creation

**Status**: PASS - Delivery pipeline already established

## Project Structure

### Documentation (this feature)

```text
specs/002-core-db-models/
├── plan.md              # This file (planning output)
├── spec.md              # Feature specification (input)
├── research.md          # Phase 0 research findings
├── data-model.md        # Phase 1 data model design
├── quickstart.md        # Phase 1 quickstart guide
├── contracts/           # Phase 1 database contracts
│   ├── user-model.yaml
│   ├── chat-model.yaml
│   ├── message-model.yaml
│   └── invite-model.yaml
├── checklists/
│   └── requirements.md   # Specification validation checklist
└── tasks.md             # Phase 2 implementation tasks (created by /speckit.tasks)
```

### Source Code (repository root)

```text
backend/
├── lib/
│   ├── server.dart
│   ├── src/
│   │   ├── models/              # ← Core entities (Phase 1 output)
│   │   │   ├── user_model.dart
│   │   │   ├── chat_model.dart
│   │   │   ├── chat_member_model.dart
│   │   │   ├── message_model.dart
│   │   │   └── invite_model.dart
│   │   ├── services/            # ← Data access layer
│   │   └── endpoints/           # ← API endpoints
│   └── config/
├── migrations/                   # ← Database migrations (Phase 2 deliverables)
│   ├── 001_create_users_table.dart
│   ├── 002_create_chats_table.dart
│   ├── 003_create_chat_members_table.dart
│   ├── 004_create_messages_table.dart
│   └── 005_create_invites_table.dart
├── pubspec.yaml
└── Dockerfile

docker-compose.yml               # PostgreSQL + Serverpod
```

**Structure Decision**: Backend services model with database migrations organized by entity creation order. Models reference migration contracts. This follows Serverpod convention of migrations in the backend deployed with the application.

## Complexity Tracking

No Constitution violations identified. All 5 core principles (Security-First, Architecture Clarity, Testing Discipline, Code Consistency, Delivery Readiness) pass the gate.

---

## Phase 1 Summary

✅ **Design Complete** - All artifacts generated

### Artifacts Generated

1. **[research.md](research.md)** - 7 research topics resolved with decisions, rationale, and alternatives
2. **[data-model.md](data-model.md)** - 5 entities fully defined with fields, relationships, constraints, and indexes
3. **[quickstart.md](quickstart.md)** - Developer guide for migrations, model usage, testing, and troubleshooting
4. **contracts/** - 5 database entity contracts with SQL schemas and Dart model definitions:
   - [user-model.yaml](contracts/user-model.yaml)
   - [chat-model.yaml](contracts/chat-model.yaml)
   - [message-model.yaml](contracts/message-model.yaml)
   - [invite-model.yaml](contracts/invite-model.yaml)
   - [chat_member-model.yaml](contracts/chat_member-model.yaml)
5. **Agent Context Updated** - Copilot instructions updated with Dart 3.5, Serverpod, PostgreSQL 13+

### Constitution Re-Check (Post-Design)

✅ All principles remain in compliance after design phase
- Security-First: Encryption at application layer, encrypted_content as TEXT field
- Architecture Clarity: Clear layer separation with defined contracts
- Testing Discipline: Schema supports three-tier testing strategy
- Code Consistency: Naming conventions established (snake_case columns, PascalCase models)
- Delivery Readiness: Migrations follow Serverpod conventions, docker-compose ready

### Next Steps

Run `/speckit.tasks` to generate implementation tasks from this design

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
