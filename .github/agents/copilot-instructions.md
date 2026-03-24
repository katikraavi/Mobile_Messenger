# mobile-messenger Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-03-10

## Active Technologies
- Dart 3.5 (backend uses Serverpod framework, frontend uses Flutter) + Serverpod (backend framework), PostgreSQL (database), Dart runtime (002-core-db-models)
- PostgreSQL 13+ with UUID extensions (002-core-db-models)
- Dart/Flutter 3.12.0+ + Riverpod 2.4.0, image_picker 1.0.0, flutter_secure_storage 9.0.0 (016-user-profile)
- PostgreSQL (backend profiles), local secure storage (auth tokens/credentials) (016-user-profile)
- Dart 3.5 (Flutter 3.41.4 frontend + Serverpod backend) + Flutter SDK, Riverpod (state management), Serverpod, PostgreSQL database driver, http, image_picker, permission_handler (017-chat-invitations)
- PostgreSQL (primary) + in-memory Riverpod state (frontend) (017-chat-invitations)
- Dart (Flutter 3.x frontend + Serverpod 2.x backend) (018-invite-send-accept)
- PostgreSQL database with `invites` table (existing schema with sender_id, receiver_id, status, timestamps) (018-invite-send-accept)
- Dart 3.11.1 (Flutter 3.41.4 mobile) + Dart backend (Shelf) + Riverpod (state management), Provider (auth), Shelf (HTTP server), PostgreSQL driver, cryptography (019-chat-list)
- PostgreSQL with tables: `users`, `chats`, `messages`, `invites` (019-chat-list)
- Dart (frontend: Flutter 3.0+, backend: Serverpod) (020-message-status-typing)
- PostgreSQL 13+ with tables: `messages`, `message_status`, `message_edits` (020-message-status-typing)

- Dart (frontend: Flutter SDK 3.10+, backend: Serverpod 2.1+) + Flutter SDK, Serverpod, Dart SDK, PostgreSQL 13+, Docker Compose (001-messenger-init)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Dart (frontend: Flutter SDK 3.10+, backend: Serverpod 2.1+)

## Code Style

Dart (frontend: Flutter SDK 3.10+, backend: Serverpod 2.1+): Follow standard conventions

## Recent Changes
- 020-message-status-typing: Added Dart (frontend: Flutter 3.0+, backend: Serverpod)
- 019-chat-list: Added Dart 3.11.1 (Flutter 3.41.4 mobile) + Dart backend (Shelf) + Riverpod (state management), Provider (auth), Shelf (HTTP server), PostgreSQL driver, cryptography
- 018-invite-send-accept: Added Dart (Flutter 3.x frontend + Serverpod 2.x backend)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
