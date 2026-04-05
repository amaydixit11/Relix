# Sync And Pairing Model

## Purpose

This document explains how Relix currently thinks about synchronization, pairing, reachability, and offline behavior.

## Conceptual Model

Relix has two layers:

1. ACORDE
2. Relix frontend

ACORDE is responsible for:

- data storage
- peer identity
- sync transport
- note CRUD backend

Relix is responsible for:

- local user-facing cache
- note UI
- pairing UI
- queued offline mutations
- displaying operational state

## Connection Model

The frontend always talks to one ACORDE REST endpoint at a time through a base URL.

Current default:

- `http://localhost:7331`

The app can override this in settings.

## Pairing Flow

### Current Flow

1. Device A requests invite from ACORDE.
2. ACORDE returns an invite code.
3. Relix shows the invite code as text and QR.
4. Device B submits the invite code.
5. Relix calls ACORDE `/pair`.
6. Peer state refreshes and paired devices appear in the fleet list.

### Important Product Truth

Pairing UI does not automatically mean universal reachability.

Whether a pair can sync across networks depends on ACORDE networking behavior, including:

- direct local addresses
- public reachability
- relay support
- NAT traversal behavior

This is why pairing and internet-wide sync must be documented separately.

## Refresh Model

The frontend controller polls every 5 seconds.

Each refresh attempts:

- health check
- identity
- peers
- status
- notes

This is a practical current-state implementation, not necessarily the final architecture.

## Offline Model

### Local Cache

The frontend persists:

- notes
- peers
- base URL
- queued mutations
- stuck mutations

### Mutation Queue

Mutation queue entries currently support:

- create
- update
- delete

### Drain Behavior

When ACORDE is reachable:

- queued mutations are replayed in order
- successful operations are removed
- repeated failures are moved to the stuck set

### User-Visible Consequences

- notes can still appear while offline
- edits can still be made
- pending-sync markers remain visible
- stuck-mutation count is shown in settings

## Conflict Model

The Flutter frontend currently supports basic conflict awareness, not full conflict resolution.

Current behavior:

- user can manually check for remote changes
- UI can warn about freshness mismatch

Not yet fully implemented:

- automatic semantic merge
- revision graph diffing
- full conflict timeline

## Peer Metadata Model

Relix keeps its own lightweight peer metadata alongside ACORDE’s internal pairing state.

This enables:

- nickname edits
- first paired time
- last seen time
- last sync time

## Reachability States

The frontend currently treats connection state as one of:

- `offline`
- `direct`
- `relay`
- `unknown`

This is a UI-facing abstraction used to communicate operating state to the user.

## Known Limitations

- refresh is polling-based
- internet reachability is still subject to ACORDE constraints
- native QR scanning is not yet present in the Flutter branch
- conflict handling is not yet rich enough for all multi-device edge cases

## Long-Term Desired Direction

- pairing-first setup
- identity-first mental model
- relay-aware reachability status
- event-driven refresh where possible
- explicit sync diagnostics for advanced users
