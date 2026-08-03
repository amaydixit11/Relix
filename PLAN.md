# Relix — Comprehensive Project Overview & Task Document

> **Generated:** April 2026 | **Source:** Full codebase digest analysis

---

## Table of Contents

1. [What is Relix?](#1-what-is-relix)
2. [Architecture at a Glance](#2-architecture-at-a-glance)
3. [Repository Structure](#3-repository-structure)
4. [The ACORDE Backend Contract](#4-the-acorde-backend-contract)
5. [Frontend Platforms](#5-frontend-platforms)
6. [Core Package (`@relix/core`)](#6-core-package-relixcore)
7. [Flutter Frontend (Primary Target)](#7-flutter-frontend-primary-target)
8. [Web App (`apps/web`)](#8-web-app-appsweb)
9. [Mobile App (`apps/mobile`)](#9-mobile-app-appsmobile)
10. [Desktop App (`apps/desktop`)](#10-desktop-app-appsdesktop)
11. [Data Flow & Sync Model](#11-data-flow--sync-model)
12. [Current State of Each Area](#12-current-state-of-each-area)
13. [What Needs to Be Done — Full Task Breakdown](#13-what-needs-to-be-done--full-task-breakdown)
14. [Phase-by-Phase Implementation Plan](#14-phase-by-phase-implementation-plan)
15. [Known Bugs & Issues](#15-known-bugs--issues)
16. [Documentation Gaps](#16-documentation-gaps)
17. [Testing Strategy](#17-testing-strategy)
18. [Naming Conventions & Code Style](#18-naming-conventions--code-style)

---

## 1. What is Relix?

Relix is a **local-first, privacy-first personal knowledge management system** (PKM) built on top of **ACORDE** — a peer-to-peer daemon that handles data storage, sync, and device-to-device communication without a central cloud service.

### Core Philosophy

The product is not "a notes app with sync bolted on." It is an attempt to build a fundamentally different user mental model:

- **"This device is part of my fleet"** — not "log into my account"
- **"Pair a new device"** — not "point at a server URL"
- **"Work locally, sync when reachable"** — not "always online required"

### What It Does (Feature Summary)

- Create, edit, and delete notes in Markdown
- Organize notes with tags and wikilinks (`[[Note Title]]`)
- Browse notes as a knowledge graph with nodes and edges
- Sync notes across devices peer-to-peer via ACORDE
- Work completely offline with a mutation queue that drains later
- Pair new devices using invite codes or QR codes
- Manage a fleet of paired devices with nicknames and sync timestamps
- Export notes as Markdown files or ZIP archives

### What It Deliberately Is NOT

- A collaborative SaaS workspace
- A social publishing platform
- An always-online cloud editor
- A generic sync server product

---

## 2. Architecture at a Glance

```
┌─────────────────────────────────────────────────────────────────┐
│                        RELIX FRONTENDS                          │
│                                                                 │
│  ┌──────────────────┐  ┌────────────────┐  ┌────────────────┐  │
│  │  Flutter App     │  │   Next.js Web  │  │  Electron      │  │
│  │  (PRIMARY)       │  │   (Legacy/Ref) │  │  Desktop       │  │
│  │  frontend/       │  │   apps/web/    │  │  apps/desktop/ │  │
│  └────────┬─────────┘  └───────┬────────┘  └───────┬────────┘  │
│           │                    │                    │           │
│           └────────────────────┼────────────────────┘           │
│                                │ HTTP REST                      │
│                                ▼                                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              @relix/core  (TypeScript)                  │    │
│  │   AcordeClient | NoteService | GraphService | P2P       │    │
│  └─────────────────────────┬───────────────────────────────┘    │
└────────────────────────────┼────────────────────────────────────┘
                             │ HTTP REST (localhost:7331)
                             ▼
            ┌─────────────────────────────────┐
            │          ACORDE DAEMON          │
            │   (Go binary — external repo)   │
            │   Port 7331 (API) + 4001 (P2P)  │
            └──────────────┬──────────────────┘
                           │ libp2p
                           ▼
              Other devices on the fleet
```

### Two-Layer Separation

**ACORDE** is responsible for:
- Data storage (entries/notes/files)
- Peer identity and cryptographic pairing
- CRDT-based sync transport
- P2P networking

**Relix** is responsible for:
- Local user-facing cache
- Note UI and editing
- Pairing UI
- Queued offline mutations
- Displaying operational state
- Knowledge graph visualization

---

## 3. Repository Structure

```
Relix/
├── README.md
├── package.json                # Turbo monorepo root (npm workspaces)
├── turbo.json                  # Turborepo task pipeline
├── tsconfig.json               # Root TypeScript config
├── start-all.sh                # Convenience launcher for ACORDE + Flutter
├── connect_cluster.sh          # Dev script: mesh 3 local ACORDE nodes
├── simulate_sync.sh            # Dev script: simulate a second ACORDE peer
├── verify_cluster_sync.sh      # Dev script: verify sync propagation
│
├── apps/
│   ├── desktop/                # Electron app (wraps apps/web)
│   ├── mobile/                 # React Native / Expo app (LEGACY)
│   └── web/                    # Next.js 14 web app (LEGACY reference)
│
├── packages/
│   ├── core/                   # Shared TypeScript: client, services, hooks, models
│   └── plugins/                # Plugin system + AI plugin example
│
├── frontend/                   # Flutter app (PRIMARY active client)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models.dart
│   │   ├── pages/
│   │   ├── services/
│   │   └── widgets/
│   ├── android/
│   ├── ios/
│   ├── macos/
│   ├── linux/
│   ├── windows/
│   └── web/
│
└── docs/
    ├── PRODUCT_VISION.md
    ├── FEATURES_AND_REQUIREMENTS.md
    ├── FLUTTER_FRONTEND_ARCHITECTURE.md
    ├── ACORDE_INTEGRATION.md
    ├── SYNC_AND_PAIRING_MODEL.md
    ├── PAIRING_REACHABILITY.md
    ├── REMOTE_SYNC_BUILD_PLAN.md
    ├── SCREEN_SPECIFICATION.md
    └── UI_UX_REQUIREMENTS.md
```

---

## 4. The ACORDE Backend Contract

ACORDE is an external Go binary (not part of this repo). Relix talks to it via REST over `localhost:7331`.

### Guaranteed REST Routes

| Method | Route | Purpose |
|--------|-------|---------|
| GET | `/entries` | List entries (filter by `type`, `tag`, `limit`, `offset`) |
| POST | `/entries` | Create entry |
| GET | `/entries/:id` | Get single entry |
| PUT | `/entries/:id` | Update entry |
| DELETE | `/entries/:id` | Delete entry (tombstone, not hard delete) |
| POST | `/entries/:id/authorize` | Grant writer access to a peer |
| GET | `/identity` | Get local peer identity |
| GET | `/peers` | Get connected/known peers |
| POST | `/invite` | Generate a pairing invite code |
| POST | `/pair` | Accept an invite code to pair a device |
| GET | `/status` | Get daemon health and sync status |
| GET | `/events` | SSE stream for real-time events |

### Entry Schema

Every entry has these fields:

```json
{
  "id": "uuid",
  "type": "note | log | file | event",
  "content": "<base64-encoded JSON>",
  "tags": ["tag1", "tag2"],
  "created_at": 1700000000,
  "updated_at": 1700000001,
  "deleted": false,
  "owner": "peer-id"
}
```

**Critical wire detail:** `content` is stored as `[]byte` and exposed as **base64-encoded JSON**. All clients must decode base64 before parsing content as JSON.

### What Is NOT Guaranteed (Do Not Use)

- `GET /search` — not in REST contract
- `GET /entries/:id/versions` — not supported
- `GET /entries/:id/acl` — not supported
- `PUT /entries/:id/acl/public` — not supported

### Startup Command

```bash
acorde daemon --data ./data --port 4001 --api-port 7331
```

---

## 5. Frontend Platforms

### Primary: Flutter (`frontend/`)

This is the **active development target** for the current branch. It targets Flutter Web, Desktop (macOS, Windows, Linux), and Mobile (iOS, Android) from a single codebase.

### Legacy/Reference: TypeScript Apps (`apps/`)

These exist for historical reference and are not the active development focus:
- `apps/web` — Next.js 14 app (has a complete UI but is not the primary client)
- `apps/mobile` — React Native / Expo app with offline mutation queue
- `apps/desktop` — Electron wrapper around `apps/web`

All documentation should be read through the lens of **Flutter as the primary client**.

---

## 6. Core Package (`@relix/core`)

The `packages/core` package is a shared TypeScript library used by `apps/web`, `apps/mobile`, and `apps/desktop`. The Flutter app has its own equivalent implementation in Dart.

### Key Exports

**Client:**
- `AcordeClient` — direct HTTP wrapper for all ACORDE REST endpoints

**Services:**
- `NoteService` — CRUD + wikilink resolution + backlink querying
- `GraphService` — builds graph data from notes and outlink tags
- `FileService` — blob upload/download + file entry management
- `ExportService` — Markdown export and ZIP bundling
- `P2PService` — identity, peers, invite generation, pairing
- `ConnectionService` — manages polling loop, SSE subscription, state aggregation
- `PairedPeersStore` — durable storage of peer metadata (nicknames, timestamps)

**Hooks (React):**
- `useNotes`, `useNote`, `useBacklinks`, `useCreateNote`, `useUpdateNote`, `useDeleteNote`
- `useGraph`, `useNeighbors`, `useRelatedNotes`
- `useConnectionState`, `ConnectionProvider`
- `useConflictDetection`
- `useVaultStatus`, `useHealthCheck`

**Models (TypeScript types):**
- `Note`, `NoteContent`, `Entry`, `EntryType`
- `RemotePeer`, `LocalIdentity`, `PairedPeerMetadata`
- `ConnectionState`, `ConnectionType`, `RelayStatus`
- `Graph`, `GraphNode`, `GraphEdge`

### Storage Adapter Pattern

The core package uses a pluggable `RuntimeStorageAdapter` interface so the same services work in browsers (localStorage) and React Native (AsyncStorage):

```typescript
configureRuntimeStorage({
  getItem: AsyncStorage.getItem.bind(AsyncStorage),
  setItem: async (key, value) => AsyncStorage.setItem(key, value),
  removeItem: AsyncStorage.removeItem.bind(AsyncStorage),
});
```

---

## 7. Flutter Frontend (Primary Target)

### Architecture Layers

The Flutter app follows a clean layered architecture:

**Layer 1 — Entry Point:** `lib/main.dart`
- Initializes Flutter bindings
- Creates `RelixController`
- Calls `controller.initialize()`
- Mounts `RelixApp` → `HomePage`

**Layer 2 — Application State:** `lib/services/relix_controller.dart`
- Central coordinator (extends `ChangeNotifier`)
- Holds the single `SyncSnapshot` state object
- Manages polling timer (every 5 seconds)
- Coordinates all service calls
- Handles optimistic local writes + mutation queue drain

**Layer 3 — Service Layer:**

| File | Responsibility |
|------|---------------|
| `acorde_client.dart` | HTTP wrapper for all ACORDE REST routes |
| `note_service.dart` | Note CRUD, wikilink extraction, backlink queries |
| `graph_service.dart` | Graph construction from notes and outlink tags |
| `file_service.dart` | File/blob operations |
| `export_service.dart` | Export to Markdown/ZIP, share via OS share sheet |
| `local_store.dart` | SharedPreferences persistence (notes, queue, peers) |

**Layer 4 — Model Layer:** `lib/models.dart`
- `NoteContent`, `NoteEntry`, `LocalIdentity`, `RemotePeer`
- `MutationPayload`, `SyncSnapshot`
- `GraphNode`, `GraphEdge`, `GraphData`

**Layer 5 — Presentation Layer:**

| Page | File |
|------|------|
| Home Shell | `pages/home_page.dart` |
| Notes List | `pages/notes_page.dart` |
| Note Detail | `pages/note_detail_page.dart` |
| Note Editor | `pages/note_editor_page.dart` |
| Settings/Fleet | `pages/settings_page.dart` |
| Graph View | `pages/graph_page.dart` |

Widgets: `connection_banner.dart`, `glass_card.dart`, `note_card.dart`

### State Management

State flows through `SyncSnapshot`, an immutable snapshot object with `copyWith()`:

```dart
class SyncSnapshot {
  final LocalIdentity? identity;
  final List<RemotePeer> peers;
  final List<NoteEntry> notes;
  final String baseUrl;
  final int pendingChanges;
  final int stuckMutations;
  final bool daemonReachable;
  final bool initialized;
  // ...
}
```

The `RelixController` calls `notifyListeners()` after any state change, and the `AnimatedBuilder` at the root of `RelixApp` re-renders.

### Refresh Cycle

On each 5-second poll tick:
1. Health check (`/status`)
2. If offline → update snapshot with `daemonReachable: false`, show cache
3. If online → parallel fetch: identity, peers, status, notes
4. Merge remote notes with local mutation queue
5. Drain mutation queue
6. Update snapshot + notify listeners

### Mutation Queue (Offline-First)

When the user creates/edits/deletes a note:
1. UI updates optimistically (note appears instantly)
2. `MutationPayload` is persisted to `SharedPreferences`
3. `pendingChanges` count increments
4. Background drain retries when ACORDE is reachable
5. After 5 failed retries → mutation moves to `stuckMutations`
6. User can clear stuck mutations from Settings

### Peer Management

Flutter app maintains its own peer metadata layer on top of ACORDE:
- Persisted in `SharedPreferences` under `relix.peers_meta`
- Tracks `nickname`, `firstPairedAt`, `lastSeenAt`, `lastSyncAt`
- Merges with ACORDE `/peers` response on each refresh

---

## 8. Web App (`apps/web`)

### Tech Stack

- Next.js 14 (App Router)
- React with `@tanstack/react-query` for data fetching
- CodeMirror 6 for the Markdown editor
- `@relix/core` for all service logic

### Page Structure

| Route | Component | Purpose |
|-------|-----------|---------|
| `/` | `page.tsx` | Dashboard: greeting, recent notes, quick actions |
| `/notes` | `notes/page.tsx` | Notes list with search, pagination |
| `/notes/[id]` | `notes/[id]/page.tsx` | Note editor with backlinks, conflict detection |
| `/notes/new` | `notes/new/page.tsx` | New note with template selection |
| `/graph` | `graph/page.tsx` | Physics-based force graph canvas |
| `/files` | `files/page.tsx` | File upload area (placeholder) |
| `/settings` | `settings/page.tsx` | Fleet status, pairing, export |

### Key Components

- **`MarkdownEditor`** — CodeMirror 6 editor with wikilink highlighting, Mod+B/I/L shortcuts
- **`CommandPalette`** — `Cmd+K` overlay for navigation and note search
- **`QuickCapture`** — `Cmd+Shift+N` floating note creation widget
- **`ConflictBanner` / `ConflictModal`** — sync conflict detection UI
- **`FileTree`** — Obsidian-style file explorer sidebar (tags as folders)
- **`NavRail`** — Vertical navigation sidebar
- **`ConnectionProvider`** — starts/stops the `ConnectionService` polling loop

### Graph Visualization

The graph page runs a custom physics simulation directly on an HTML5 Canvas element using `requestAnimationFrame`. It applies repulsion between all nodes and spring attraction along edges, converging toward the canvas center. Clicking a node navigates to the note.

### Design System

Dark glassmorphism aesthetic defined in `globals.css`:
- Deep cosmic purple-black background (`#030014`)
- Aurora mesh gradient animation (20-second cycle)
- `--accent`: Violet `#8b5cf6`
- `--accent-cyan`: `#06b6d4`
- `--accent-rose`: `#f43f5e`
- Glass panel utility classes: `.glass-panel`, `.glass-card`

---

## 9. Mobile App (`apps/mobile`)

### Tech Stack

- React Native / Expo (SDK ~50)
- Expo Router for file-based navigation
- `@tanstack/react-query` for data fetching
- `@react-native-async-storage/async-storage` for persistence

### Offline Architecture

The mobile app has a complete offline-first mutation queue in `src/offline/`:

**`noteCache.ts`** — AsyncStorage-backed note cache:
- `getCachedNotes()`, `setCachedNotes()`
- `getCachedNote(id)`, `setCachedNote(note)`
- `upsertCachedNote(note)` — adds to list + individual key
- `replaceCachedNoteId(tempId, note)` — replaces local ID with server ID after create sync
- `mergeRemoteNotes(remoteNotes)` — merges server data with local pending/offline notes

**`mutationQueue.ts`** — Durable mutation queue:
- Supports `create`, `update`, `delete` mutations
- Tracks `attempts` count per mutation
- Promotes to stuck queue after `MAX_MUTATION_ATTEMPTS = 5`
- Maintains a `NOTE_ALIAS_KEY` map: `tempId → serverId` for created notes
- `drainMutationQueue()` — processes queue items in order, breaks on first failure

**`OfflineSyncProvider.tsx`** — Background sync provider:
- Drains queue every 15 seconds (`DRAIN_INTERVAL_MS`)
- Also drains on `AppState` change to `'active'`
- Also drains when `connectionService` detects daemon reachable

### ACORDE URL Detection

`src/acordeHost.ts` auto-detects the ACORDE URL from Expo's Metro script URL (works for physical device testing where `localhost` doesn't work). Falls back to stored URL or `http://localhost:7331`.

### Screen Flow

```
/ (index) → Note list with pull-to-refresh
         → /note/[id] (detail + edit)
         → /note/create (new note)
         → /settings (pairing, fleet)
```

---

## 10. Desktop App (`apps/desktop`)

### Tech Stack

- Electron 28
- TypeScript in main process
- Loads `apps/web` as the renderer (URL: `http://localhost:3000` in dev, or static export in production)

### ACORDE Lifecycle Management

`apps/desktop/src/main.ts` handles starting/stopping the ACORDE daemon:

- Searches for the ACORDE binary in: `ACORDE_BIN` env var, project root, app path, `process.cwd()`
- Starts the daemon with: `acorde daemon --data <userData>/acorde-data --port 4001 --api-port 7331`
- Pipes daemon logs to `<userData>/acorde-data/acorde.log`
- Auto-restarts once if the daemon exits unexpectedly
- Kills daemon cleanly on `before-quit`

### Loading Screen

Shows an HTML loading screen while waiting for the Next.js dev server, with a timeout of 30 seconds (`DEV_SERVER_TIMEOUT_MS`).

### Preload Script

`preload.ts` exposes a safe `window.electron` API to the renderer:
- `platform` — OS platform string
- `getVersion()` — app version via IPC
- `openFile()`, `saveFile(data)` — file operations (future use)
- `showNotification(title, body)` — native notifications

---

## 11. Data Flow & Sync Model

### End-to-End Note Create Flow

```
User taps "+ New Note"
       │
       ▼
Create optimistic local note (temp ID = "local-<timestamp>-<random>")
       │
       ├─→ Add to snapshot.notes (UI updates immediately)
       ├─→ Persist to SharedPreferences / AsyncStorage
       └─→ Enqueue MutationPayload { type: 'create', noteId: tempId, ... }
                    │
                    ▼ (on next refresh or drain trigger)
            Try: noteService.create(title, body, tags)
                    │
                    ├─ Success: ACORDE returns real entry
                    │         → Replace temp ID with real ID everywhere
                    │         → Remove mutation from queue
                    │
                    └─ Failure: increment attempts
                               After 5 failures → stuck queue
```

### Note Content Encoding

Notes stored in ACORDE have their `content` field as base64-encoded JSON:

```json
// Wire format from ACORDE:
{ "content": "eyJ0aXRsZSI6ICJIZWxsbyIsICJib2R5IjogIldvcmxkIn0=" }

// After base64 decode:
{ "title": "Hello", "body": "World" }
```

Both the Flutter `AcordeClient` and the TypeScript `AcordeClient` handle this decode transparently.

### Wikilink System

Wikilinks (`[[Note Title]]`) are resolved to outlink tags on save:

1. Parse `[[...]]` patterns from note body
2. Search all notes for titles matching the wikilink text
3. For each match, add `outlink:<matched-note-id>` to the note's tags
4. The matched note gets `backlink:<this-note-id>` added by convention

Backlinks are queryable by filtering entries with `tag=outlink:<id>`.

### Connection States

```
offline      → daemon unreachable, working from cache
direct       → connected to at least one peer directly
relay        → connected through a relay (unverified capability)
unknown      → daemon reachable, no peers connected
```

### Relay / Internet Reachability

**Current status: Local network only, unverified for internet use.**

The pairing UI exists and works locally. Whether ACORDE invites contain public internet-reachable addresses, whether relay fallback works across NAT, and whether cross-network pairing succeeds — none of these have been verified end-to-end in this repository.

---

## 12. Current State of Each Area

### ✅ Implemented and Working

| Area | Status |
|------|--------|
| Note CRUD (create, read, update, delete) | Complete in Flutter + web + mobile |
| Offline note cache | Complete in Flutter + mobile |
| Offline mutation queue | Complete in Flutter + mobile |
| Pending sync badges | Complete (shows "PENDING_SYNC" on notes) |
| Pairing UI (invite generation) | Complete: text code + QR code |
| Pairing UI (accept invite) | Complete: paste code input |
| QR scanning for invites | Complete in `apps/mobile` (barcode scanner) |
| Peer list display | Complete (shows connected/saved peers) |
| Peer nickname editing | Complete |
| Settings: daemon URL override | Complete |
| Graph view | Basic: physics force-directed canvas |
| Export: single note to Markdown | Complete |
| Export: all notes to ZIP | Complete (Flutter uses `archive` package, web uses JSZip) |
| Connection banner | Complete (online/offline status) |
| Stuck mutation display + clear | Complete |
| Dark theme / glassmorphism UI | Complete |
| Knowledge graph (nodes + edges) | Complete via outlink tags |
| CommandPalette (web) | Complete |
| QuickCapture widget (web) | Complete |
| Markdown editor with wikilinks (web) | Complete (CodeMirror 6) |
| Markdown preview (Flutter) | Complete via `flutter_markdown` |

### ⚠️ Partially Implemented

| Area | Status |
|------|--------|
| Conflict detection | Basic: SSE event heuristic only, no real merge |
| File/blob management | Service layer exists, UI is placeholder |
| Native QR scanning (Flutter) | Not yet added to Flutter (`apps/mobile` has it) |
| Desktop daemon lifecycle | Partially done — starts daemon but no health monitoring |
| Search | Client-side filtering only (no `/search` ACORDE endpoint) |
| Relay/internet sync | UI labeled "local network only" — unverified |

### ❌ Not Yet Implemented

| Area | Status |
|------|--------|
| Verified internet-wide pairing | Not done |
| Full conflict resolution UI (diff/merge) | Not done |
| File browsing in Flutter | Not done |
| Attachment linking (notes ↔ files) | Not done |
| Version history | ACORDE has no REST endpoint for this |
| ACL/sharing management | ACORDE has no REST endpoint for this |
| Native QR scanner in Flutter | Not done |
| First-run onboarding | Not done |
| Note templates in Flutter | Not done (exists in web) |

---

## 13. What Needs to Be Done — Full Task Breakdown

### A. Backend Contract Reconciliation (BLOCKER)

The `docs/ACORDE_INTEGRATION.md` says routes like `/identity`, `/peers`, `/invite`, `/pair` are not guaranteed — but the entire codebase already uses them. This contradiction must be resolved.

**Tasks:**
- [ ] **A1.** Verify which ACORDE routes actually exist in the current binary
- [ ] **A2.** Update `docs/ACORDE_INTEGRATION.md` to reflect reality (add the identity/peer/invite/pair routes to the guaranteed contract)
- [ ] **A3.** Document the exact request/response shapes for `/identity`, `/peers`, `/invite`, `/pair`
- [ ] **A4.** Add capability probe to `AcordeClient` (gracefully degrade if a route is missing)
- [ ] **A5.** Conduct ACORDE transport audit: what protocols are enabled? (TCP, QUIC, WebSockets, WebRTC, mDNS, relay, AutoNAT, DHT?)
- [ ] **A6.** Document what's inside an invite code: peer ID only? multiaddrs? relay hints? authorization token?

### B. Flutter — Native QR Scanner

**Tasks:**
- [ ] **B1.** Add QR scanner dependency to `frontend/pubspec.yaml` (e.g., `mobile_scanner` or `qr_code_scanner`)
- [ ] **B2.** Implement QR scan flow in `pages/settings_page.dart`
- [ ] **B3.** Test scanning QR codes generated by the web app and other devices
- [ ] **B4.** Add QR code display for invite generation (already uses `qr_flutter` package — verify it works)

### C. Flutter — Conflict Resolution

**Tasks:**
- [ ] **C1.** Add a "check for remote changes" mechanism in `note_detail_page.dart` (the stub exists: `_checkUpdates()`)
- [ ] **C2.** Implement `fetchLatestRemoteNote(id)` in `RelixController` (stub exists, needs real comparison logic)
- [ ] **C3.** Design and implement a conflict resolution dialog: show local vs. remote content side-by-side
- [ ] **C4.** Add "Load Remote Copy" action to note editor
- [ ] **C5.** Track `baselineUpdatedAt` per note to detect divergence accurately

### D. Desktop — Daemon Lifecycle Hardening

**Tasks:**
- [ ] **D1.** Add daemon health monitoring loop to `apps/desktop/src/main.ts` (poll `/status` on an interval)
- [ ] **D2.** Show daemon status in the Electron tray icon or title bar
- [ ] **D3.** Add daemon log viewer accessible from the app
- [ ] **D4.** Handle the case where `acorde` binary is not found: show clear error UI, not just a dialog
- [ ] **D5.** Bundle the ACORDE binary with the Electron build (update `electron-builder` config in `apps/desktop/package.json`)
- [ ] **D6.** Test packaged builds (not just `npm run dev`) on macOS, Windows, Linux

### E. Flutter — File & Attachment Support

**Tasks:**
- [ ] **E1.** Implement file browsing page in Flutter (list file entries from ACORDE)
- [ ] **E2.** Implement file upload flow (use `file_picker` package — already in `pubspec.yaml`)
- [ ] **E3.** Implement file download/open flow (use `share_plus` or `path_provider`)
- [ ] **E4.** Link files to notes (attach via tag or wikilink)
- [ ] **E5.** Display file metadata (name, size, MIME type, upload date)

### F. Flutter — Search

**Tasks:**
- [ ] **F1.** Client-side search already works (filter by title/body/tags in `notes_page.dart`) — verify it performs adequately for large vaults
- [ ] **F2.** If ACORDE adds a `/search` endpoint, wire it up in `acorde_client.dart` and `note_service.dart`
- [ ] **F3.** Add search to note detail (highlight matching text in body)

### G. Web App — Production Readiness

**Tasks:**
- [ ] **G1.** Fix the `apps/web/src/hooks/useNotes.ts` — it appears to be a binary file in the digest, needs investigation
- [ ] **G2.** Add error boundaries for query failures
- [ ] **G3.** Test the graph page with large note collections (100+ notes)
- [ ] **G4.** Add pan/drag support to the graph canvas (mouse drag for panning)
- [ ] **G5.** Implement zoom controls for the graph (mouse wheel or buttons)
- [ ] **G6.** Implement the `files/page.tsx` upload flow (currently only stores files in component state, never uploads to ACORDE)
- [ ] **G7.** Add proper loading states and skeleton screens
- [ ] **G8.** Test the Electron build with the web export (`next build` → `loadFile` mode)

### H. Mobile — Improve UX

**Tasks:**
- [ ] **H1.** Replace the manual "Bridge URL" entry in settings with pairing-first UX (the current UI still emphasizes URL entry)
- [ ] **H2.** Add pairing success/failure feedback (Alert is too disruptive — use a toast/banner)
- [ ] **H3.** Add pull-to-refresh reliability improvement (sometimes `drainMutationQueue` fails silently)
- [ ] **H4.** Add swipe-to-delete on note cards
- [ ] **H5.** Add search/filter to the notes list

### I. Sync & Relay

**Tasks:**
- [ ] **I1.** Verify cross-network pairing end-to-end (two devices on different networks, no LAN)
- [ ] **I2.** Determine if ACORDE includes public internet-reachable addresses in invite codes
- [ ] **I3.** Determine if ACORDE has relay fallback (libp2p circuit relay)
- [ ] **I4.** Update the reachability badge in UI based on actual verified capability
- [ ] **I5.** Add per-peer sync telemetry: lag indicator, direct vs. relay indicator

### J. Testing

**Tasks:**
- [ ] **J1.** Fix the failing Flutter test (`test/app_test.dart` — looks for "Your Vault" text which may not exist in current UI)
- [ ] **J2.** Add widget tests for `NoteCard`, `ConnectionBanner`, `SettingsPage`
- [ ] **J3.** Add integration tests for the mutation queue (create note offline → come online → verify sync)
- [ ] **J4.** Add TypeScript unit tests in `packages/core` (Vitest is already configured — `vitest run`)
- [ ] **J5.** Add end-to-end cluster tests using `verify_cluster_sync.sh` as a model

### K. Documentation

**Tasks:**
- [ ] **K1.** Update `docs/ACORDE_INTEGRATION.md` (see A2)
- [ ] **K2.** Write a proper README for `frontend/` with setup instructions
- [ ] **K3.** Write a developer quickstart: how to run Relix from scratch (clone → install ACORDE → `./start-all.sh`)
- [ ] **K4.** Document the app ID/bundle ID that needs to be changed before release (`com.example.relix_flutter`)
- [ ] **K5.** Add CHANGELOG.md

---

## 14. Phase-by-Phase Implementation Plan

This section translates the task list into a recommended execution order based on the existing `docs/REMOTE_SYNC_BUILD_PLAN.md`.

### Phase 0: Resolve the Contract Mismatch (1-2 days)

**Goal:** Stop contradicting the existing client code in the documentation.

- Complete tasks A1, A2, A3
- Update `docs/ACORDE_INTEGRATION.md` to accurately reflect what the codebase uses
- This unblocks everything else

### Phase 1: Stabilize the ACORDE Interface (3-5 days)

**Goal:** Have a typed, documented, tested interface between Relix and ACORDE.

- Complete tasks A4, A5, A6
- Add capability detection to `AcordeClient` (Flutter and TypeScript versions)
- Create the transport compatibility matrix document

### Phase 2: Flutter Feature Completeness (1-2 weeks)

**Goal:** Flutter app is feature-complete for the core PKM use case.

- Complete tasks B1-B4 (native QR)
- Complete tasks E1-E5 (file management)
- Complete tasks F1-F3 (search improvements)
- Fix the failing test (J1)

### Phase 3: Pairing UX Improvements (1 week)

**Goal:** First-run and pairing experience feels polished and device-centric.

- Complete tasks H1-H2 (mobile pairing UX)
- Add first-run onboarding screen
- Test QR invite flow across iOS/Android/macOS/Web

### Phase 4: Conflict Handling (1 week)

**Goal:** Users can understand and resolve conflicts from multi-device editing.

- Complete tasks C1-C5
- Design and implement the diff/merge UI
- Add conflict recovery test cases

### Phase 5: Desktop Hardening (1 week)

**Goal:** Desktop app is a real packaged local-first runtime.

- Complete tasks D1-D6
- Bundle ACORDE binary in the Electron build
- Test packaged builds on all platforms

### Phase 6: Relay & Internet Sync (TBD — depends on ACORDE capabilities)

**Goal:** Cross-network pairing works reliably.

- Complete tasks I1-I5
- Update reachability UI based on verified capability
- Add relay-specific UX if ACORDE supports it

### Phase 7: Polish & Release Preparation (1 week)

**Goal:** App is ready for real users.

- Update bundle IDs from `com.example.*` to production values
- Complete task K2-K5 (documentation)
- Add crash reporting / analytics hooks
- Submit to app stores (iOS, Android, macOS)

---

## 15. Known Bugs & Issues

### Bug 1: `useNotes.ts` Appears as Binary File

`packages/core/src/hooks/useNotes.ts` is listed as `[Binary file]` in the codebase digest. This file is a core hook that `apps/web` imports. If it's actually binary, the web app will fail to compile. **Needs immediate investigation.**

### Bug 2: Flutter Test Assertion Mismatch

`frontend/test/app_test.dart` asserts `find.text('Your Vault')` exists in the home page, but the current `home_page.dart` uses "PERSONAL VAULT" as the section title and "Memoranda Index" for the notes list — the assertion will fail. The test needs updating.

### Bug 3: Desktop Preload IPC Not Wired

`apps/desktop/src/preload.ts` exposes `getVersion()` via IPC, but `apps/desktop/src/main.ts` never registers the `ipcMain.handle('get-version', ...)` handler. Calling `window.electron.getVersion()` from the renderer will hang.

### Bug 4: Graph Canvas Has No Pan/Drag

The graph page in `apps/web/src/app/graph/page.tsx` has a `onMouseDown` handler stub with a comment "omitted for brevity during rewrite" — pan functionality was removed during refactoring and never restored.

### Bug 5: File Upload in Web is Simulated

`apps/web/src/app/files/page.tsx` has a `handleFiles()` function that simulates upload with `setTimeout(1000)` and stores files in React state — it never calls ACORDE. The `// TODO: Upload to ACORDE` comment confirms this.

### Bug 6: `simulate_sync.sh` Uses Hardcoded Binary Path

`simulate_sync.sh` assumes `./acorde` is in the current directory. It doesn't use the helper function from `start-all.sh` that tries multiple candidate paths. If the binary is elsewhere, the script will fail.

### Bug 7: ApplicationId Needs to Change Before Release

Both `frontend/android/app/build.gradle.kts` and the macOS `AppInfo.xcconfig` use `com.example.relix_flutter` and `com.example.relixFlutter`. These must be changed to a real bundle ID before app store submission.

---

## 16. Documentation Gaps

The following things are not documented anywhere and should be:

1. **How to build a packaged Electron release** — `npm run package` exists in `apps/desktop/package.json` but there's no docs on signing, notarization, or distribution.

2. **How to add a new plugin** — The plugin system in `packages/plugins/` has a good example but no getting-started guide.

3. **How the mutation queue handles ID aliasing** — The `NOTE_ALIAS_KEY` mechanism in `apps/mobile/src/offline/mutationQueue.ts` is sophisticated but undocumented.

4. **How to run the benchmark** — `packages/core/scripts/benchmark.ts` exists but no docs.

5. **What `connect_cluster.sh` requires** — It hardcodes a path `/home/amaydixit11/Desktop/dev/vaultd/acorde`. This personal path is checked into the repo.

6. **How to configure ACORDE for the Flutter app** — `start-all.sh` starts ACORDE and Flutter, but doesn't explain what to do when running on a physical mobile device (the ACORDE URL detection in `acordeHost.ts` vs. manual URL entry).

---

## 17. Testing Strategy

### Current Test Coverage

The project is significantly undertested. Existing tests:

- `frontend/test/app_test.dart` — 1 widget test (currently broken, see Bug 2)
- `frontend/ios/RunnerTests/RunnerTests.swift` — empty placeholder
- `frontend/macos/RunnerTests/RunnerTests.swift` — empty placeholder

No meaningful test coverage exists for:
- The mutation queue drain logic
- The note merge logic
- The wikilink extraction and resolution
- The peer metadata merge logic
- Any of the TypeScript services in `packages/core`

### Recommended Test Types

**Unit tests for `packages/core`:**
- Test `extractWikilinks()` with edge cases (nested brackets, empty links, special characters)
- Test `PairedPeersStore` — upsert, touch, forget, merge
- Test `NoteService` wikilink resolution pipeline
- Use Vitest (already configured: `"test": "vitest run --passWithNoTests"`)

**Widget tests for Flutter:**
- `NoteCard` renders title, body preview, tags correctly
- `ConnectionBanner` shows correct message for online/offline states
- `NoteEditorPage` can save a note (with a mocked `RelixController`)

**Integration tests:**
- Create note offline → start ACORDE → verify sync completes
- Pair two local ACORDE instances → create note on one → verify appears on other

**End-to-End scripts:**
- `verify_cluster_sync.sh` already demonstrates the right pattern — formalize it into a CI-runnable test

---

## 18. Naming Conventions & Code Style

### Flutter (Dart)

- Services: `camelCase` class names ending in `Service` or `Controller`
- Pages: `PascalCase` ending in `Page`
- Widgets: `PascalCase` ending in widget type or descriptive name
- Private methods: `_camelCase`
- Constants: `UPPER_SNAKE_CASE` for compile-time, `camelCase` for final fields

### TypeScript

- Services: `PascalCase` class + `camelCase` singleton export (e.g., `NoteService` + `noteService`)
- Hooks: `use` prefix (e.g., `useNotes`, `useConnectionState`)
- Types/Interfaces: `PascalCase` (e.g., `RemotePeer`, `ConnectionState`)
- Query keys: `const xyzKeys = { all: [...], detail: (id) => [...] }` pattern

### ACORDE Tag Conventions

Tags are string arrays on every entry. Relix uses prefixed tags for internal linking:
- `outlink:<id>` — this note contains a wikilink to note with `<id>`
- `backlink:<id>` — this note is linked from note with `<id>` (informational, may be derived)
- All other tags are user-defined and should be displayed in the UI

### ID Conventions

- Real note IDs: UUID format (`[0-9a-f]{8}-[0-9a-f]{4}-...`)
- Temporary local IDs: `local-<timestamp>-<random>` (Flutter) or `local-note-<timestamp>-<random>` (mobile)
- Mutation IDs: `mutation-<timestamp>-<random>`

---

## Summary: Top 10 Priority Tasks

If you had to pick the highest-impact tasks to do first, they are:

1. **Resolve the ACORDE contract mismatch** (A1, A2) — documentation contradicts code; fix this first
2. **Fix `useNotes.ts` binary file issue** (G1) — web app may not compile; needs immediate investigation
3. **Fix the Flutter test** (J1) — broken tests block CI confidence
4. **Add native QR scanner to Flutter** (B1-B4) — major UX gap for the primary client
5. **Fix graph canvas pan/drag** (G4) — the graph is unusable without panning
6. **Fix desktop IPC handler gap** (D1) — `getVersion()` call hangs the renderer
7. **Implement file upload in web** (G6) — currently simulated, never reaches ACORDE
8. **Change bundle IDs before shipping** (K4) — `com.example.*` must not go to app stores
9. **Fix `connect_cluster.sh` hardcoded personal path** — blocks other developers from using this tool
10. **Write developer quickstart** (K2, K3) — new contributors cannot easily get started

---

*Document generated from full codebase analysis of the Relix monorepo. All file paths, feature states, and architectural details are derived directly from the source code.*