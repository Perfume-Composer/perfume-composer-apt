#!/bin/bash
set -e

# ==============================
# Perfume Composer AppStream sync (auto git recovery)
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

# --- Step 1: Extract only AppStream file ---
if [ ! -f "$DEB_PATH" ]; then
    echo "❌ Error: $DEB_PATH not found."
    exit 1
fi

rm -rf "$TMP_DIR"
dpkg-deb -x "$DEB_PATH" "$TMP_DIR"

# --- Step 2: Copy AppStream XML into repo folder ---
mkdir -p "$APPSTREAM_DIR"
cp "$TMP_DIR/usr/share/metainfo/org.perfumecomposer.app.metainfo.xml" "$XML_PATH"

# --- Step 3: Compress for publishing ---
gzip -f "$XML_PATH"

# --- Step 4: Clean up temp directory ---
rm -rf "$TMP_DIR"

# --- Step 5: Validate XML ---
if command -v appstreamcli >/dev/null 2>&1; then
    echo "🧪 Validating AppStream XML..."
    appstreamcli validate "$XML_GZ" || {
        echo "⚠️  Validation failed — check output above."
        exit 1
    }
    echo "✅ Validation successful."
else
    echo "⚠️  appstreamcli not found; skipping validation."
fi

# --- Step 6: Generate AppStream component index safely ---
echo "🧩 Generating AppStream component index..."

if [ ! -f "${APPSTREAM_DIR}/perfume-composer.xml" ]; then
    gunzip -c "$XML_GZ" > "${APPSTREAM_DIR}/perfume-composer.xml"
fi

TMP_COMPOSE=$(mktemp -d)
mkdir -p "$TMP_COMPOSE/usr/share/metainfo"
cp "${APPSTREAM_DIR}/perfume-composer.xml" "$TMP_COMPOSE/usr/share/metainfo/"

appstreamcli compose --data-dir "$APPSTREAM_DIR" "$TMP_COMPOSE" || {
    echo "⚠️  appstreamcli compose failed."
    rm -rf "$TMP_COMPOSE"
    exit 1
}

rm -rf "$TMP_COMPOSE"

echo "🧹 Cleaning up temporary AppStream folders..."
find "$APPSTREAM_DIR" -type d \( -path "$APPSTREAM_DIR/appstream" -o -path "$APPSTREAM_DIR/usr" \) -exec rm -rf {} + 2>/dev/null || true
find "$APPSTREAM_DIR" -type f -name "example.xml.gz" -delete 2>/dev/null || true
echo "✅ Clean AppStream folder ready for push."

# --- Step 7: Commit and push with retry logic ---
echo "🪄 Preparing Git commit..."
git add -A "$APPSTREAM_DIR" "$DEB_PATH" "$XML_GZ" update_appstream.sh || true
git clean -fdx "$APPSTREAM_DIR"/usr "$APPSTREAM_DIR"/appstream 2>/dev/null || true

if git diff --cached --quiet; then
    echo "⚠️  No new changes to commit. Everything already up to date."
else
    echo "🪄 Committing and pushing..."
    git commit -m "Add PerfumeComposer ${VERSION} with updated AppStream metadata and index" || true

    echo "🚀 Pushing to remote..."
    if ! git push origin main 2>push_error.log; then
        if grep -q "fetch first" push_error.log; then
            echo "⚠️  Push rejected — repository not up to date. Pulling latest changes..."
            git pull --rebase origin main
            echo "🔁 Retrying push..."
            git push origin main || {
                echo "❌ Push failed again — please resolve conflicts manually."
                exit 1
            }
        else
            echo "❌ Push failed — unknown error:"
            cat push_error.log
            exit 1
        fi
    fi
fi

echo "🎉 Done! AppStream, index, and .deb synced for version $VERSION."
echo "🌐 Published at:"
echo "   https://perfume-composer.github.io/perfume-composer-apt/appstream/perfume-composer.xml.gz"
echo "   https://perfume-composer.github.io/perfume-composer-apt/appstream/Components-amd64.yml.gz"
echo "🧭 Run 'sudo apt update && sudo appstreamcli refresh-cache --force' to refresh Mint Software Manager."

