# Relix

**Privacy-first personal knowledge management built on ACORDE.**

> Your second brain. Without the cloud.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Status](https://img.shields.io/badge/status-alpha-orange.svg)

## ✨ Features

- 📝 **Markdown Notes** — Write in markdown with live preview
- 🔗 **Backlinks** — `[[Wikilink]]` syntax with bidirectional linking
- 📊 **Graph View** — Visualize your knowledge connections
- 📄 **PDF Storage** — Store and annotate documents
- 🔍 **Full-text Search** — Find anything instantly
- 🏷️ **Tags** — Hierarchical `#topic/subtopic` organization
- 🔐 **Encrypted** — End-to-end encryption with ACORDE
- 🔄 **P2P Sync** — Sync across devices without cloud servers

## 🏗️ Architecture

```
apps/
├── frontend/      # Flutter app for web, desktop, and mobile
├── web/           # Legacy Next.js client
├── desktop/       # Legacy Electron shell
└── mobile/        # Legacy Expo app

packages/
├── core/          # Legacy TypeScript client package
└── plugins/       # Legacy TypeScript plugin package
```

## 🚀 Getting Started

### Prerequisites

1. **ACORDE daemon** running on localhost:7331
   ```bash
   acorde daemon --api-port 7331
   ```

2. **Flutter 3.41+**
3. **Node.js 18+** for legacy tooling still present in the repo

### Acorde Dependency

Relix requires a local ACORDE daemon.

```bash
acorde daemon --api-port 7331
```

Relix talks to `http://localhost:7331` by default.

### Flutter Setup

```bash
# Start ACORDE + Flutter web
./start-all.sh
```

Or run Flutter directly:

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

For desktop targets, replace `chrome` with `linux`, `windows`, or `macos`.
For mobile targets, use a connected emulator/device or `flutter run -d android` / `flutter run -d ios`.

## 📦 Tech Stack

| Layer | Technology |
|-------|------------|
| App | Flutter |
| Web | Flutter Web |
| Desktop | Flutter Desktop |
| Mobile | Flutter Mobile |
| Backend | ACORDE |
| Legacy Workspace | Turborepo |

## 📚 Documentation

- [Documentation Index](./docs/DOCUMENTATION_INDEX.md)
- [Product Vision](./docs/PRODUCT_VISION.md)
- [Features And Requirements](./docs/FEATURES_AND_REQUIREMENTS.md)
- [Flutter Frontend Architecture](./docs/FLUTTER_FRONTEND_ARCHITECTURE.md)
- [Sync And Pairing Model](./docs/SYNC_AND_PAIRING_MODEL.md)
- [UI / UX Requirements](./docs/UI_UX_REQUIREMENTS.md)
- [Screen Specification](./docs/SCREEN_SPECIFICATION.md)

## 🗺️ Roadmap

- [x] Core package (ACORDE client + services)
- [x] Flutter notes CRUD client
- [x] Flutter settings / pairing UI
- [x] Flutter offline cache + mutation queue
- [ ] Markdown editor (CodeMirror)
- [ ] Graph visualization (D3)
- [ ] PDF viewer
- [ ] Native QR scanning in Flutter
- [ ] Verified relay-backed internet sync

## 📄 License

MIT
