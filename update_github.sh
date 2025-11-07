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
git add -A "$POOL_DIR" "$DISTS_DIR" "$APPSTREAM_DIR" update_appstream.sh || true

if git diff --cached --quiet; then
    echo "ℹ️  No changes to commit."
else
    git commit -m "🔄 Update APT repo and AppStream metadata"
    git push origin main
    echo "✅ Repository updated on GitHub."
fi

echo "✨ Done!"

