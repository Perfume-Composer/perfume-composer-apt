#!/bin/bash
set -e

echo "🌿 Installing Perfume Composer repository..."
REPO_URL="https://perfume-composer.github.io/perfume-composer-apt"
LIST_FILE="/etc/apt/sources.list.d/perfume-composer.list"
KEY_FILE="/usr/share/keyrings/perfume-composer.gpg"

# --- Step 1: Import GPG key ---
if [ ! -f "$KEY_FILE" ]; then
    echo "🔑 Importing repository key..."
    curl -fsSL "$REPO_URL/PERFUME-COMPOSER.gpg.key" | \
        gpg --dearmor | sudo tee "$KEY_FILE" >/dev/null
    sudo chmod 644 "$KEY_FILE"
else
    echo "✅ Repository key already installed."
fi

# --- Step 2: Add APT source list ---
if [ ! -f "$LIST_FILE" ]; then
    echo "🧩 Adding Perfume Composer APT source..."
    echo "deb [arch=amd64 signed-by=$KEY_FILE] $REPO_URL stable main" | \
        sudo tee "$LIST_FILE" >/dev/null
else
    echo "✅ APT source already exists."
fi

# --- Step 3: Update package cache ---
echo "🔄 Updating package lists..."
sudo apt update -qq

# --- Step 4: Install Perfume Composer ---
echo "💻 Installing Perfume Composer..."
sudo apt install -y perfumecomposer || {
    echo "❌ Installation failed. Try running 'sudo apt update' and retry."
    exit 1
}

echo
echo "✅ Perfume Composer installed successfully!"
echo "You can launch it from the applications menu or by running 'perfume-composer'."

