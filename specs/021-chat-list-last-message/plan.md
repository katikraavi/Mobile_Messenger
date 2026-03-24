# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]


## Technical Context

**Language/Version**: Dart 3.x, Flutter 3.x
**Primary Dependencies**: flutter_riverpod, provider, cryptography, WebSocket, Serverpod backend
**Storage**: PostgreSQL (backend), local state (frontend)
**Testing**: flutter_test, integration_test, manual UI testing, two-user integration tests
**Target Platform**: Android, iOS, Linux (for backend)
**Project Type**: mobile-app (Flutter), backend (Serverpod)
**Performance Goals**: Chat list updates within 1 second of new message
**Constraints**: End-to-end encryption, code consistency, test discipline, delivery readiness
**Scale/Scope**: 10k+ users, 50+ screens, real-time messaging

## Constitution Check

GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.

- Security-First: All message previews and timestamps must respect encryption boundaries. No plaintext sensitive data.
- End-to-End Architecture Clarity: Chat list must update via WebSocket or push, not polling. Data flow explicit.
- Testing Discipline: Unit, UI, and integration tests required for chat list update logic.
- Code Consistency & Naming Standards: All new files/classes/functions must follow project naming conventions.
- Delivery Readiness: Feature must work with docker-compose backend and be testable on Android/iOS emulator.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

[Gates determined based on constitution file]

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
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
# [REMOVE IF UNUSED] Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
