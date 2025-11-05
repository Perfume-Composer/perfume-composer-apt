#!/bin/bash
set -e

# ==============================
# Perfume Composer AppStream sync
# ==============================

if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    echo "Example: ./update_appstream.sh 1.0.10"
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

# --- Step 2: Copy to appstream folder ---
mkdir -p "$APPSTREAM_DIR"
cp "$TMP_DIR/usr/share/metainfo/org.perfumecomposer.app.metainfo.xml" "$XML_PATH"

# --- Step 3: Compress it ---
gzip -f "$XML_PATH"

# --- Step 4: Clean up ---
rm -rf "$TMP_DIR"

# --- Step 5: Validate ---
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

# --- Step 6: Commit and push ---
echo "🪄 Adding and committing new AppStream + .deb..."
git add "$DEB_PATH" "$XML_GZ"
git commit -m "Add PerfumeComposer ${VERSION} with updated AppStream metadata"
git push origin main

echo "🎉 Done! AppStream and .deb synced for version $VERSION."

