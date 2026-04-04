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
├── web/       # Next.js 14 (primary)
├── desktop/   # Electron (coming soon)
└── mobile/    # Expo (coming soon)

packages/
├── core/      # ACORDE client + services
├── ui/        # Shared components
└── storage/   # Local preferences
```

## 🚀 Getting Started

### Prerequisites

1. **ACORDE daemon** running on localhost:7331
   ```bash
   acorde daemon --api-port 7331
   ```

2. **Node.js 18+**

### Acorde Dependency

Relix requires a local ACORDE daemon.

```bash
acorde daemon --api-port 7331
```

Relix talks to `http://localhost:7331` by default.

### Setup

```bash
# Install dependencies
npm install

# Start development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

## 📦 Tech Stack

| Layer | Technology |
|-------|------------|
| Web | Next.js 14 |
| Desktop | Electron |
| Mobile | Expo |
| State | React Query |
| Backend | ACORDE |
| Monorepo | Turborepo |

## 🗺️ Roadmap

- [x] Core package (ACORDE client + services)
- [x] Web app (notes CRUD)
- [ ] Markdown editor (CodeMirror)
- [ ] Graph visualization (D3)
- [ ] PDF viewer
- [ ] Desktop app (Electron)
- [ ] Mobile app (Expo)

## 📄 License

MIT
