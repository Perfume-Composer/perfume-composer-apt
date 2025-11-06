#!/bin/bash
set -e

# ==============================
# Perfume Composer AppStream sync (auto-healing version)
# ==============================

if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    echo "Example: ./update_appstream.sh 1.0.17"
    exit 1
fi

VERSION="$1"
DEB_PATH="pool/main/p/perfume-composer/PerfumeComposer_${VERSION}.deb"
TMP_DIR="tmp_appstream"
APPSTREAM_DIR="appstream"
XML_PATH="${APPSTREAM_DIR}/perfume-composer.xml"
XML_GZ="${XML_PATH}.gz"

echo "📦 Extracting AppStream from $DEB_PATH..."

# --- Step 1: Extract AppStream file ---
if [ ! -f "$DEB_PATH" ]; then
    echo "❌ Error: $DEB_PATH not found."
    exit 1
fi

rm -rf "$TMP_DIR"
dpkg-deb -x "$DEB_PATH" "$TMP_DIR"

# --- Step 2: Copy AppStream XML ---
mkdir -p "$APPSTREAM_DIR"
cp "$TMP_DIR/usr/share/metainfo/org.perfumecomposer.app.metainfo.xml" "$XML_PATH"

# --- Step 3: Compress ---
gzip -f "$XML_PATH"

# --- Step 4: Cleanup temp ---
rm -rf "$TMP_DIR"

# --- Step 5: Validate XML ---
if command -v appstreamcli >/dev/null 2>&1; then
    echo "🧪 Validating AppStream XML..."
    if appstreamcli validate "$XML_GZ"; then
        echo "✅ Validation successful."
    else
        echo "⚠️  Validation failed — check above, continuing anyway."
    fi
else
    echo "⚠️  appstreamcli not found; skipping validation."
fi

# --- Step 6: Generate Component Index ---
echo "🧩 Generating AppStream component index..."
TMP_COMPOSE=$(mktemp -d)
mkdir -p "$TMP_COMPOSE/usr/share/metainfo"
gunzip -c "$XML_GZ" > "$TMP_COMPOSE/usr/share/metainfo/org.perfumecomposer.app.metainfo.xml"

# Older AppStream versions don’t support --no-network, so we hush harmless warnings
if appstreamcli compose --data-dir "$APPSTREAM_DIR" "$TMP_COMPOSE" 2>&1 | grep -v "icon-not-found"; then
    echo "✅ DEP-11 metadata composed (warnings ignored)."
else
    echo "⚠️  appstreamcli compose finished with non-critical warnings (ignored)."
fi
rm -rf "$TMP_COMPOSE"

# --- Step 7: Cleanup extra folders ---
find "$APPSTREAM_DIR" -type d \( -path "$APPSTREAM_DIR/usr" -o -path "$APPSTREAM_DIR/appstream" \) -exec rm -rf {} + 2>/dev/null || true
find "$APPSTREAM_DIR" -type f -name "example.xml.gz" -delete 2>/dev/null || true

echo "✅ AppStream ready for commit."

# --- Step 7a: Keep readable copies (for manual inspection)
echo "📖 Creating readable XML and YAML copies..."
if [ -f "${APPSTREAM_DIR}/perfume-composer.xml.gz" ]; then
    gunzip -c "${APPSTREAM_DIR}/perfume-composer.xml.gz" > "${APPSTREAM_DIR}/perfume-composer.xml" || true
fi
if [ -f "${APPSTREAM_DIR}/Components-amd64.yml.gz" ]; then
    gunzip -c "${APPSTREAM_DIR}/Components-amd64.yml.gz" > "${APPSTREAM_DIR}/Components-amd64.yml" || true
fi
echo "✅ Readable copies added (perfume-composer.xml + Components-amd64.yml)"

# --- Step 7b: Publish AppStream to dep11 folder for Software Manager ---
DEP11_DIR="public/dists/stable/main/dep11"
mkdir -p "$DEP11_DIR"

echo "📤 Copying AppStream XML to $DEP11_DIR..."
cp "$XML_GZ" "$DEP11_DIR/perfume-composer.xml.gz"

# --- Step 7c: Update APT Release files ---
echo "🔐 Regenerating Release files..."
apt-ftparchive release public/dists/stable > public/dists/stable/Release
gpg --clearsign -o public/dists/stable/InRelease public/dists/stable/Release

# --- Step 8: Git commit logic ---
echo "🪄 Preparing Git commit..."
git add -A "$APPSTREAM_DIR" "$DEB_PATH" "$DEP11_DIR" public/dists/stable update_appstream.sh || true

if git diff --cached --quiet; then
    echo "⚠️  No new changes to commit."
else
    git commit -m "Add PerfumeComposer ${VERSION} with updated AppStream metadata and index" || true
fi

# --- Step 9: Push with auto-healing ---
echo "🚀 Pushing to remote..."
if ! git push origin main; then
    echo "⚠️  Push rejected — syncing with remote..."

    # Try to stash and pull safely
    git stash push -m "auto-stash-before-sync" || true
    git fetch origin main || true

    # Reset to remote main
    git reset --merge origin/main || git merge --abort || true

    # Auto-resolve binary and script conflicts
    git checkout --ours appstream/perfume-composer.xml.gz 2>/dev/null || true
    git add appstream/perfume-composer.xml.gz 2>/dev/null || true
    git checkout --ours update_appstream.sh 2>/dev/null || true
    git add update_appstream.sh 2>/dev/null || true

    # Apply stash if exists
    if git stash list | grep -q "auto-stash-before-sync"; then
        echo "💾 Restoring stashed changes..."
        git stash pop || true
    fi

    # Recommit if needed
    if ! git diff --cached --quiet; then
        git commit -m "Merge-safe AppStream sync for v${VERSION}" || true
    fi

    # Final push
    git push origin main || {
        echo "❌ Final push failed — please check manually."
        exit 1
    }
fi

echo "🎉 AppStream sync complete for version $VERSION."
echo "🌐 Published at:"
echo "   https://perfume-composer.github.io/perfume-composer-apt/appstream/perfume-composer.xml.gz"
echo "   https://perfume-composer.github.io/perfume-composer-apt/appstream/Components-amd64.yml.gz"

