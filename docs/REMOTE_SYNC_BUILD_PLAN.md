# Relix Remote Sync Build Plan

This plan grounds the remote-sync work in the current Relix codebase instead of starting from a blank-sheet architecture.

## Current State Audit

### What already exists in Relix

- `@relix/core` already assumes these ACORDE routes exist:
  - `GET /identity`
  - `GET /peers`
  - `POST /invite`
  - `POST /pair`
  - `GET /status`
  - `GET /events`
- The client and service layer already expose identity and pairing primitives:
  - [`packages/core/src/client/acorde.ts`](/home/amaydixit11/Desktop/dev/Relix/packages/core/src/client/acorde.ts)
  - [`packages/core/src/services/P2PService.ts`](/home/amaydixit11/Desktop/dev/Relix/packages/core/src/services/P2PService.ts)
- The shared model layer already has basic peer and identity types:
  - [`packages/core/src/models/types.ts`](/home/amaydixit11/Desktop/dev/Relix/packages/core/src/models/types.ts)
- The web settings screen already supports:
  - showing local peer identity
  - generating invite codes
  - pairing with an invite code
  - showing connected-peer count
  - file: [`apps/web/src/app/settings/page.tsx`](/home/amaydixit11/Desktop/dev/Relix/apps/web/src/app/settings/page.tsx)
- The mobile settings screen already supports:
  - showing local identity
  - manual server URL entry
  - manual invite-code pairing
  - QR scanning for invites
  - listing peers
  - file: [`apps/mobile/app/settings.tsx`](/home/amaydixit11/Desktop/dev/Relix/apps/mobile/app/settings.tsx)
- The mobile app already has read-through caching for note list and note detail views using AsyncStorage:
  - [`apps/mobile/app/index.tsx`](/home/amaydixit11/Desktop/dev/Relix/apps/mobile/app/index.tsx)
  - [`apps/mobile/app/note/[id].tsx`](/home/amaydixit11/Desktop/dev/Relix/apps/mobile/app/note/[id].tsx)

### What is missing or materially incomplete

- The integration contract doc still says Relix must not assume any REST routes beyond `/entries`, `/status`, and `/events`.
  - file: [`docs/ACORDE_INTEGRATION.md`](/home/amaydixit11/Desktop/dev/Relix/docs/ACORDE_INTEGRATION.md)
- Mobile still thinks in terms of a daemon URL, not peer identity.
- Mobile caching is read-only fallback, not offline-first sync.
- Create, update, and delete operations fail when offline instead of queuing.
- Conflict detection is only an SSE heuristic and does not model actual divergent edits.
  - file: [`packages/core/src/hooks/useConflictDetection.ts`](/home/amaydixit11/Desktop/dev/Relix/packages/core/src/hooks/useConflictDetection.ts)
- Desktop does not manage daemon lifecycle yet.
  - file: [`apps/desktop/src/main.ts`](/home/amaydixit11/Desktop/dev/Relix/apps/desktop/src/main.ts)
- There is no Relix-side connection manager, pairing persistence layer, or per-peer sync model.

### Important mismatch to resolve first

Relix already uses identity and pairing endpoints in code, but the published ACORDE integration contract says those routes are not guaranteed. That inconsistency is the first blocker.

There are only two clean options:

1. Update ACORDE's published REST contract so `/identity`, `/peers`, `/invite`, and `/pair` are formally supported.
2. Remove those assumptions from Relix and gate the UI behind capability detection.

The recommended path is option 1, because the product already depends on those routes and the pairing UI is built around them.

## Build Strategy

## Phase 0: ACORDE Capability Audit

Before expanding the Relix UI further, verify what ACORDE actually supports today.

Questions to answer:

- What transports are enabled in ACORDE now: TCP, QUIC, WebSockets, WebRTC?
- Does ACORDE already support:
  - libp2p relay
  - AutoNAT
  - hole punching
  - mDNS
  - rendezvous or DHT discovery
- What fields are embedded in the current invite code:
  - peer ID only
  - peer ID plus multiaddrs
  - relay hint
  - authorization token
