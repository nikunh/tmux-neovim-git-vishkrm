#!/bin/bash
set -e

# Function to execute command with sudo only if needed
run_with_sudo() {
    if [ "$(id -u)" = "0" ]; then
        # Running as root, no sudo needed
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        # Not root and sudo available
        sudo "$@"
    else
        # Not root and no sudo available - try without sudo (might fail)
        echo "Warning: Not running as root and sudo not available. Trying without sudo..." >&2
        "$@"
    fi
}

# Function to get runtime user from environment or current context
get_runtime_user() {
    # Try environment variables first (from docker-compose)
    if [ -n "${RUNTIME_USER:-}" ]; then
        echo "${RUNTIME_USER}"
        return
    fi
    
    # Try to detect from HOME environment
    if [ -n "${HOME:-}" ] && [ "${HOME}" != "/" ] && [ "${HOME}" != "/root" ]; then
        basename "${HOME}"
        return
    fi
    
    # Try to get from current user context
    if [ "${USER:-}" != "root" ] && [ -n "${USER:-}" ]; then
        echo "${USER}"
        return
    fi
    
    # Fall back to discovering from /home directory
    local home_user=$(ls -1 /home 2>/dev/null | head -1)
    if [ -n "${home_user}" ]; then
        echo "${home_user}"
        return
    fi
    
    # Final fallback to babaji for backward compatibility
    echo "${DEVPOD_USERNAME:-babaji}"
}

# Install newer Neovim version (LazyVim requires >= 0.8.0)
echo "Installing newer Neovim version for LazyVim compatibility..."
echo "Version 0.0.9 with fixed line endings and ARM64 support"

# Architecture detection for Neovim AppImage
if [ "$(uname -m)" = "x86_64" ]; then
    NVIM_APPIMAGE="nvim.appimage"
else
    NVIM_APPIMAGE="nvim-linux-arm64.appimage"
fi

# Install tmux and Neovim dependencies
# Wait for apt lock and refresh package database
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "Waiting for apt lock..."
    sleep 1
done
echo "Installing tmux and dependencies..."
export DEBIAN_FRONTEND=noninteractive
run_with_sudo apt-get update -qq
echo "Installing tmux specifically..."
if ! run_with_sudo apt-get install -y --no-install-recommends tmux; then
    echo "❌ First tmux install attempt failed, retrying with apt update..."
    run_with_sudo apt-get update
    run_with_sudo apt-get install -y --no-install-recommends tmux
fi

# Verify tmux installation
if command -v tmux >/dev/null 2>&1; then
    TMUX_VERSION=$(tmux -V)
    echo "✅ tmux installed successfully: ${TMUX_VERSION}"
else
    echo "❌ ERROR: tmux installation failed!"
    echo "❌ This is a critical issue - container may be unusable for development"
    exit 1
fi

echo "Installing other dependencies..."
run_with_sudo apt-get install -y --no-install-recommends curl fuse libfuse2 squashfs-tools openssh-client
cd /tmp
echo "Downloading Neovim AppImage for ${NVIM_APPIMAGE}..."
curl -LO "https://github.com/neovim/neovim/releases/latest/download/${NVIM_APPIMAGE}"
chmod u+x "${NVIM_APPIMAGE}"

# Try multiple AppImage extraction methods for Docker compatibility
echo "Extracting Neovim AppImage (trying multiple methods for Docker compatibility)..."
EXTRACTION_SUCCESS=false

# Method 1: Standard AppImage extraction (works if FUSE is available)
echo "Attempting standard AppImage extraction..."
if ./"${NVIM_APPIMAGE}" --appimage-extract >/dev/null 2>&1; then
    echo "✓ Standard AppImage extraction successful"
    EXTRACTION_SUCCESS=true
else
    echo "✗ Standard AppImage extraction failed (FUSE likely not available in container)"
fi

# Method 2: Extract-and-run method (Docker-friendly fallback)
if [ "$EXTRACTION_SUCCESS" = false ]; then
    echo "Attempting --appimage-extract-and-run method..."
    if ./"${NVIM_APPIMAGE}" --appimage-extract-and-run --version >/dev/null 2>&1; then
        echo "✓ AppImage extract-and-run works, but we need the extracted files..."
        # This method runs the app but doesn't extract files, so we still need extraction
        # Try forcing extraction without execution
        echo "Forcing manual extraction..."
        if timeout 30 ./"${NVIM_APPIMAGE}" --appimage-extract >/dev/null 2>&1; then
            EXTRACTION_SUCCESS=true
            echo "✓ Forced extraction successful"
        fi
    fi
fi

