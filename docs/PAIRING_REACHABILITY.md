# Pairing Reachability Status

This document states the current honest status of Relix pairing reachability.

## Current Product Position

- Pairing UI exists on web and mobile.
- Relix can generate and consume invite codes through ACORDE.
- Local daemon health, peer identity, and peer inspection are integrated into the UI.
- Cross-network pairing is not yet verified end to end in this repository.

Until relay support or internet reachability is confirmed in ACORDE, Relix should present pairing as:

- reliable on the same local network
- unverified across the internet

That is why the current UI labels pairing as local-network-first and avoids claiming internet sync is proven.

## What Is Verified

- Relix can call:
  - `GET /identity`
  - `GET /peers`
  - `POST /invite`
  - `POST /pair`
- Relix can render invite QR codes.
- Mobile and web can both submit invite codes.
- Desktop cluster and local-node scripts in the repository demonstrate local peer connectivity.

## What Is Not Yet Verified

- Whether ACORDE invite payloads include public internet-reachable addresses
- Whether ACORDE supports relay fallback in the currently used runtime
- Whether NAT traversal works reliably outside a shared LAN
- Whether invite acceptance succeeds when both devices are on different consumer networks

## Required Validation

To move Relix from "local network only" to "internet-capable", verify all of the following:

1. Pair two devices on different residential networks.
2. Confirm whether the session is direct or relay-backed.
3. Confirm invite acceptance without manual port forwarding.
4. Confirm sync after one device edits offline and reconnects.
5. Capture the observed limitations in docs.

## Until Then

Relix should continue to:

- show a local-network-only or relay-unverified badge in pairing UI
- avoid promising internet reachability in product copy
- document the limitation explicitly
