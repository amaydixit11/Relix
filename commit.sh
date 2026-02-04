#!/bin/bash

# Function to safe commit
safe_commit() {
  local msg="$1"
  shift
  # Only commit if there are staged changes
  if git diff --cached --quiet; then
    echo "Nothing to commit for: $msg"
  else
    git commit -m "$msg"
    echo "✓ Committed: $msg"
  fi
}

# Core
git add packages/core/src/models || true
safe_commit "feat(core): data models and types"

git add packages/core/src/services || true
safe_commit "feat(core): note and file services"

git add packages/core/src/utils || true
safe_commit "feat(core): shared utilities"

git add packages/core/src/hooks || true
safe_commit "feat(core): react hooks"

git add packages/core/src/templates || true
safe_commit "feat(core): note templates"

git add packages/core/src/index.ts packages/core/src/benchmark.ts || true
safe_commit "feat(core): barrel exports and benchmark script"

# Plugins
git add packages/plugins || true
safe_commit "feat(plugins): plugin system scaffold"

# Apps - Mobile
git add apps/mobile || true
safe_commit "feat(mobile): initial mobile app setup"

# Apps - Desktop
git add apps/desktop || true
safe_commit "feat(desktop): initial electron setup"

# Apps - Web
git add apps/web/package.json apps/web/tsconfig.json || true
safe_commit "feat(web): web app scaffold"

git add apps/web/src/styles apps/web/src/app/globals.css || true
safe_commit "feat(web): global styles and theme"

git add apps/web/src/components/Editor || true
safe_commit "feat(web): markdown editor component"

git add apps/web/src/components/Conflict || true
safe_commit "feat(web): conflict resolution UI"

git add apps/web/src/components/CommandPalette || true
safe_commit "feat(web): command palette"

git add apps/web/src/components/QuickCapture || true
safe_commit "feat(web): quick capture widget"

git add apps/web/src/components/Sidebar || true
safe_commit "feat(web): sidebar navigation"

git add apps/web/src/components/Layout || true
safe_commit "feat(web): layout components"

git add apps/web/src/components/index.ts || true
safe_commit "feat(web): component exports"

git add apps/web/src/hooks || true
safe_commit "feat(web): web hooks"

git add apps/web/src/app/providers.tsx || true
safe_commit "feat(web): app providers"

git add apps/web/src/app/layout.tsx || true
safe_commit "feat(web): root layout"

git add apps/web/src/app/page.tsx || true
safe_commit "feat(web): home page dashboard"

git add apps/web/src/app/notes || true
safe_commit "feat(web): notes pages (list, detail, new)"

git add apps/web/src/app/graph || true
safe_commit "feat(web): graph visualization page"

git add apps/web/src/app/files || true
safe_commit "feat(web): files management page"

git add apps/web/src/app/settings || true
safe_commit "feat(web): settings page"

# Remaining Configs
git add . || true
safe_commit "chore: remaining configs and cleanup"