# Method 3: Alternative extraction approaches
if [ "$EXTRACTION_SUCCESS" = false ]; then
    echo "Attempting alternative extraction methods..."

    # Try with different AppImage environment variables
    export APPIMAGE_EXTRACT_AND_RUN=1
    if ./"${NVIM_APPIMAGE}" --appimage-extract >/dev/null 2>&1; then
        echo "✓ Alternative extraction method successful"
        EXTRACTION_SUCCESS=true
    else
        # Try unsquashfs if available
        if command -v unsquashfs >/dev/null 2>&1; then
            echo "Trying unsquashfs extraction..."
            if unsquashfs "${NVIM_APPIMAGE}" >/dev/null 2>&1; then
                mv squashfs-root squashfs-root 2>/dev/null || true
                EXTRACTION_SUCCESS=true
                echo "✓ unsquashfs extraction successful"
            fi
        fi
    fi
fi

# Verify extraction and install
if [ "$EXTRACTION_SUCCESS" = true ] && [ -d "squashfs-root" ]; then
    echo "✓ Neovim AppImage extraction successful - installing..."
    run_with_sudo mv squashfs-root /opt/nvim
    run_with_sudo ln -sf /opt/nvim/AppRun /usr/local/bin/nvim
    run_with_sudo ln -sf /usr/local/bin/nvim /usr/local/bin/vim
    echo "✓ Neovim installed successfully"

    # Verify installation
    if /opt/nvim/AppRun --version >/dev/null 2>&1; then
        NVIM_VERSION=$(/opt/nvim/AppRun --version | head -1)
        echo "✓ Neovim installation verified: ${NVIM_VERSION}"
    else
        echo "⚠ Warning: Neovim installation may have issues"
    fi
else
    echo "✗ All AppImage extraction methods failed!"
    echo "✗ This will prevent LazyVim from working properly"
    echo "✗ LazyVim requires Neovim >= 0.8.0, but Ubuntu 22.04 only provides 0.6.1"
    echo "✗ Container build will continue but Neovim setup is incomplete"
fi

rm "${NVIM_APPIMAGE}"

# SSH setup
RUNTIME_USER=$(get_runtime_user)
TARGET_HOME="/home/${RUNTIME_USER}"

# Create SSH directory for target user
if [ ! -d "${TARGET_HOME}/.ssh" ]; then
  mkdir -p "${TARGET_HOME}/.ssh"
fi

# Set ownership and permissions for target user's SSH directory
run_with_sudo chown -R "${RUNTIME_USER}:${RUNTIME_USER}" "${TARGET_HOME}/.ssh"
run_with_sudo find "${TARGET_HOME}/.ssh" -type d -exec chmod 700 {} \;
run_with_sudo find "${TARGET_HOME}/.ssh" -type f -exec chmod 600 {} \;
run_with_sudo find "${TARGET_HOME}/.ssh" -name "*.pub" -type f -exec chmod 644 {} \;

# Add GitHub to known_hosts for target user
if [ ! -f "${TARGET_HOME}/.ssh/known_hosts" ] || ! grep -q "github.com" "${TARGET_HOME}/.ssh/known_hosts" 2>/dev/null; then
  if command -v ssh-keyscan >/dev/null 2>&1; then
    ssh-keyscan github.com >> "${TARGET_HOME}/.ssh/known_hosts" 2>/dev/null || echo "Warning: Could not add GitHub to known_hosts"
    run_with_sudo chown "${RUNTIME_USER}:${RUNTIME_USER}" "${TARGET_HOME}/.ssh/known_hosts" 2>/dev/null || true
  else
    echo "Warning: ssh-keyscan not available, skipping GitHub known_hosts setup"
  fi
fi

# Add SSH config for GitHub for target user
if [ ! -f "${TARGET_HOME}/.ssh/config" ] || ! grep -q "StrictHostKeyChecking no" "${TARGET_HOME}/.ssh/config" 2>/dev/null; then
  echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> "${TARGET_HOME}/.ssh/config"
  run_with_sudo chown "${RUNTIME_USER}:${RUNTIME_USER}" "${TARGET_HOME}/.ssh/config"
fi
# Git config
if ! git config --global --get core.editor; then
  git config --global core.editor "vi"
fi
if ! git config --global --get http.sslVerify; then
  git config --global http.sslVerify false
fi
if [ -n "$GIT_USER_NAME" ] && [ -n "$GIT_USER_EMAIL" ]; then
  if ! git config --global --get user.name; then
    git config --global user.name "$GIT_USER_NAME"
  fi
  if ! git config --global --get user.email; then
    git config --global user.email "$GIT_USER_EMAIL"
  fi
  if ! git config --global --get init.defaultBranch; then
    git config --global init.defaultBranch main
  fi
