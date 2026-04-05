# Flutter Frontend Architecture

## Overview

The active frontend target on this branch is the Flutter application in `frontend/`.

Its job is to act as a cross-platform client for ACORDE across:

- Flutter Web
- Flutter Desktop
- Flutter Mobile

## Directory Structure

Key frontend paths:

- `frontend/lib/main.dart`
- `frontend/lib/models.dart`
- `frontend/lib/services/`
- `frontend/lib/pages/`
- `frontend/lib/widgets/`

## Architectural Layers

### 1. Entry Layer

`frontend/lib/main.dart`

Responsibilities:

- initialize Flutter bindings
- construct the central `RelixController`
- call `initialize()`
- mount the app shell

### 2. State / Application Layer

`frontend/lib/services/relix_controller.dart`

This is the main application coordinator.

Responsibilities:

- hold the app snapshot/state
- initialize from persisted local state
- poll ACORDE periodically
- track daemon reachability
- merge remote and local data
- manage the offline mutation queue
- expose domain services to pages

This controller currently acts as the equivalent of:

- connection manager
- sync state store
- note coordinator
- peer metadata manager

## 3. Service Layer

### `acorde_client.dart`

Low-level HTTP access to ACORDE REST routes.

Responsibilities:

- `/status`
- `/identity`
- `/peers`
- `/entries`
- `/invite`
- `/pair`

### `note_service.dart`

Higher-level note operations and content helpers, including wikilink-related behaviors.

### `graph_service.dart`

Builds graph data from notes and relationships.

### `file_service.dart`

Handles file/blob operations against ACORDE.

### `export_service.dart`

Handles export workflows for user-owned data.

### `local_store.dart`

Persists client-side data using `shared_preferences`.

Current persisted categories:

- base URL
- cached notes
- queued mutations
- stuck mutations
- peer metadata

## 4. Model Layer

`frontend/lib/models.dart`

Defines the core frontend data structures:

- `NoteContent`
- `NoteEntry`
- `LocalIdentity`
- `RemotePeer`
- `MutationPayload`
- `SyncSnapshot`

These provide a typed boundary between:

- raw ACORDE payloads
- persisted client data
- rendered Flutter UI

## 5. Presentation Layer

### Pages

- `notes_page.dart`
- `note_detail_page.dart`
- `note_editor_page.dart`
- `graph_page.dart`
- `settings_page.dart`

### Widgets

- `connection_banner.dart`
- `glass_card.dart`
- `note_card.dart`

The page layer should stay relatively thin:

- read snapshot
- call controller methods
- render state

Business logic should remain mostly inside controller/services.

## Runtime Flow

### Startup

1. Flutter initializes.
2. `RelixController.initialize()` reads persisted state.
3. Cached notes and peers are shown immediately.
4. ACORDE polling starts.
5. Fresh daemon state replaces stale local state when reachable.

### Sync Refresh

1. Controller checks health.
2. If daemon is offline:
   - keep local state
   - update pending/stuck counts
3. If daemon is online:
   - fetch identity
   - fetch peers
   - fetch status
   - fetch notes
   - merge with queued local mutations
   - attempt drain

### Mutations

1. User creates/edits/deletes a note.
2. UI updates optimistically.
3. Mutation is persisted locally.
4. Background drain attempts to apply mutation to ACORDE.
5. Success clears pending state.
6. Repeated failure promotes mutation to stuck state.

## Design Constraints

### Strengths of the Current Architecture

- one cross-platform client codebase
- clear service/controller separation
- durable local cache
- durable mutation queue
- type-safe state transitions

### Current Architectural Limits

- the controller is still doing a lot and may need decomposition later
- `shared_preferences` is acceptable now but may need replacement for larger datasets
- polling is simple but not as efficient as a richer event-driven bridge
- conflict handling is still basic

## Recommended Next Architectural Steps

- split `RelixController` into smaller stores/services if feature count grows
- move from `shared_preferences` to a stronger local store if vault size grows
- add explicit domain modules for:
  - pairing
  - sync queue
  - graph
  - export
- add native QR scanning layer for mobile
