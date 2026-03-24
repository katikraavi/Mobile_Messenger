# Phase 0 Research: Core Database Models

**Date**: 2026-03-10  
**Feature**: 002-core-db-models  
**Status**: Research Complete

## Research Overview

Phase 0 research validated technical assumptions and design decisions for the database schema. No NEEDS CLARIFICATION items remain from the specification.

## Resolved Research Topics

### Decision 1: Primary Key Strategy

**Topic**: How to identify records uniquely across distributed systems?

**Decision**: Use UUID v4 primary keys for all entities (User, Chat, ChatMember, Message, Invite)

**Rationale**: 
- UUID enables distributed ID generation without database coordination
- Supports potential future sharding or replication
- Industry standard for messaging systems

**Alternatives Considered**:
- Sequential BIGINT: Simpler but requires central coordination, leaks data distribution
- ULID: Slightly better ordering but UUID acceptable for current scale
- Application-generated surrogate keys: Additional complexity without benefits

**Implementation**: PostgreSQL UUID type with uuid-ossp extension or application-generated UUIDs in Serverpod service layer

---

### Decision 2: Encrypted Content Storage

**Topic**: How to store encrypted message content while preserving search/query capability?

**Decision**: Store encrypted_content as TEXT field, encrypted at application layer before database insert

**Rationale**:
- Aligns with Constitution Security-First principle
- Application handles encryption/decryption, database stores opaque TEXT
- Enables end-to-end encryption without database-level decryption
- Follows best practice of encryption at boundary

**Alternatives Considered**:
- Database-level encryption (pgcrypto): Database knows keys, violates principle
- Store as BYTEA: No functional difference from TEXT for this use case
- Searchable encryption: Too complex for v1, not required

**Implementation**: Dart `cryptography` package handles AES-256-GCM encryption before Serverpod persists to database

---

### Decision 3: Chat Archival Mechanism

**Topic**: How to track which users have archived a chat without separate records?

**Decision**: Store archived_by_users as PostgreSQL BIGINT[] array type OR JSON field with user IDs

**Rationale**:
- Avoids separate archive table/junction table complexity
- Single SELECT query returns complete archive state
- Supports both one-on-one and group chats
- Keeps related data denormalized but immutable

**Alternatives Considered**:
- ChatArchive junction table: Creates additional complexity, slower queries
- Boolean archived flag: Can't distinguish per-user archive state
- Application-maintained cache: Inconsistency risks

**Implementation**: Use PostgreSQL BIGINT[] array for simplicity (more performant than JSON for this use case)

---

### Decision 4: Message Status Transitions

**Topic**: What message lifecycle states prevent invalid transitions?

**Decision**: Define ENUM type: message_status (sent, delivered, read) with application-enforced transitions only

**Rationale**:
- Limits to 3 states sufficient for MVP messaging
- Forward-only transitions (sent → delivered → read)
- Prevents data corruption via invalid transitions
- Database-level ENUM prevents unknown values

**Alternatives Considered**:
- No constraint, application validates: Risky, allows silent corruption
- Complex state machine in database: Adds trigger complexity
- Separate state_history table: Overkill for MVP requirements

**Implementation**: CREATE TYPE message_status AS ENUM ('sent', 'delivered', 'read'); Application enforces transition rules

---

### Decision 5: Foreign Key Cascade Policy

**Topic**: What happens to dependent records when a user is deleted?

**Decision**: CASCADE for ChatMember (user removed from chats), RESTRICT for Message (prevent orphaned messages)

**Rationale**:
- ChatMember on DELETE CASCADE: Clean up membership when user deleted
- Message on DELETE RESTRICT: Preserve message history, prevents accidental data loss
- Invite on DELETE CASCADE: Clean up pending invitations when user/receiver deleted (can re-send)
- User must be unaffiliated from chats before deletion if messages exist (soft delete approach)

**Alternatives Considered**:
- ALL CASCADE: Loses message history, violates audit trail needs
- ALL RESTRICT: Prevents user deletion, complicates cleanup
- ALL SET NULL: Not applicable, user_id is NOT NULL

**Implementation**: Foreign key constraints configured at migration time per entity relationships

---

### Decision 6: Indexing Strategy

**Topic**: Which queries need indexes for sub-100ms performance?

**Decision**: Create indexes on:
- User.email (UNIQUE index for login queries)
- User.username (UNIQUE index for mention/search)
- Message.chat_id + Message.created_at (composite for pagination)
- Message.sender_id (for user's sent messages)
- Message.status (for status queries)
- ChatMember.user_id (for user's chats)
- Invite.receiver_id (for pending invitations)

**Rationale**:
- Email/username: Account lookups (critical path)
- Message queries: Pagination of 1000+ messages requires efficient sorting
- ChatMember user_id: User's active chats list
- Invite receiver_id: Notification counts, pending invite display

**Alternatives Considered**:
- Index on all foreign keys: Unnecessary overhead
- Application-level caching: Adds complexity, staleness issues
- Partial indexes: Premature optimization

**Implementation**: Index creation in migrations with EXPLAIN ANALYZE verification for actual performance

---

### Decision 7: Timestamp Precision

**Topic**: Should timestamps support sub-second precision for message ordering?

**Decision**: Use TIMESTAMP WITH TIME ZONE (microsecond precision) standard PostgreSQL timestamp type

**Rationale**:
- Microsecond precision sufficient for ordering 1000+ messages/second
- Timezone awareness required for correct distributed timestamp handling
- PostgreSQL native type, no custom serialization
- Aligns with UTC-based system clocks

**Alternatives Considered**:
- BIGINT Unix milliseconds: Requires serialization, less PostgreSQL-idiomatic
- Double-precision floats: Rounding errors accumulate
- No timezone: Ambiguous for audit trails

**Implementation**: Column type TIMESTAMP WITH TIME ZONE, application layer manages UTC conversion

---

## Research Findings Summary

| Topic | Decision | Confidence |
|-------|----------|-----------|
| Primary Keys | UUID v4 | High |
| Encryption Storage | Encrypted TEXT in app layer | High |
| Chat Archival | BIGINT[] array | High |
| Message States | ENUM (sent/delivered/read) | High |
| Cascade Policy | CASCADE ChatMember, RESTRICT Message | High |
| Indexes | Email, username, chat_id+created_at, sender_id, status, user_id | High |
| Timestamps | TIMESTAMP WITH TIME ZONE | High |

All decisions support the Constitution principles:
- ✅ Security-First: Encryption at application boundary
- ✅ Testing Discipline: Schemas allow comprehensive testing
- ✅ Architecture Clarity: Foreign keys define clear relationships
- ✅ Code Consistency: Naming prepared for schema-first generator
- ✅ Delivery Readiness: Migrations are standard Serverpod format

## No Clarifications Required

All technical questions have clear answers supported by research. Proceeding to Phase 1 design.
