<!-- 
SYNC IMPACT REPORT - v1.0.0 (Initial Creation)
================================================
Version Change: N/A → 1.0.0 (initial project constitution)
Ratification Date: 2026-03-10

PRINCIPLES (5 defined):
  ✓ I. Security-First (NON-NEGOTIABLE)
  ✓ II. End-to-End Architecture Clarity
  ✓ III. Testing Discipline (NON-NEGOTIABLE)
  ✓ IV. Code Consistency & Naming Standards
  ✓ V. Delivery Readiness

ADDED SECTIONS:
  ✓ Security & Encryption Requirements (details scope, key management, database, transport)
  ✓ Architecture & Technology Stack (defines tech choices and directory structure)
  ✓ Development Workflow & Review Gates (code review, branching, build gates)

TEMPLATES STATUS:
  ⚠ plan-template.md - pending update for project-specific technical context
  ⚠ spec-template.md - pending update for Flutter/Serverpod user stories template
  ⚠ tasks-template.md - pending update for task categorization by principle (Security, Testing, Delivery)

FOLLOW-UP TODOS:
  - Ensure plan.md includes Constitution Check gate per Principles I and III
  - Update spec-template.md with Flutter-specific user story examples (mobile auth, messaging)
  - Create GUIDANCE.md for runtime development (linting config, encryption library usage, testing setup)

COMMIT MESSAGE SUGGESTION:
  docs: add flutter-mobile-messenger constitution v1.0.0 (5 principles + security/architecture/workflow)
-->

# Flutter Mobile Messenger Constitution

## Core Principles

### I. Security-First (NON-NEGOTIABLE)

All sensitive data MUST be encrypted before persistence or transmission. Encryption scope includes messages, media metadata, user profile data, and chat lists. End-to-end encryption principles apply to user-to-user communication. The cryptography library is the single source of truth for encryption operations. No plaintext storage of user credentials, authentication tokens, or encrypted keys.

### II. End-to-End Architecture Clarity

The system consists of three distinct layers: Flutter frontend (mobile app), WebSocket real-time communication layer, and Serverpod backend with PostgreSQL storage. Each layer MUST have defined responsibilities and contract boundaries. Data flow across layers MUST be explicit and testable. Cross-layer communication MUST use WebSockets for real-time messaging or HTTP for command-response patterns.

### III. Testing Discipline (NON-NEGOTIABLE)

Three-tier testing strategy MUST be followed: (1) Feature-level unit tests after each module delivery, (2) Manual UI testing on emulator for each feature, (3) Two-user integration messaging tests for chat functionality. New features MUST include tests at all three levels before PR approval. Test failures block merge until resolved.

### IV. Code Consistency & Naming Standards

File names MUST use snake_case (e.g., `user_service.dart`). Class and type names MUST use PascalCase (e.g., `UserService`, `MessageModel`). Variable and function names MUST use camelCase (e.g., `userPreferences`, `fetchMessages()`). These conventions apply to both Dart (frontend + backend) and all configuration files. Code review gates MUST enforce conformance.

### V. Delivery Readiness

Backend MUST start with a single `docker-compose up` command. All necessary services (PostgreSQL, Serverpod application) MUST be defined in docker-compose.yml. Android build artifacts (.apk) MUST be generated and provided for reviewer testing. README MUST include step-by-step reviewer guide for building Android and running backend.

## Security & Encryption Requirements

- **Encryption Library**: cryptography (Dart package) is the canonical encryption provider
- **Encrypted Data Scopes**:
  - Messages: Full message content encrypted end-to-end
  - Media Metadata: File names, sizes, types encrypted at rest
  - User Profile Data: Names, contact info, status encrypted at rest
  - Chat Lists: Chat metadata and participant info encrypted at rest
- **Key Management**: Keys MUST never be logged, exported in plaintext, or stored unencrypted
- **Database**: PostgreSQL stores only encrypted values except for query indexes (which MUST use salted hashes)
- **Transport**: All WebSocket traffic MUST use WSS (WebSocket Secure) with TLS certificates

## Architecture & Technology Stack

- **Frontend**: Flutter with Dart, organized into `lib/core`, `lib/features`, `lib/services`, `lib/widgets`, `lib/models`
- **Backend**: Serverpod with Dart, PostgreSQL database, WebSocket real-time layer
- **Containerization**: Docker with docker-compose for single-command startup
- **Storage**: Object storage for media files (separate from database)
- **Navigation (UI)**: Login, Register, Chat List, Chat, Profile, Invites

Dependencies and framework versions MUST be pinned in pubspec.yaml. Major version updates require updated tests and integration validation.

## Development Workflow & Review Gates

1. **Code Review Requirements**:
   - All PRs MUST verify Code Consistency principle compliance (naming standards)
   - Security-First principle MUST be verified for any data handling changes
   - PRs touching encryption MUST include cryptography expert review
   - Testing Discipline MUST be confirmed: three-tier test strategy present

2. **Branching Strategy**:
   - Feature branches named `###-feature-name` (e.g., `001-secure-auth`)
   - All commits to main MUST pass all tests and code review

3. **Build & Test Gates**:
   - Unit tests and linting MUST pass before PR merge
   - Android APK build MUST complete successfully for mobile features
   - Backend docker-compose setup MUST start without errors
   - Manual UI testing sign-off required for feature features

## Governance

- This Constitution supersedes all other development practices within the flutter-mobile-messenger project
- All team members MUST adhere to the Core Principles (especially Security-First and Testing Discipline marked NON-NEGOTIABLE)
- Constitution amendments MUST be documented with rationale and effective date
- Principle violations discovered during development MUST be logged and addressed in the next review cycle
- Exceptions to principles require explicit justification and approval from project lead
- Reference [.specify/GUIDANCE.md](../../.specify/GUIDANCE.md) for runtime development guidance and troubleshooting

**Version**: 1.0.0 | **Ratified**: 2026-03-10 | **Last Amended**: 2026-03-10
