#!/bin/bash
set -e

# === Perfume Composer Windows uploader ===
# Syncs PerfumeComposerSetup.exe → GitHub Pages under /windows

REPO_PATH="$(pwd)"
WINDOWS_DIR="$REPO_PATH/windows"
INSTALLER_NAME="PerfumeComposerSetup.exe"
PUBLIC_BASE="https://perfume-composer.github.io/perfume-composer-apt/windows"

if [ -f "$HOME/.github_token" ]; then
    GITHUB_TOKEN=$(<"$HOME/.github_token")
    echo "🔑 Loaded GitHub token from ~/.github_token (length: ${#GITHUB_TOKEN} chars)"
else
    echo "⚠️ No GitHub token file found (~/.github_token)."
fi

echo "💻 Preparing Windows upload..."

VERSION_FILE=$(find pool/main/p/perfume-composer/ -type f -name 'PerfumeComposer_*.deb' | sort | tail -n 1)
if [ -z "$VERSION_FILE" ]; then
    echo "❌ Could not detect version (.deb missing in pool/)"
    exit 1
fi
VERSION=$(basename "$VERSION_FILE" | sed 's/PerfumeComposer_\(.*\)\.deb/\1/')
echo "🧩 Detected version: $VERSION"

INSTALLER_PATH="$WINDOWS_DIR/$INSTALLER_NAME"
if [ ! -f "$INSTALLER_PATH" ]; then
    echo "❌ Error: $INSTALLER_PATH not found!"
    exit 1
fi

INSTALLER_VERSIONED="$WINDOWS_DIR/PerfumeComposerSetup_${VERSION}.exe"

echo "📦 Copying and renaming $INSTALLER_PATH → $INSTALLER_VERSIONED..."
cp -f "$INSTALLER_PATH" "$INSTALLER_VERSIONED"

find "$WINDOWS_DIR" -type f -name "PerfumeComposerSetup_*.exe" ! -name "$(basename "$INSTALLER_VERSIONED")" -delete

git lfs prune || true
git gc || true

echo "🪄 Committing and pushing new Windows installer..."
git add "$INSTALLER_VERSIONED" || true
git commit -m "Update Windows installer for version ${VERSION}" || echo "🟡 Nothing new to commit."
git push origin main || echo "⚠️ Push skipped or already up-to-date."

PUBLIC_URL="$PUBLIC_BASE/PerfumeComposerSetup_${VERSION}.exe"
echo "🌐 Download link:"
echo "   $PUBLIC_URL"

