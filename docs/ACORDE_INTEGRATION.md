# ACORDE Integration

## Runtime Contract

Relix depends on a local ACORDE daemon.

Default startup command:

```bash
acorde daemon --api-port 7331
```

Default API base URL:

```txt
http://localhost:7331
```

Canonical Relix config variable:

```txt
ACORDE_BASE_URL=http://localhost:7331
```

Notes:

- `daemon` is the supported runtime command.
- `serve` should not be referenced by Relix docs or scripts.
- Relix should treat ACORDE as local-first infrastructure and assume the daemon is available on the same machine during development.

## REST Contract Guaranteed Today

The ACORDE REST API currently guarantees these routes:

- `GET /entries`
- `POST /entries`
- `GET /entries/:id`
- `PUT /entries/:id`
- `DELETE /entries/:id`
- `POST /entries/:id/authorize`
- `GET /identity`
- `GET /peers`
- `POST /invite`
- `POST /pair`
- `GET /status`
- `GET /events`
- `GET /search`
- `POST /blobs`
- `GET /blobs/:cid`

These peer, search, and storage routes are part of the current Relix runtime contract. The shipped client and UI already depend on them.

Relix must not assume additional REST routes unless ACORDE explicitly adds them to this contract.

### Peer and Pairing Route Notes

`GET /identity`

- returns the local daemon peer identity
- current Relix model expects:
  - `peer_id`
  - `addrs`
  - optional `name`

`GET /peers`

- returns currently known or connected peers
- current Relix model expects each peer to include:
  - `id`
  - `addrs`
  - optional `protocol`
  - optional `name`
  - optional `last_seen`
  - optional `connection_type`

`POST /invite`

- generates a shareable invite code for pairing another device
- current Relix client expects a JSON response containing:
  - `code`

`POST /pair`

- accepts an invite code and initiates device pairing
- current Relix client sends:
  - `code`

These routes are required for the current web and mobile pairing UX. If ACORDE changes their request or response shapes, Relix must be updated in lockstep.

`GET /search`

- performs a full-text search across entries
- parameters:
  - `q`: search query string
  - `type`: (optional) filter by entry type
- returns a list of matching entries

`POST /blobs`

- uploads a raw blob and returns its Content Identifier (CID)
- body: raw binary data
- returns: `{"cid": "..."}`

`GET /blobs/:cid`

- retrieves a raw blob by its CID
- returns: raw binary data

## Entry Model Contract

Current entry shape:

- `id`
- `type`
- `content`
- `tags`
- `created_at`
- `updated_at`
- `deleted`
- `owner`

Supported entry types:

- `note`
- `log`
- `file`
- `event`

Important wire detail:

- `content` is stored as `[]byte`
- JSON responses expose `content` as base64
- Relix must decode base64 before parsing structured content

Delete semantics:

- deletes are tombstones, not hard deletes

Privacy and sharing semantics:

- entries are private by default
- owner may grant writer access with `POST /entries/:id/authorize`
- writers can read and write

## Product Assumptions

Relix assumes the following ACORDE behavior:

- local-first
- offline-first
- peer sync is eventual
- sync is CRDT-based
- private by default unless explicitly shared
- peer identity and pairing are daemon-level concerns exposed over REST

## Known REST Gaps

These capabilities are not part of the current ACORDE REST contract:

- version history endpoints
- ACL inspection endpoints
- ACL revoke or public visibility endpoints

Specifically, Relix should not depend on:

- `GET /entries/:id/versions`
- `GET /entries/:id/versions/:versionId`
- `GET /entries/:id/acl`
- `POST /entries/:id/acl`
- `DELETE /entries/:id/acl/:peerId`
- `PUT /entries/:id/acl/public`

If ACORDE supports any of these internally or via library APIs, Relix should still treat them as unavailable until they are part of the published REST contract.

## Current Relix Usage

The current Relix codebase already consumes the following ACORDE features:

- note CRUD through `/entries`
- writer authorization through `/entries/:id/authorize`
- daemon and sync health through `/status`
- event subscription through `/events`
- local peer identity through `/identity`
- peer inspection through `/peers`
- invite generation through `/invite`
- device pairing through `/pair`

If ACORDE removes or changes any of those routes, it is a breaking change for Relix.

## Relix Mapping

- Relix note = ACORDE `note` entry
- Relix file or document = ACORDE `file` entry
- backlinks = Relix tag conventions on top of ACORDE entries
- tags and indexes = Relix-side conventions, not ACORDE-native schema
- tombstones = deleted ACORDE entries retained for sync consistency
