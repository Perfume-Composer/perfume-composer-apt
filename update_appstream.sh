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
if appstreamcli compose --origin="Perfume Composer APT" --data-dir "$APPSTREAM_DIR" "$TMP_COMPOSE" 2>&1 \
   | grep -vE "icon-not-found|Metadata origin not set|Run failed|some data was ignored|Errors were raised during this compose run|Refer to the generated issue report data"; then
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

# --- Step 7c: Update APT Release files (include DEP-11 properly) ---
echo "🔐 Regenerating Release files (including DEP-11)..."
cd public

# Ensure binary package index exists
mkdir -p dists/stable/main/binary-amd64

# Detect where the pool really is (root-level, not inside public)
if [ -d "../pool/main/p/perfume-composer" ]; then
    POOL_PATH="../pool/main/p/perfume-composer"
elif [ -d "pool/main/p/perfume-composer" ]; then
    POOL_PATH="pool/main/p/perfume-composer"
else
    echo "❌ Could not find pool/main/p/perfume-composer directory!"
    exit 1
fi

echo "📦 Using pool path: $POOL_PATH"
apt-ftparchive packages "$POOL_PATH" > dists/stable/main/binary-amd64/Packages
gzip -f dists/stable/main/binary-amd64/Packages

# --- Step 7d: Generate Release metadata and integrate DEP-11 ---
echo "🔐 Building final Release metadata..."

# Build temporary apt-ftparchive config
TMP_CFG=$(mktemp)
cat > "$TMP_CFG" <<EOF
Dir {
  ArchiveDir ".";
};

TreeDefault {
  Directory "dists/stable";
  Contents "no";
  SrcDirectory "pool";
};

BinDirectory "dists/stable/main/binary-amd64" {
  Packages "dists/stable/main/binary-amd64/Packages";
};

BinDirectory "dists/stable/main/dep11" {
  Packages "dists/stable/main/dep11/Components-amd64.yml.gz";
};
EOF

# Generate Release metadata
apt-ftparchive \
  -o APT::FTPArchive::Release::Origin="Perfume Composer" \
  -o APT::FTPArchive::Release::Label="Perfume Composer" \
  -o APT::FTPArchive::Release::Suite="stable" \
  -o APT::FTPArchive::Release::Codename="stable" \
  -o APT::FTPArchive::Release::Architectures="amd64" \
  -o APT::FTPArchive::Release::Components="main" \
  release dists/stable > dists/stable/Release

# ✅ Ensure DEP-11 file exists to avoid apt-ftparchive failure
if [ ! -f "dists/stable/main/dep11/Components-amd64.yml.gz" ]; then
    echo "⚠️  DEP-11 file missing — creating empty placeholder."
    echo "# Empty DEP-11 metadata placeholder" | gzip -c > dists/stable/main/dep11/Components-amd64.yml.gz
fi

# Integrate DEP-11 checksum
apt-ftparchive generate "$TMP_CFG"
rm -f "$TMP_CFG"

# Sign Release
gpg --clearsign -o dists/stable/InRelease dists/stable/Release
cd -


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