fi
# NerdFonts
if [ ! -d ~/.local/share/fonts/nerdfonts ]; then
  mkdir -p ~/.local/share/fonts/nerdfonts
fi
if [ ! -f ~/.local/share/fonts/nerdfonts/Ubuntu\ Mono\ Nerd\ Font\ Complete.ttf ]; then
  curl -fLo /tmp/nerdfonts.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/UbuntuMono.zip
  unzip /tmp/nerdfonts.zip -d ~/.local/share/fonts/nerdfonts
  fc-cache -fv
  rm -rf /tmp/nerdfonts.zip
fi
# Get runtime user and set target home directory
RUNTIME_USER=$(get_runtime_user)
TARGET_HOME="/home/${RUNTIME_USER}"

# Neovim config
if [ ! -d "${TARGET_HOME}/.config/nvim" ]; then
  sudo -u "${RUNTIME_USER}" git clone https://github.com/LazyVim/starter "${TARGET_HOME}/.config/nvim"
  rm -rf "${TARGET_HOME}/.config/nvim/.git"
fi
if ! grep -q 'alias vi="nvim"' "${TARGET_HOME}/.zshrc"; then
  echo 'alias vi="nvim"' >> "${TARGET_HOME}/.zshrc"
fi
if ! grep -q 'alias vim="nvim"' "${TARGET_HOME}/.zshrc"; then
  echo 'alias vim="nvim"' >> "${TARGET_HOME}/.zshrc"
fi
if ! grep -q 'export OLLAMA_API_BASE=' "${TARGET_HOME}/.zshrc"; then
  echo 'export OLLAMA_API_BASE=${OLLAMA_URL:-http://localhost:11434}' >> "${TARGET_HOME}/.zshrc"
fi
if ! grep -q 'alias aider-chat=' "${TARGET_HOME}/.zshrc"; then
  echo 'alias aider-chat="pipx run aider-chat --edit-format whole"' >> "${TARGET_HOME}/.zshrc"
fi
# Copy tmux configuration from feature directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ ! -f "${TARGET_HOME}/.tmux.conf" ] && [ -f "${SCRIPT_DIR}/tmux/.tmux.conf" ]; then
  cp "${SCRIPT_DIR}/tmux/.tmux.conf" "${TARGET_HOME}/.tmux.conf"
  chown ${RUNTIME_USER}:${RUNTIME_USER} "${TARGET_HOME}/.tmux.conf"
fi
if ! grep -q 'eval "$(direnv hook zsh)"' "${TARGET_HOME}/.zshrc"; then
  echo 'eval "$(direnv hook zsh)"' >> "${TARGET_HOME}/.zshrc"
fi
if [ -x "$(command -v ssh)" ]; then
  if ! grep -q 'eval $(ssh-agent -s)' "${TARGET_HOME}/.zshrc"; then
    echo 'eval $(ssh-agent -s)' >> "${TARGET_HOME}/.zshrc"
  fi
fi
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "${TARGET_HOME}/.profile"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${TARGET_HOME}/.profile"
fi
# Ensure Neovim config directories exist
mkdir -p "${TARGET_HOME}/.config/nvim/lua/plugins" || true
mkdir -p "${TARGET_HOME}/.config/nvim/lua/config" || true

# Copy all Lua plugin/config files to correct locations
echo "Copying nvim plugins and configs..."
SOURCE_DIR="$(dirname "$0")"
echo "Source directory: ${SOURCE_DIR}"
echo "Target home: ${TARGET_HOME}"

