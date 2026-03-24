# Phase 0 Research: Technical Foundation & Decisions

**Date**: March 15, 2026  
**Feature**: Invitation Send, Accept, Reject, and Cancel  
**Status**: ✅ Complete (No NEEDS CLARIFICATION items)

## Research Summary

All technical context items determined from existing project architecture. No unknowns required resolution.

---

## Technology Stack Decisions

### Frontend Framework

**Decision**: Flutter (Dart) with Riverpod state management  
**Rationale**: Already used throughout the project; seamless integration with existing UI components and auth system  
**Alternatives Considered**:
- React Native: Rejected (project already commits to Flutter ecosystem)
- Native iOS/Android: Rejected (complexity; Flutter provides cross-platform coverage)

**Documentation**: See `frontend/pubspec.yaml` for pinned Flutter version and dependencies

---

### Backend Framework

**Decision**: Dart Serverpod with HTTP REST endpoints (no new WebSocket layer)  
**Rationale**: 
- Existing backend already uses Serverpod; feature fits naturally into HTTP handler pattern
- Invitation operations are stateless request-response; WebSocket overkill
- Polling or app-level refresh sufficient for status updates (SC-006: 95% within 5 seconds)

**Alternatives Considered**:
- GraphQL: Rejected (complexity; simple REST sufficient)
- WebSocket real-time: Rejected (over-engineered for stateless metadata; polling acceptable)

**Documentation**: See `backend/lib/server.dart` for existing endpoint patterns

---

### State Management (Frontend)

**Decision**: Riverpod providers for invitation list caching + state updates  
**Rationale**: 
- Already proven in project (user auth, chat list state)
- Declarative approach aligns with Flutter best practices
- Enables efficient refresh/invalidation strategies

**Alternatives Considered**:
- Redux: Rejected (overkill; Riverpod simpler for this scope)
- Plain FutureBuilder: Rejected (lacks caching; UX suffers on repeated views)

**Documentation**: See `frontend/lib/features/invitations/providers/invites_provider.dart`

---

### Data Persistence & Storage

**Decision**: PostgreSQL `invites` table with existing schema  
**Rationale**: 
- Table already exists with sender_id, receiver_id, status, timestamps
- PostgreSQL supports JSON (for future blob storage if needed)
- Transaction semantics support race condition resolution (Q2: timestamp-based)

**Schema Reference**:
```sql
CREATE TABLE invites (
  id UUID PRIMARY KEY,
  sender_id UUID NOT NULL REFERENCES users(id),
  receiver_id UUID NOT NULL REFERENCES users(id),
  status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'rejected', 'canceled')),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMP,
  canceled_at TIMESTAMP
);
```

**Alternatives Considered**:
- SQLite: Rejected (not suitable for multi-client server)
- DynamoDB: Rejected (overkill; PostgreSQL sufficient)

---

### Real-Time Updates Strategy

**Decision**: Polling-based with manual refresh (short-term) + WebSocket upgrade path (future)  
**Rationale**: 
- Meets SC-006 (95% propagation within 5 seconds) with 3-second polling interval
- Simpler implementation; no additional infrastructure
- Future WebSocket upgrade possible without API contract changes

**Alternatives Considered**:
- Full WebSocket: Rejected (adds server complexity for single feature; polling adequate)
- Firebase Cloud Messaging: Rejected (requires additional paid service; project self-hosted)

**Implementation**: Riverpod provider with `Future` that reruns on user focus/manual refresh

---

### Authentication & Authorization

**Decision**: Reuse existing JWT Bearer token auth + SecureStorage wrapper  
**Rationale**: 
- Already implemented and working in project
- Invitations are user-specific; token validation sufficient
- No new auth schemes required

**Implementation Details**:
- InviteApiService reads fresh token from SecureStorageWrapper per request (prevents multi-user bugs)
- Backend validates Bearer token; extracts user_id for sender_id validation
- No special scopes/permissions needed (invitation creation is available to all authenticated users)

---

### Performance & Scalability Targets

**Decision**: Optimize for typical usage patterns (1-100 concurrent users); defer optimization if needed  
**Rationale**: 
- SC-005 requires handling 100+ concurrent invitations (not users)
- PostgreSQL + in-memory Riverpod caching sufficient for current scale
- No distributed cache (Redis) needed at this stage

