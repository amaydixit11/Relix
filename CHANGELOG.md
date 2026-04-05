# Changelog

## Unreleased

### Added

- Flutter frontend as the primary active client under [`frontend/`](/home/amaydixit11/Desktop/dev/Relix/frontend)
- QR invite scanning in the Flutter settings screen
- File entry upload, listing, and share/download flow in Flutter
- Capability-aware ACORDE client behavior with local search fallback
- Additional product and developer documentation

### Changed

- `start-all.sh` now launches the Flutter frontend
- Flutter conflict checks now use a per-note baseline timestamp
- Flutter note detail adds in-note search highlighting

### Known Limits

- Cross-network relay-backed pairing is still unverified
- ACORDE transport capability auditing depends on the external ACORDE repo/runtime
