# Relix Product Vision

## One-Line Summary

Relix is a local-first, privacy-first knowledge system built on ACORDE, designed to let a user keep notes, links, files, and relationships synced across personal devices without relying on a central cloud service.

## Core Idea

Relix is not meant to be "another notes app with sync bolted on."

The central idea is:

- your data lives primarily on your devices
- ACORDE provides the persistence and synchronization substrate
- Relix provides the human-facing product experience
- pairing should feel device-to-device, not account-to-server

This means the user mental model should shift away from:

- "log into my account"
- "point the app at a server URL"

and toward:

- "this device is part of my fleet"
- "pair a new device"
- "work locally, sync when reachable"

## Product Principles

### 1. Local-First

The app must remain useful when the daemon is unavailable or the network is unstable.

Implications:

- cached notes must still render
- note creation and edits must survive temporary disconnects
- destructive operations should be queued, not lost
- the UI must clearly indicate when work is pending sync

### 2. Privacy-First

Relix should not require a hosted SaaS account to function.

Implications:

- peer-to-peer and direct-device models are preferred
- any relay or rendezvous support must be treated as infrastructure, not identity
- metadata exposure should be explicitly documented
- users should be able to understand where trust boundaries exist

### 3. Identity-Driven Sync

The important unit is the peer, not the IP address.

Implications:

- pairing flows should center on invite codes and QR
- users should see their device identity and fleet state
- manual base URL entry should be treated as operational override, not the primary happy path

### 4. Multi-Platform by Design

Relix should feel like one product across:

- mobile
- desktop
- web

Implications:

- the design language should remain consistent across targets
- behavior should be familiar even when layout changes
- feature parity matters more than platform-specific novelty

### 5. Understandable Sync

Sync should never feel mysterious.

Implications:

- online vs offline state must be visible
- pending changes must be visible
- paired peers must be visible
- reachability limitations must be documented honestly

## Target User Experience

A complete successful user journey should look like this:

1. User starts ACORDE locally.
2. User launches Relix on desktop, web, or mobile.
3. Relix shows current vault state and connection status.
4. User pairs another device using invite code or QR.
5. Notes appear on the second device without any manual export/import workflow.
6. User edits notes offline if needed.
7. Changes synchronize later when the daemon and peer path are reachable.

## Scope of the Current Branch

The current Flutter branch is focused on:

- note browsing
- note creation and editing
- local caching
- queued offline mutations
- pairing UI
- peer management UI
- connection state visibility
- graph/relationship visualization

It is not yet the finished product. Missing or still-maturing areas include:

- native QR scanning in Flutter
- richer markdown editing
- verified internet-wide relay support
- full file/PDF workflows
- production-ready conflict resolution UX

## Non-Goals

Relix is not currently trying to be:

- a collaborative SaaS workspace
- a social publishing platform
- an always-online cloud editor
- a generic sync server product

The product should stay disciplined around personal knowledge, personal fleet sync, and local ownership.