**Bottleneck Analysis**:
- Database: Simple indexed queries on sender_id/receiver_id (O(1) lookups with proper indexes)
- Network: <2s response time target achievable on 4G+ networks
- Frontend: Riverpod caching eliminates re-fetches within session

**Future Optimization Path**: If scale grows beyond 10k users, add Redis cache layer to backend

---

## API Design Decisions

### Endpoint Strategy

**Decision**: RESTful endpoints following existing project patterns  
**Routes Designed**:
- `GET /api/users/{userId}/invites/pending` - Receiver's view
- `GET /api/users/{userId}/invites/sent` - Sender's view
- `POST /api/invites` - Create invitation
- `POST /api/invites/{id}/accept` - Accept invitation
- `POST /api/invites/{id}/decline` - Decline invitation
- `DELETE /api/invites/{id}` or `POST /api/invites/{id}/cancel` - Cancel invitation

**Response Schema** (both endpoints return consistent DTO):
```json
{
  "id": "uuid",
  "senderId": "uuid",
  "senderName": "string",
  "senderAvatarUrl": "string or null",
  "recipientId": "uuid",
  "recipientName": "string",
  "recipientAvatarUrl": "string or null",
  "status": "pending|accepted|rejected|canceled",
  "createdAt": "ISO 8601 timestamp",
  "respondedAt": "ISO 8601 timestamp or null"
}
```

**Rationale**: Consistent DTO across endpoints enables frontend code reuse; sender/recipient data always available

---

## UI/UX Design Decisions

### Unified Invitations Screen

**Decision**: Single consolidated screen combining pending + sent invitations  
**Rationale**: 
- Better UX than two-tab view (users see full context)
- Conditional buttons (Accept/Decline only for incoming) clear user intent
- Status badges (Sent, Pending, Accepted) provide at-a-glance information

**Alternative Rejected**: Two-tab layout created complexity in prior iteration; unified view simpler and more intuitive

---

## Testing Strategy

### Three-Tier Test Approach (Per Constitution)

**Tier 1 - Unit Tests**:
- Riverpod provider logic (state transitions, list filtering)
- InviteApiService HTTP client behavior
- Invitation data model validation

**Tier 2 - Widget Tests**:
- InvitationsScreen component rendering
- Button visibility logic (Accept/Decline only for incoming)
- List empty state handling

**Tier 3 - Integration Tests**:
- Two-device scenario: Alice sends → Bob receives → Bob accepts
- State consistency across API calls
- Concurrent operations (race condition handling)

---

## Security Considerations

### Threat Model

1. **Unauthorized Invitation Creation**: User tries to send invitation as someone else
   - **Mitigation**: Backend validates sender_id matches Bearer token user_id

2. **Unauthorized Status Changes**: User tries to accept invitation not addressed to them
   - **Mitigation**: Backend validates receiver_id for accept/decline; sender_id for cancel

3. **Blocking Bypass**: User sends invitation to blocked user
   - **Mitigation**: Frontend checks blocking list before show "Send" button; Backend also validates

4. **Data Leakage**: Invitation data exposed to unauthorized users
   - **Mitigation**: Queries filtered by current user_id (sender OR receiver)

---

## Summary of Decisions

| Area | Decision | Rationale |
|------|----------|-----------|
| Frontend | Flutter + Riverpod | Already in project |
| Backend | Serverpod HTTP | Existing architecture |
| Storage | PostgreSQL (existing table) | No migration needed |
| Real-time | Polling + app refresh | Meets SLA requirements |
| Testing | Three-tier (unit/widget/integration) | Per constitution |
| API Design | RESTful with consistent DTOs | Simplifies frontend |
| UI Pattern | Unified screen | Better UX than tabs |

---

## Recommendation

✅ **Proceed to Phase 1 Design** - All technical decisions are grounded in existing project architecture and proven patterns. No blocking unknowns remain.

## Next Steps (Phase 1)

1. Generate `data-model.md` documenting entities and state transitions
2. Generate `contracts/` with API request/response schemas
3. Create `quickstart.md` with implementation guide for developers
4. Update agent context with new technology dependencies
5. Re-evaluate Constitution Check after design review
