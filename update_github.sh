#!/bin/bash
set -e

echo "🚀 Updating GitHub APT repository..."

APPSTREAM_DIR="appstream"
POOL_DIR="pool/main/p/perfume-composer"
DISTS_DIR="dists"

# Validate existence
if [ ! -d "$POOL_DIR" ]; then
    echo "❌ Missing pool directory: $POOL_DIR"
    exit 1
fi

if [ ! -d "$APPSTREAM_DIR" ]; then
    echo "❌ Missing appstream directory: $APPSTREAM_DIR"
    exit 1
fi

echo "🔍 Validating AppStream XML..."
appstreamcli validate "$APPSTREAM_DIR/perfume-composer.xml.gz" || true

echo "📦 Staging repository changes..."
git add -A "$POOL_DIR" "$DISTS_DIR" "$APPSTREAM_DIR" docs update_appstream.sh update_github.sh update_windows.sh windows || true

echo
echo "🧪 Debug: current branch:"
git branch --show-current || true

echo
echo "🧪 Debug: working tree changes (unstaged + staged):"
git status --porcelain || true

echo
echo "🧪 Debug: staged changes only:"
git diff --cached --name-status || true

if git diff --cached --quiet; then
    echo
    echo "ℹ️  No staged changes to commit."
    echo "👉 Either nothing changed in: $POOL_DIR, $DISTS_DIR, $APPSTREAM_DIR, docs, update_appstream.sh"
    echo "👉 Or your changes are outside those paths."
    echo "👉 Or the APT/AppStream regeneration step didn't run, so outputs didn't change."
else
    git commit -m "🔄 Update APT repo and AppStream metadata"
    git push origin main
    echo "✅ Repository updated on GitHub."
fi

echo "✨ Done!"

echo
read -rp "✅ Script finished. Press Enter to close..."
