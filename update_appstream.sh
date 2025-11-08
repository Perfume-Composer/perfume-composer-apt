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

# --- 🆕 Step 5: Add AppStream line to Release ---
echo "📜 Updating Release file with AppStream reference..."
RELEASE_FILE="dists/stable/Release"
if [ -f "$RELEASE_FILE" ]; then
    # Remove any existing old line to avoid duplicates
    sed -i '/^AppStream:/d' "$RELEASE_FILE"
    echo "AppStream: appstream/Components-amd64.yml.gz" >> "$RELEASE_FILE"
    echo "✅ Added AppStream reference to Release file."
else
    echo "⚠️ Release file not found at $RELEASE_FILE — skipping."
fi

# --- Step 6: Sign updated Release ---
if [ -f "$RELEASE_FILE" ]; then
    echo "🔏 Signing Release files..."
    gpg --clearsign -o dists/stable/InRelease dists/stable/Release
    gpg -abs -o dists/stable/Release.gpg dists/stable/Release
    echo "✅ Release files signed successfully."
fi

# --- 🆕 Step 8: Extract README and CHANGELOG to docs/ ---
echo "📚 Updating local docs folder..."
DOCS_SRC="$TMP_DIR/usr/share/doc/perfumecomposer"
DOCS_DIR="docs"
mkdir -p "$DOCS_DIR"

if [ -f "$DOCS_SRC/README" ]; then
    cp "$DOCS_SRC/README" "$DOCS_DIR/README.md"
    echo "✅ Updated README.md from package."
else
    echo "ℹ️ No README found in package."
fi

if [ -f "$DOCS_SRC/changelog.Debian.gz" ]; then
    gunzip -c "$DOCS_SRC/changelog.Debian.gz" > "$DOCS_DIR/CHANGELOG.md"
    echo "✅ Updated CHANGELOG.md from package."
else
    echo "ℹ️ No changelog found in package."
fi

# --- 🧹 Step 9: Remove temporary folder ---
rm -rf "$TMP_DIR"
echo "🧹 Temporary folder '$TMP_DIR' deleted."

# --- Step 10: Display summary ---
echo
echo "🧾 Summary:"
echo "  - XML: $APPSTREAM_DIR/perfume-composer.xml.gz"
echo "  - DEP-11: $APPSTREAM_DIR/Components-amd64.yml.gz"
echo "  - AppStream line added to: dists/stable/Release"
echo "  - Docs updated in: $DOCS_DIR"
echo
echo "✨ AppStream data ready for git commit and push."
echo
read -rp "✅ Script finished. Press Enter to close..."