- Do `/identity`, `/peers`, `/invite`, and `/pair` already exist as stable API on the daemon, or are they local-only experiments?
- Does `/events` emit peer lifecycle events or only entry events?

Deliverable:

- A short compatibility matrix in `docs/` covering transport, discovery, relay, invite contents, and REST guarantees.

Exit criteria:

- Relix knows which capabilities are real and which must be built in ACORDE first.

## Phase 1: Stabilize the Relix-ACORDE Contract

This phase is about removing ambiguity from the interface Relix depends on.

Required outcomes:

- Update [`docs/ACORDE_INTEGRATION.md`](/home/amaydixit11/Desktop/dev/Relix/docs/ACORDE_INTEGRATION.md) so it matches reality.
- If ACORDE supports peer endpoints, document:
  - request and response shapes
  - error modes
  - invite expiration rules
  - whether addresses are LAN-only or internet-reachable
- If ACORDE does not guarantee those routes yet, add capability guards in the client instead of assuming availability.

Recommended client-side follow-up:

- Extend `AcordeClient` with a lightweight capability probe or typed error surface.
- Avoid hardcoding future assumptions like relay support until ACORDE exposes them.

Exit criteria:

- The code, docs, and daemon contract describe the same API surface.

## Phase 2: Move Relix from "Server URL" to "Peer-Aware"

The current codebase is in a hybrid state:

- web already talks to a local daemon by default
- mobile still persists `@relix/server_url`
- identity and peers exist, but they are not the primary UX model

Required work:

- Add richer models in [`packages/core/src/models/types.ts`](/home/amaydixit11/Desktop/dev/Relix/packages/core/src/models/types.ts):
  - `PairedPeer`
  - `PairingInvite`
  - `ConnectionState`
  - `PeerConnectionStatus`
- Keep the daemon base URL as a transport detail, not the user-facing primary setting.
- Introduce a `ConnectionService` in `@relix/core` responsible for:
  - loading local identity
  - loading peers
  - tracking daemon health
  - subscribing to events
  - exposing a normalized connection state for UI use

Exit criteria:

- UI can render identity, peer state, and daemon reachability from one shared source of truth.

## Phase 3: Replace Mobile Bridge Configuration

This is the highest-value product change inside Relix itself.

Current mobile behavior:

- user manually enters `http://192.168.x.x:7331`
- pairing exists, but the primary setup mental model is still "connect to a REST endpoint"

Required changes in [`apps/mobile/app/settings.tsx`](/home/amaydixit11/Desktop/dev/Relix/apps/mobile/app/settings.tsx):

- Replace "Bridge Configuration" with "This Device" and "Paired Devices"
- Keep a hidden or advanced daemon URL override for development only
- Make pairing the primary path:
  - scan QR
  - paste invite
  - show connection progress
  - show success and failure states
- Persist paired-peer metadata separately from daemon URL state

Recommended UX states:

- no daemon reachable
- daemon reachable, no peers paired
- paired but disconnected
- connected direct
- connected via relay

Exit criteria:

- First-run mobile setup does not ask normal users for an IP address.

## Phase 4: Real Offline-First Mobile Data

The current mobile caching layer is only sufficient for read fallback.

Existing read cache:

- note list cache in [`apps/mobile/app/index.tsx`](/home/amaydixit11/Desktop/dev/Relix/apps/mobile/app/index.tsx)
- note detail cache in [`apps/mobile/app/note/[id].tsx`](/home/amaydixit11/Desktop/dev/Relix/apps/mobile/app/note/[id].tsx)

Required work:

- Introduce a local persistence layer for:
  - cached notes
  - pending mutations
  - sync metadata
  - per-note dirty state
- Convert create, update, and delete flows to optimistic local writes.
- Add a mutation queue that retries when connectivity returns.
- Reflect pending-sync state in the UI.

Implementation note:

- AsyncStorage is acceptable for a first pass.
- If vault size or query complexity grows, move to SQLite.

Exit criteria:

- Mobile create/edit/delete works without a live daemon connection and syncs later.

## Phase 5: Pairing Persistence and Peer Management

Relix needs its own peer metadata even if ACORDE stores cryptographic pairing state internally.

Required work:

- Add persistence for:
  - peer nickname
  - first paired timestamp
  - last seen timestamp
  - last successful sync timestamp
  - last known connection type
- Add peer management UI in both web and mobile:
  - rename peer
  - remove or forget peer
  - show current status
  - show last sync

Web target file:

- [`apps/web/src/app/settings/page.tsx`](/home/amaydixit11/Desktop/dev/Relix/apps/web/src/app/settings/page.tsx)

Mobile target file:

- [`apps/mobile/app/settings.tsx`](/home/amaydixit11/Desktop/dev/Relix/apps/mobile/app/settings.tsx)

Exit criteria:

- Pairing is no longer a one-shot action with no durable product state around it.

## Phase 6: Improve Sync Telemetry

Current sync status is too coarse.

Existing model:

- `connected`
- `peer_id`
- `peers`
- `last_sync`
- `pending_changes`

Required additions if ACORDE can expose them:

- peer-specific status
- per-peer lag or behind count
- direct vs relay connection type
- currently syncing indicator
- initial sync progress

Required Relix work:

- expand shared types
- add new hooks or service methods
- surface status in:
  - mobile status bar
  - web status bar
  - peer management panels

Exit criteria:

- Users can tell whether sync is healthy, degraded, or stalled.

## Phase 7: Conflict Handling

The current conflict hook is insufficient for real offline multi-device editing.

Current implementation:

- marks a conflict when an `updated` or `synced` event is observed for the same entry ID

Required work:

- distinguish:
  - remote update
  - local unsynced edit
  - true divergent edit
- store enough local revision context to know whether the local editor is editing stale content
- add a conflict-resolution UI instead of a boolean warning

Likely touch points:

- [`packages/core/src/hooks/useConflictDetection.ts`](/home/amaydixit11/Desktop/dev/Relix/packages/core/src/hooks/useConflictDetection.ts)
- mobile note edit screen
- web note editor

Exit criteria:

- Conflicts are explicit, inspectable, and recoverable.

## Phase 8: Desktop Runtime Integration

The desktop shell is still just an Electron wrapper around the web app.

Current state:

- loads the web UI
- does not start or monitor ACORDE
- file: [`apps/desktop/src/main.ts`](/home/amaydixit11/Desktop/dev/Relix/apps/desktop/src/main.ts)

Required work:

- start ACORDE on desktop launch
- monitor the daemon process
- expose restart and logs for debugging
- ensure app shutdown handles daemon lifecycle cleanly

Exit criteria:

- Desktop is a real packaged local-first runtime, not just a browser shell.

## Phase 9: Relay and Internet Reachability

This phase depends on the ACORDE audit.

Do not build Relix UI assuming relay semantics before the daemon side is clear.

Possible outcomes:

- ACORDE already has adequate relay and discovery support
- ACORDE needs a rendezvous service first
- ACORDE needs both rendezvous and relay fallback

Relix-side requirements once daemon support exists:

- show whether a peer is connected directly or through relay
- optionally expose custom relay configuration in advanced settings
- surface degraded connectivity clearly instead of pretending all connections are equal

Exit criteria:

- Cross-network pairing and sync work without requiring users to type LAN IP addresses.

## Recommended Implementation Order

1. Resolve the ACORDE contract mismatch.
2. Audit actual ACORDE transport and discovery capabilities.
3. Add a shared `ConnectionService` and richer peer models in `@relix/core`.
4. Replace mobile "server URL" setup with pairing-first UX.
5. Add offline mutation queue and pending-sync state on mobile.
6. Add durable peer management UI in web and mobile.
7. Improve sync telemetry and conflict handling.
8. Add desktop daemon lifecycle management.
9. Layer in relay-specific UX after ACORDE relay behavior is confirmed.

## Immediate Next Tasks

These are the next concrete engineering tasks that fit the current repo:

1. Update the integration docs to stop contradicting the existing client code.
2. Introduce a `ConnectionService` in `packages/core/src/services`.
3. Refactor mobile settings to demote manual daemon URL entry behind an advanced toggle.
4. Add a persistent local mutation queue for mobile note create and update flows.
5. Extend shared models to represent paired peers and connection state explicitly.
