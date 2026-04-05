# Screen Specification

This document describes the major screens in the current Relix product and what each screen is responsible for.

## 1. Home Shell

### Purpose

Provide the global app structure, top-level navigation, and always-visible sync state.

### Current Implementation

- `frontend/lib/pages/home_page.dart`
- `frontend/lib/widgets/connection_banner.dart`

### Responsibilities

- render navigation rail on larger screens
- render bottom navigation on smaller screens
- show connection banner
- host page stack for:
  - Notes
  - Graph
  - Settings

## 2. Notes Page

### Purpose

Primary vault view.

### Current Implementation

- `frontend/lib/pages/notes_page.dart`
- `frontend/lib/widgets/note_card.dart`

### Responsibilities

- show note count
- render error state if refresh failed
- render empty state
- render note cards
- allow refresh
- launch note creation
- open note detail

### Data Needed

- `snapshot.notes`
- `snapshot.errorMessage`
- `snapshot.daemonReachable`

## 3. Note Detail Page

### Purpose

Read a single note and expose note-specific actions.

### Current Implementation

- `frontend/lib/pages/note_detail_page.dart`

### Responsibilities

- render full note body
- show note tags
- show updated time
- expose edit action
- expose delete action
- show pending-sync state
- show remote-change warning when detected

## 4. Note Editor Page

### Purpose

Create and edit notes.

### Current Implementation

- `frontend/lib/pages/note_editor_page.dart`

### Responsibilities

- title editing
- body editing
- tags editing
- save action
- optional conflict/freshness checks

### Requirements

- must support both create and edit
- must remain usable on narrow mobile screens
- save action should remain obvious and close to the top app chrome

## 5. Settings / Fleet Page

### Purpose

Operational control center for peer identity, fleet state, pairing, and advanced daemon configuration.

### Current Implementation

- `frontend/lib/pages/settings_page.dart`

### Responsibilities

- show local identity
- show pairing controls
- generate invite
- show invite QR
- paste invite code
- show paired peers
- edit peer nicknames
- show pending changes
- show stuck mutation count
- show advanced ACORDE base URL config

## 6. Graph / Neural Map Page

### Purpose

Show note relationships and linked structures in an exploratory format.

### Current Implementation

- `frontend/lib/pages/graph_page.dart`

### Responsibilities

- build graph data through graph service
- show empty graph state
- render nodes
- render connected edges per node

### Future Direction

- richer visual graph
- filtering
- interaction-based navigation back to notes

## 7. Dialogs And Supporting UI

### Invite Dialog

Current responsibilities:

- render QR code from invite string
- show full invite code
- allow copy action

### Banners

Used for:

- connection state
- pending sync
- errors
- conflict warnings

## Screen Relationships

Primary navigation graph:

1. Home shell
2. Notes page
3. Note detail
4. Note editor
5. Settings page
6. Graph page

The settings and notes flows are the most operationally important.
The graph flow is secondary and exploratory.

## Priority Order For Product Completeness

If implementation time is limited, priority should be:

1. Notes page
2. Note detail/editor
3. Settings/pairing
4. Connection banner/state
5. Graph page
