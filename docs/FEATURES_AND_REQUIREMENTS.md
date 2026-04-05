# Features And Requirements

This document describes the major product features Relix aims to provide, with emphasis on the current Flutter frontend target.

## 1. Notes

### Description

Relix supports structured note entries stored in ACORDE.

### Current Requirements

- list notes from ACORDE
- open a note detail screen
- create a note locally
- edit a note locally
- delete a note
- show tags
- show updated time
- show pending-sync state on a note

### Quality Requirements

- notes must remain viewable from cache when offline
- note mutations must not disappear if the daemon is temporarily unreachable
- note actions should feel near-instant even when sync is deferred

## 2. Offline Queue

### Description

Mutations should be durable when connectivity is lost.

### Current Requirements

- queue create operations
- queue update operations
- queue delete operations
- retry queued operations automatically
- mark items as stuck after repeated failures
- allow the user to clear the stuck-mutation log

### UX Requirements

- pending changes count should be visible at the app level
- pending state should be visible on notes
- the user should not have to manually re-enter data after a temporary failure

## 3. Pairing

### Description

Users pair devices through ACORDE invite flows, not account login.

### Current Requirements

- show local peer identity
- generate invite code
- display invite as QR
- paste invite code from another device
- complete pairing through ACORDE `/pair`

### Desired Future Additions

- native QR scanner
- device naming during pairing
- pairing success/failure event feedback
- clearer first-run onboarding

## 4. Peer Management

### Description

A user should understand which devices are in their fleet.

### Current Requirements

- list known peers
- show peer display name and ID
- show connection state
- show first-paired time
- show last-seen time
- show last-sync time
- allow peer nickname edits

## 5. Sync Status

### Description

Relix should surface connectivity and sync state as a first-class part of the product.

### Current Requirements

- daemon reachable or not
- connection mode: offline, direct, relay, unknown
- number of connected peers
- number of pending changes
- number of stuck mutations

### UI Requirements

- a persistent connection banner should exist at app level
- fleet settings should summarize operational state
- the app should not silently fail into stale state

## 6. Graph / Knowledge Map

### Description

Relix includes a graph-style view of relationships between entries.

### Current Requirements

- build graph data from ACORDE-backed notes
- show nodes and connected edges
- display linked relationships in a readable UI

### Future Requirements

- richer spatial graph visualization
- interactive filtering
- larger-scale performance tuning

## 7. Export

### Description

Users should be able to extract their data in open formats.

### Current Direction

- export services exist in the Flutter frontend service layer
- long-term expectation is open, user-readable formats like Markdown or archive bundles

## 8. Files / Attachments

### Description

Relix is intended to support stored files, not only notes.

### Current State

- file service exists in the Flutter frontend service layer
- this area is less mature than notes and pairing

### Future Requirements

- file browsing
- file metadata
- upload flow
- download/open flow
- attachment linkage to notes

## 9. Conflict Awareness

### Description

When multiple devices touch the same note, Relix should help the user understand what happened.

### Current Requirements

- detect remote freshness checks on demand
- surface remote-change warnings while editing

### Future Requirements

- revision-aware conflict detection
- merge assistance
- side-by-side conflict UX

## 10. Reachability Transparency

### Description

The app must not overpromise internet sync.

### Requirements

- document that remote reachability is still constrained by ACORDE networking capabilities
- distinguish clearly between:
  - local network pairing
  - direct internet reachability
  - relay-assisted operation
- avoid implying that QR pairing alone guarantees internet-wide sync
