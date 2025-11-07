#!/bin/bash
set -e

echo "🪶 Perfume Composer — AppStream/DEP-11 Updater"
echo "============================================="

APPSTREAM_DIR="appstream"
POOL_DIR="pool/main/p/perfume-composer"

# --- Step 1: Find latest .deb file ---
LATEST_DEB=$(ls -t $POOL_DIR/PerfumeComposer_*.deb 2>/dev/null | head -n 1)
if [ -z "$LATEST_DEB" ]; then
    echo "❌ No .deb file found in $POOL_DIR"
    exit 1
fi

echo "📦 Found package: $LATEST_DEB"

# --- Step 2: Extract AppStream metadata from .deb ---
TMP_DIR="tmp_appstream"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

echo "📤 Extracting metadata..."
dpkg-deb -x "$LATEST_DEB" "$TMP_DIR"

XML_SRC="$TMP_DIR/usr/share/metainfo/org.perfumecomposer.app.metainfo.xml"
XML_DEST="$APPSTREAM_DIR/perfume-composer.xml"

if [ ! -f "$XML_SRC" ]; then
    echo "❌ AppStream XML not found in package!"
    exit 1
fi

# Copy and compress XML
mkdir -p "$APPSTREAM_DIR"
cp "$XML_SRC" "$XML_DEST"
gzip -f "$XML_DEST"

echo "✅ Extracted and compressed: $XML_DEST.gz"

# --- Step 3: Generate DEP-11 catalog ---
echo "🧩 Generating DEP-11 index..."

cd "$APPSTREAM_DIR"

mkdir -p usr/share/metainfo usr/share/icons/hicolor/128x128/apps
cp perfume-composer.xml.gz usr/share/metainfo/

ICON_PATH="../appstream/icons-128x128/perfume-composer.png"
if [ -f "$ICON_PATH" ]; then
    cp "$ICON_PATH" usr/share/icons/hicolor/128x128/apps/perfume-composer.png
else
    echo "⚠️ Local icon not found at $ICON_PATH"
fi

appstreamcli compose --origin=perfume-composer-apt .
rm -rf usr
cd ..

echo "✅ DEP-11 catalog rebuilt successfully."

# --- Step 4: Optional validation ---
echo "🔍 Validating XML..."
appstreamcli validate "$APPSTREAM_DIR/perfume-composer.xml.gz" || true

# --- Step 5: Display summary ---
echo
echo "🧾 Summary:"
echo "  - XML: $APPSTREAM_DIR/perfume-composer.xml.gz"
echo "  - DEP-11: $APPSTREAM_DIR/Components-amd64.yml.gz"
echo
echo "✨ AppStream data ready for git commit and push."

echo
read -rp "✅ Script finished. Press Enter to close..."