# Find the correct build features directory during container build
BUILD_FEATURES_DIR=""
for dir in /tmp/build-features/*/lua/plugins; do
    if [ -d "$dir" ]; then
        BUILD_FEATURES_DIR="$(dirname "$(dirname "$dir")")"
        echo "Found build features directory: ${BUILD_FEATURES_DIR}"
        break
    fi
done

# Copy plugins with verbose output - try build features dir first, then source dir
if [ -n "${BUILD_FEATURES_DIR}" ] && [ -d "${BUILD_FEATURES_DIR}/lua/plugins" ]; then
    echo "Copying plugins from ${BUILD_FEATURES_DIR}/lua/plugins to ${TARGET_HOME}/.config/nvim/lua/plugins/"
    cp -v "${BUILD_FEATURES_DIR}/lua/plugins/"*.lua "${TARGET_HOME}/.config/nvim/lua/plugins/" || echo "Warning: Failed to copy some plugin files from build features"
elif [ -d "${SOURCE_DIR}/lua/plugins" ]; then
    echo "Copying plugins from ${SOURCE_DIR}/lua/plugins to ${TARGET_HOME}/.config/nvim/lua/plugins/"
    cp -v "${SOURCE_DIR}/lua/plugins/"*.lua "${TARGET_HOME}/.config/nvim/lua/plugins/" || echo "Warning: Failed to copy some plugin files from source"
else
    echo "Warning: Plugin source directory not found in either ${BUILD_FEATURES_DIR}/lua/plugins or ${SOURCE_DIR}/lua/plugins"
fi

# Copy config files
if [ -n "${BUILD_FEATURES_DIR}" ] && [ -d "${BUILD_FEATURES_DIR}/lua/config" ]; then
    echo "Copying configs from ${BUILD_FEATURES_DIR}/lua/config"
    cp -v "${BUILD_FEATURES_DIR}/lua/config/"*.lua "${TARGET_HOME}/.config/nvim/lua/config/" || echo "Warning: Failed to copy some config files from build features"
elif [ -d "${SOURCE_DIR}/lua/config" ]; then
    echo "Copying configs from ${SOURCE_DIR}/lua/config"
    cp -v "${SOURCE_DIR}/lua/config/"*.lua "${TARGET_HOME}/.config/nvim/lua/config/" || echo "Warning: Failed to copy some config files from source"
else
    echo "Warning: Config source directory not found in either ${BUILD_FEATURES_DIR}/lua/config or ${SOURCE_DIR}/lua/config"
fi

# Copy init.lua
if [ -n "${BUILD_FEATURES_DIR}" ] && [ -f "${BUILD_FEATURES_DIR}/lua/init.lua" ]; then
    echo "Copying init.lua from build features"
    cp -v "${BUILD_FEATURES_DIR}/lua/init.lua" "${TARGET_HOME}/.config/nvim/lua/" || echo "Warning: Failed to copy init.lua from build features"
elif [ -f "${SOURCE_DIR}/lua/init.lua" ]; then
    echo "Copying init.lua from source"
    cp -v "${SOURCE_DIR}/lua/init.lua" "${TARGET_HOME}/.config/nvim/lua/" || echo "Warning: Failed to copy init.lua from source"
fi

# Note: .tmux.conf copying is handled earlier in the script with proper SCRIPT_DIR logic

# Copy zsh fragments for tmux UTF-8 support to correct location
FRAGMENTS_DIR="${TARGET_HOME}/.ohmyzsh_source_load_scripts"
if [ ! -d "${FRAGMENTS_DIR}" ]; then
  mkdir -p "${FRAGMENTS_DIR}"
fi

if [ -f "${SCRIPT_DIR}/fragments/tmux-utf8.zshrc" ]; then
  echo "Installing tmux UTF-8 fragment..."
  cp "${SCRIPT_DIR}/fragments/tmux-utf8.zshrc" "${FRAGMENTS_DIR}/.tmux-utf8.zshrc"
  chown "${RUNTIME_USER}:${RUNTIME_USER}" "${FRAGMENTS_DIR}/.tmux-utf8.zshrc"
  chmod 644 "${FRAGMENTS_DIR}/.tmux-utf8.zshrc"
elif [ -f "${BUILD_FEATURES_DIR}/fragments/tmux-utf8.zshrc" ]; then
  echo "Installing tmux UTF-8 fragment from build features..."
  cp "${BUILD_FEATURES_DIR}/fragments/tmux-utf8.zshrc" "${FRAGMENTS_DIR}/.tmux-utf8.zshrc"
  chown "${RUNTIME_USER}:${RUNTIME_USER}" "${FRAGMENTS_DIR}/.tmux-utf8.zshrc"
  chmod 644 "${FRAGMENTS_DIR}/.tmux-utf8.zshrc"
fi

# Fix permissions for runtime user (prevents LazyVim permission errors)
echo "Fixing permissions for runtime user '${RUNTIME_USER}' configuration..."
run_with_sudo chown -R "${RUNTIME_USER}:${RUNTIME_USER}" "${TARGET_HOME}/.config" 2>/dev/null || true
run_with_sudo chown -R "${RUNTIME_USER}:${RUNTIME_USER}" "${TARGET_HOME}/.local" 2>/dev/null || true
run_with_sudo chown -R "${RUNTIME_USER}:${RUNTIME_USER}" "${TARGET_HOME}/.tmux.conf" 2>/dev/null || true

# Clean up
run_with_sudo apt-get clean
# Auto-trigger build Tue Sep 24 00:15:00 BST 2025
