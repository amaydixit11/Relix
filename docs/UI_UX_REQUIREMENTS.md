# UI / UX Requirements

This document defines the user experience requirements for Relix across Flutter web, desktop, and mobile.

## Visual Direction

Relix should feel:

- dark
- deliberate
- technical without being sterile
- premium without becoming ornamental

The current visual language in the Flutter frontend uses:

- deep slate backgrounds
- teal accent highlights
- translucent glass cards
- bold section labeling
- strong operational-state signaling

## Global UX Rules

### 1. Operational State Must Be Visible

The user should always be able to tell whether the app is:

- online
- offline
- syncing
- holding pending changes

This is why the app uses a top connection banner and fleet status panels.

### 2. Pairing Must Feel Device-Centric

Primary pairing UX should emphasize:

- local device identity
- invite generation
- invite acceptance
- fleet membership

It should not feel like login/account/authentication UX.

### 3. Advanced Configuration Must Be Secondary

Manual ACORDE base URL entry is an operational override.

Requirements:

- it must exist
- it must be accessible
- it must not dominate the primary happy path

### 4. Offline Work Must Feel Safe

The user should not feel that edits are being lost.

Requirements:

- pending change count visible
- note-level pending markers visible
- settings page shows stuck mutation count
- destructive operations should be explicit

### 5. Cross-Platform Consistency

The app should preserve one product identity across device classes.

Requirements:

- same major tabs on all platforms
- same core terminology
- similar cards, accents, and status semantics
- layout adapts, but meaning does not

## Information Architecture

The current top-level navigation model is:

- Notes / Vault
- Graph / Neural Map
- Settings / Fleet

This should remain stable unless there is a strong product reason to change it.

## Screen-Level Requirements

### Notes

- prominent vault title
- obvious add-note action
- clear list of notes
- summary body preview
- visible recency label
- visible pending-sync badge

### Note Detail

- readable typography
- edit action
- delete action
- sync/conflict awareness
- tags and update time visible

### Note Editor

- minimal friction
- large title field
- comfortable body editing area
- tags field
- save action always obvious

### Settings / Fleet

- local peer identity visible
- add-peer flow visible
- paired peers visible
- status metrics visible
- advanced URL setting available

### Graph

- should feel exploratory, not operational
- relationship language should be understandable
- empty state must explain absence of links cleanly

## Responsiveness Requirements

### Mobile

- bottom navigation preferred
- touch targets must be generous
- editing must be keyboard-safe
- dense diagnostic text should be limited

### Desktop / Web

- navigation rail preferred
- more information density acceptable
- long IDs and metadata can be shown more comfortably
- dialogs and side-by-side sections are acceptable

## Tone Requirements

Language in the UI should be:

- plain
- operational
- non-marketing
- trustworthy

Preferred examples:

- "Pending sync"
- "Daemon offline"
- "Generate invite"
- "Pair device"

Avoid:

- vague cloud-language
- overpromising sync claims
- consumer-app fluff

## Reachability Messaging

The UI must remain honest where networking is not guaranteed.

Requirements:

- do not imply that invite QR automatically means internet sync works everywhere
- distinguish operational status from ideal product ambition
- make relay or reachability limitations explicit where needed

## Future UX Requirements

- native QR scanner
- first-run onboarding
- richer conflict UX
- more explicit sync diagnostics
- file/PDF workflows integrated into the same design system
