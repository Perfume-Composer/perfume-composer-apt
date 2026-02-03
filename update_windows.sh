#!/bin/bash
set -e

# === Perfume Composer Windows uploader ===
# Syncs PerfumeComposerSetup.exe → GitHub Pages under /windows
# Detects version from latest .deb, cleans old installers, commits, and pushes

REPO_PATH="$(pwd)"
WINDOWS_DIR="$REPO_PATH/windows"
INSTALLER_NAME="PerfumeComposerSetup.exe"
PUBLIC_BASE="https://perfume-composer.github.io/perfume-composer-apt/windows"

echo "💻 Preparing Windows upload..."

# --- Load GitHub token (optional) ---
if [ -f "$HOME/.github_token" ]; then
    GITHUB_TOKEN=$(<"$HOME/.github_token")
    echo "🔑 Loaded GitHub token from ~/.github_token (length: ${#GITHUB_TOKEN} chars)"
else
    echo "⚠️  No GitHub token file found (~/.github_token). Continuing without it..."
fi

# --- Detect latest version from .deb ---
VERSION_FILE=$(find pool/main/p/perfume-composer/ -type f -name 'PerfumeComposer_*.deb' | sort | tail -n 1)
if [ -z "$VERSION_FILE" ]; then
    echo "❌ Could not detect version (.deb missing in pool/)"
    exit 1
fi
VERSION=$(basename "$VERSION_FILE" | sed 's/PerfumeComposer_\(.*\)\.deb/\1/')
echo "🧩 Detected version: $VERSION"

INSTALLER_PATH="$WINDOWS_DIR/$INSTALLER_NAME"
INSTALLER_VERSIONED="$WINDOWS_DIR/PerfumeComposerSetup_${VERSION}.exe"

# --- Copy before cleaning anything ---
if [ -f "$INSTALLER_PATH" ]; then
    echo "📦 Copying and renaming $INSTALLER_PATH → $INSTALLER_VERSIONED..."
    cp -f "$INSTALLER_PATH" "$INSTALLER_VERSIONED"
else
    echo "❌ Error: $INSTALLER_PATH not found!"
    exit 1
fi

# --- Remove old unversioned installer ---
if [ -f "$WINDOWS_DIR/$INSTALLER_NAME" ]; then
    echo "🧹 Removing old unversioned installer ($INSTALLER_NAME)..."
    rm -f "$WINDOWS_DIR/$INSTALLER_NAME"
fi

# --- Delete older versioned installers (keep newest) ---
find "$WINDOWS_DIR" -type f -name "PerfumeComposerSetup_*.exe" ! -name "$(basename "$INSTALLER_VERSIONED")" -delete

# --- Clean Git repo cache ---
git lfs prune || true
git gc || true

# --- Sync repo with stash handling ---
echo "🔄 Syncing with remote repository..."
STASHED=false
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "📦 Local changes detected. Stashing temporarily..."
    git stash push -u -m "auto-stash-before-update_windows"
    STASHED=true
fi

git fetch origin main || true
git pull --rebase origin main || echo "⚠️  Rebase skipped or already up-to-date."

if [ "$STASHED" = true ]; then
    echo "📦 Restoring stashed local changes..."
    git stash pop || echo "⚠️  Could not reapply stashed changes automatically."
fi

# --- Commit and push new installer ---
echo "🪄 Committing and pushing new Windows installer..."
git add -A "$WINDOWS_DIR" || true
git commit -m "Update Windows installer for version ${VERSION}" || echo "🟡 Nothing new to commit."
git push origin main || echo "⚠️  Push skipped or already up-to-date."

PUBLIC_URL="$PUBLIC_BASE/PerfumeComposerSetup_${VERSION}.exe"
echo
echo "🌐 Download link:"
echo "   $PUBLIC_URL"
echo
echo "✅ Windows installer ${VERSION} successfully published!"

echo
read -rp "✅ Script finished. Press Enter to close..."

