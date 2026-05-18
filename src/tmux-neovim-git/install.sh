#!/bin/bash
set -e
# Shebang: bash (not zsh) to avoid zsh USERNAME-special-parameter shadowing.

# Logging mechanism for debugging
LOG_FILE="/tmp/tmux-neovim-git-install.log"
log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $*" >> "$LOG_FILE"
}

# Initialize logging
log_debug "=== TMUX-NEOVIM-GIT INSTALL STARTED ==="
log_debug "Script path: $0"
log_debug "PWD: $(pwd)"
log_debug "Environment: USER=$USER HOME=$HOME"

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
    
    # Final fallback to vishkrm (canonical default since 2026-05-15)
    echo "${DEVPOD_USERNAME:-vishkrm}"
}

# Install newer Neovim version (LazyVim requires >= 0.8.0)
echo "Installing newer Neovim version for LazyVim compatibility..."
echo "Version 0.0.9 with fixed line endings and ARM64 support"

# Architecture detection for Neovim tarball
# (Switched from AppImage to tarball 2026-05-15: FUSE not available in container.
#  Tarball naming changed in v0.10.4 (Dec 2024): nvim-linux64 → nvim-linux-x86_64.
#  We try the new name first and fall back to the old name for older releases.)
if [ "$(uname -m)" = "x86_64" ]; then
    NVIM_TARBALL_CANDIDATES=("nvim-linux-x86_64.tar.gz" "nvim-linux64.tar.gz")
else
    NVIM_TARBALL_CANDIDATES=("nvim-linux-arm64.tar.gz")
fi

# Install tmux and Neovim dependencies
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "Waiting for apt lock..."
    sleep 1
done
echo "Installing tmux and dependencies..."
export DEBIAN_FRONTEND=noninteractive
run_with_sudo apt-get update -qq
echo "Installing tmux..."
if ! run_with_sudo apt-get install -y --no-install-recommends tmux; then
    echo "❌ First tmux install attempt failed, retrying with apt update..."
    run_with_sudo apt-get update
    run_with_sudo apt-get install -y --no-install-recommends tmux
fi

# Verify tmux installation
if command -v tmux >/dev/null 2>&1; then
    TMUX_VERSION=$(tmux -V)
    echo "✅ tmux installed: ${TMUX_VERSION}"
else
    echo "❌ ERROR: tmux installation failed!"
    exit 1
fi

echo "Installing other dependencies..."
run_with_sudo apt-get install -y --no-install-recommends curl tar gzip openssh-client

# Download + extract Neovim tarball (try each candidate URL)
NVIM_DOWNLOADED=false
NVIM_TARBALL=""
for candidate in "${NVIM_TARBALL_CANDIDATES[@]}"; do
    echo "Trying Neovim tarball: ${candidate}..."
    NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/${candidate}"
    if curl -fLo /tmp/nvim.tar.gz "$NVIM_URL"; then
        NVIM_TARBALL="$candidate"
        NVIM_DOWNLOADED=true
        echo "✓ Downloaded ${candidate} ($(stat -c%s /tmp/nvim.tar.gz) bytes)"
        break
    else
        echo "✗ ${candidate} not available (404 or download error)"
    fi
done

if [ "$NVIM_DOWNLOADED" = false ]; then
    echo "❌ All Neovim tarball downloads failed"
    echo "❌ Tried: ${NVIM_TARBALL_CANDIDATES[*]}"
    echo "❌ LazyVim won't work without nvim >= 0.8.0"
    exit 1
fi

# Derive extracted directory name from tarball (strip .tar.gz)
NVIM_DIR="${NVIM_TARBALL%.tar.gz}"

# Remove any prior install
run_with_sudo rm -rf /opt/nvim /opt/${NVIM_DIR}

# Extract to /opt
if run_with_sudo tar xzf /tmp/nvim.tar.gz -C /opt; then
    # Stable symlink: /opt/nvim → /opt/${NVIM_DIR} (so consumers don't need to know naming)
    run_with_sudo ln -sf "/opt/${NVIM_DIR}" /opt/nvim
    run_with_sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
    run_with_sudo ln -sf /usr/local/bin/nvim /usr/local/bin/vim
    if /opt/nvim/bin/nvim --version >/dev/null 2>&1; then
        NVIM_VERSION=$(/opt/nvim/bin/nvim --version | head -1)
        echo "✅ Neovim installed: ${NVIM_VERSION}"
    else
        echo "❌ nvim binary not executable after extract"
        exit 1
    fi
else
    echo "❌ tar extraction failed"
    exit 1
fi
rm -f /tmp/nvim.tar.gz

# SSH setup
RUNTIME_USER=$(get_runtime_user)
# Audit fix 2026-05-15: resolve home from /etc/passwd (not hardcoded /home/$RUNTIME_USER)
# and primary group from id -gn (vishkrm's group is 'users' not 'vishkrm').
TARGET_HOME=$(getent passwd "$RUNTIME_USER" 2>/dev/null | cut -d: -f6)
[ -z "$TARGET_HOME" ] && TARGET_HOME="/home/${RUNTIME_USER}"
RUNTIME_GROUP=$(id -gn "$RUNTIME_USER" 2>/dev/null || echo users)

# Create SSH directory for target user
if [ ! -d "${TARGET_HOME}/.ssh" ]; then
  mkdir -p "${TARGET_HOME}/.ssh"
fi

# Set ownership and permissions for target user's SSH directory
run_with_sudo chown -R "${RUNTIME_USER}:${RUNTIME_GROUP}" "${TARGET_HOME}/.ssh"
run_with_sudo find "${TARGET_HOME}/.ssh" -type d -exec chmod 700 {} \;
run_with_sudo find "${TARGET_HOME}/.ssh" -type f -exec chmod 600 {} \;
run_with_sudo find "${TARGET_HOME}/.ssh" -name "*.pub" -type f -exec chmod 644 {} \;

# Add GitHub to known_hosts for target user
if [ ! -f "${TARGET_HOME}/.ssh/known_hosts" ] || ! grep -q "github.com" "${TARGET_HOME}/.ssh/known_hosts" 2>/dev/null; then
  if command -v ssh-keyscan >/dev/null 2>&1; then
    ssh-keyscan github.com >> "${TARGET_HOME}/.ssh/known_hosts" 2>/dev/null || echo "Warning: Could not add GitHub to known_hosts"
    run_with_sudo chown "${RUNTIME_USER}:${RUNTIME_GROUP}" "${TARGET_HOME}/.ssh/known_hosts" 2>/dev/null || true
  else
    echo "Warning: ssh-keyscan not available, skipping GitHub known_hosts setup"
  fi
fi

# Add SSH config for GitHub for target user
if [ ! -f "${TARGET_HOME}/.ssh/config" ] || ! grep -q "StrictHostKeyChecking no" "${TARGET_HOME}/.ssh/config" 2>/dev/null; then
  echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> "${TARGET_HOME}/.ssh/config"
  run_with_sudo chown "${RUNTIME_USER}:${RUNTIME_GROUP}" "${TARGET_HOME}/.ssh/config"
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
# Get runtime user and set target home directory (re-resolved here in case different scope)
RUNTIME_USER=$(get_runtime_user)
TARGET_HOME=$(getent passwd "$RUNTIME_USER" 2>/dev/null | cut -d: -f6)
[ -z "$TARGET_HOME" ] && TARGET_HOME="/home/${RUNTIME_USER}"
RUNTIME_GROUP=$(id -gn "$RUNTIME_USER" 2>/dev/null || echo users)

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
SCRIPT_DIR="$(dirname "$0")"
log_debug "=== TMUX.CONF COPY SECTION === (Line 261)"
log_debug "SCRIPT_DIR: $SCRIPT_DIR"
log_debug "SCRIPT_DIR (absolute): $(cd "$SCRIPT_DIR" && pwd)"
log_debug "PWD: $(pwd)"
log_debug "TARGET_HOME: $TARGET_HOME"
log_debug "RUNTIME_USER: $RUNTIME_USER"
log_debug "Directory listing of SCRIPT_DIR: $(ls -la "$SCRIPT_DIR" 2>/dev/null || echo 'FAILED')"
log_debug "Directory listing of SCRIPT_DIR/tmux: $(ls -la "$SCRIPT_DIR/tmux" 2>/dev/null || echo 'FAILED')"
log_debug "Source file exists: $([ -f "${SCRIPT_DIR}/tmux/.tmux.conf" ] && echo "YES" || echo "NO")"
log_debug "Target file exists: $([ -f "${TARGET_HOME}/.tmux.conf" ] && echo "YES" || echo "NO")"

log_debug "Checking copy conditions..."
log_debug "Target file missing check: $([ ! -f "${TARGET_HOME}/.tmux.conf" ] && echo "TRUE" || echo "FALSE")"
log_debug "Source file exists check: $([ -f "${SCRIPT_DIR}/tmux/.tmux.conf" ] && echo "TRUE" || echo "FALSE")"
log_debug "Full source path: ${SCRIPT_DIR}/tmux/.tmux.conf"
log_debug "Full target path: ${TARGET_HOME}/.tmux.conf"
log_debug "Target directory exists: $([ -d "${TARGET_HOME}" ] && echo "YES" || echo "NO")"
log_debug "Target directory listing: $(ls -la "${TARGET_HOME}" 2>/dev/null | head -10 || echo 'FAILED')"

if [ ! -f "${TARGET_HOME}/.tmux.conf" ] && [ -f "${SCRIPT_DIR}/tmux/.tmux.conf" ]; then
  log_debug "Condition met - proceeding with copy (Line 272)"
  echo "Copying tmux.conf..."
  log_debug "About to execute: cp ${SCRIPT_DIR}/tmux/.tmux.conf ${TARGET_HOME}/.tmux.conf"
  if cp "${SCRIPT_DIR}/tmux/.tmux.conf" "${TARGET_HOME}/.tmux.conf" 2>/dev/null; then
    log_debug "tmux.conf copy successful"
    log_debug "Copied file size: $(ls -la "${TARGET_HOME}/.tmux.conf" 2>/dev/null || echo 'FAILED')"
    if chown ${RUNTIME_USER}:${RUNTIME_GROUP} "${TARGET_HOME}/.tmux.conf" 2>/dev/null; then
      log_debug "tmux.conf ownership change successful"
      log_debug "Final file permissions: $(ls -la "${TARGET_HOME}/.tmux.conf" 2>/dev/null || echo 'FAILED')"
    else
      log_debug "ERROR: tmux.conf ownership change failed"
    fi
  else
    log_debug "ERROR: tmux.conf copy failed"
    log_debug "Copy error details: $(cp "${SCRIPT_DIR}/tmux/.tmux.conf" "${TARGET_HOME}/.tmux.conf" 2>&1 || echo 'FAILED')"
  fi
else
  log_debug "Condition not met - skipping copy (Line 286)"
  log_debug "Reason: target exists=$([ -f "${TARGET_HOME}/.tmux.conf" ] && echo "YES" || echo "NO") OR source missing=$([ ! -f "${SCRIPT_DIR}/tmux/.tmux.conf" ] && echo "YES" || echo "NO")"
fi
log_debug "Final target file exists: $([ -f "${TARGET_HOME}/.tmux.conf" ] && echo "YES" || echo "NO")"
log_debug "Final target file details: $(ls -la "${TARGET_HOME}/.tmux.conf" 2>/dev/null || echo 'NOT FOUND')"
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
log_debug "=== FRAGMENT INSTALLATION SECTION === (Line 353)"
FRAGMENTS_DIR="${TARGET_HOME}/.ohmyzsh_source_load_scripts"
log_debug "FRAGMENTS_DIR: $FRAGMENTS_DIR"
log_debug "Fragments dir exists: $([ -d "${FRAGMENTS_DIR}" ] && echo "YES" || echo "NO")"
log_debug "Directory listing of fragments dir: $(ls -la "$FRAGMENTS_DIR" 2>/dev/null || echo 'FAILED')"

if [ ! -d "${FRAGMENTS_DIR}" ]; then
  log_debug "Creating fragments directory"
  mkdir -p "${FRAGMENTS_DIR}"
  log_debug "Fragments dir created: $([ -d "${FRAGMENTS_DIR}" ] && echo "YES" || echo "NO")"
  log_debug "Directory listing after creation: $(ls -la "$FRAGMENTS_DIR" 2>/dev/null || echo 'FAILED')"
fi

# Get script directory for fragment copying
SCRIPT_DIR="$(dirname "$0")"
log_debug "SCRIPT_DIR for fragments: $SCRIPT_DIR"
log_debug "SCRIPT_DIR (absolute) for fragments: $(cd "$SCRIPT_DIR" && pwd)"
log_debug "Directory listing of SCRIPT_DIR/fragments: $(ls -la "$SCRIPT_DIR/fragments" 2>/dev/null || echo 'FAILED')"
log_debug "Source fragment file exists: $([ -f "${SCRIPT_DIR}/fragments/tmux-utf8.zshrc" ] && echo "YES" || echo "NO")"
log_debug "Target fragment file exists: $([ -f "${FRAGMENTS_DIR}/.tmux-utf8.zshrc" ] && echo "YES" || echo "NO")"

log_debug "Checking fragment copy conditions..."
log_debug "Full fragment source path: ${SCRIPT_DIR}/fragments/tmux-utf8.zshrc"
log_debug "Full fragment target path: ${FRAGMENTS_DIR}/.tmux-utf8.zshrc"

if [ -f "${SCRIPT_DIR}/fragments/tmux-utf8.zshrc" ]; then
  echo "Installing tmux UTF-8 fragment..."
  log_debug "Fragment source file found - proceeding with copy"
  log_debug "Source file details: $(ls -la "${SCRIPT_DIR}/fragments/tmux-utf8.zshrc" 2>/dev/null || echo 'FAILED')"
  log_debug "About to execute: cp ${SCRIPT_DIR}/fragments/tmux-utf8.zshrc ${FRAGMENTS_DIR}/.tmux-utf8.zshrc"

  if cp "${SCRIPT_DIR}/fragments/tmux-utf8.zshrc" "${FRAGMENTS_DIR}/.tmux-utf8.zshrc" 2>/dev/null; then
    log_debug "Fragment copy successful"
    log_debug "Copied fragment file details: $(ls -la "${FRAGMENTS_DIR}/.tmux-utf8.zshrc" 2>/dev/null || echo 'FAILED')"

    if chown "${RUNTIME_USER}:${RUNTIME_GROUP}" "${FRAGMENTS_DIR}/.tmux-utf8.zshrc" 2>/dev/null; then
      log_debug "Fragment ownership change successful"
    else
      log_debug "ERROR: Fragment ownership change failed"
      log_debug "Ownership error details: $(chown "${RUNTIME_USER}:${RUNTIME_GROUP}" "${FRAGMENTS_DIR}/.tmux-utf8.zshrc" 2>&1 || echo 'FAILED')"
    fi

    if chmod 644 "${FRAGMENTS_DIR}/.tmux-utf8.zshrc" 2>/dev/null; then
      log_debug "Fragment permissions change successful"
      log_debug "Final fragment permissions: $(ls -la "${FRAGMENTS_DIR}/.tmux-utf8.zshrc" 2>/dev/null || echo 'FAILED')"
    else
      log_debug "ERROR: Fragment permissions change failed"
      log_debug "Permissions error details: $(chmod 644 "${FRAGMENTS_DIR}/.tmux-utf8.zshrc" 2>&1 || echo 'FAILED')"
    fi
  else
    log_debug "ERROR: Fragment copy failed"
    log_debug "Fragment copy error details: $(cp "${SCRIPT_DIR}/fragments/tmux-utf8.zshrc" "${FRAGMENTS_DIR}/.tmux-utf8.zshrc" 2>&1 || echo 'FAILED')"
  fi
else
  log_debug "Fragment source file not found"
  log_debug "Attempted path: ${SCRIPT_DIR}/fragments/tmux-utf8.zshrc"
  log_debug "Available files in fragments dir: $(ls -la "${SCRIPT_DIR}/fragments/" 2>/dev/null || echo 'FAILED')"
  echo "Warning: tmux-utf8.zshrc fragment not found in ${SCRIPT_DIR}/fragments/"
fi

log_debug "Final fragment file exists: $([ -f "${FRAGMENTS_DIR}/.tmux-utf8.zshrc" ] && echo "YES" || echo "NO")"
log_debug "Final fragment file details: $(ls -la "${FRAGMENTS_DIR}/.tmux-utf8.zshrc" 2>/dev/null || echo 'NOT FOUND')"
log_debug "Final fragments directory listing: $(ls -la "${FRAGMENTS_DIR}" 2>/dev/null || echo 'FAILED')"

# ===========================================================================
# Phase 4: tpm bootstrap + plugin install (makes tmux-resurrect / continuum actually work)
# ===========================================================================
TPM_DIR="${TARGET_HOME}/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    echo "Installing tpm (Tmux Plugin Manager) for ${RUNTIME_USER}..."
    run_with_sudo -u "${RUNTIME_USER}" git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR" 2>&1 || \
        sudo git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR" 2>&1 || \
        echo "Warning: tpm clone failed (tmux plugins won't load)"
    run_with_sudo chown -R "${RUNTIME_USER}:${RUNTIME_GROUP}" "${TARGET_HOME}/.tmux" 2>/dev/null || true
fi

# Install plugins declared in .tmux.conf (headless — no tmux server needed)
TPM_INSTALL="$TPM_DIR/bin/install_plugins"
if [ -x "$TPM_INSTALL" ]; then
    echo "Installing tmux plugins via tpm..."
    sudo -u "${RUNTIME_USER}" -E HOME="${TARGET_HOME}" "$TPM_INSTALL" 2>&1 || \
        echo "Warning: tpm install_plugins failed (run 'prefix + I' inside tmux to retry)"
    run_with_sudo chown -R "${RUNTIME_USER}:${RUNTIME_GROUP}" "${TARGET_HOME}/.tmux" 2>/dev/null || true
fi

# Ensure NAS-anchored resurrect dir parent exists (the leaf is created at first save).
# This is harmless if NAS isn't mounted yet — mkdir -p won't fail on non-existent paths above mountpoints.
sudo -u "${RUNTIME_USER}" mkdir -p "${TARGET_HOME}/.cache/tmux" 2>/dev/null || true

# Fix permissions for runtime user (prevents LazyVim permission errors)
echo "Fixing permissions for runtime user '${RUNTIME_USER}' configuration..."
run_with_sudo chown -R "${RUNTIME_USER}:${RUNTIME_GROUP}" "${TARGET_HOME}/.config" 2>/dev/null || true
run_with_sudo chown -R "${RUNTIME_USER}:${RUNTIME_GROUP}" "${TARGET_HOME}/.local" 2>/dev/null || true
run_with_sudo chown -R "${RUNTIME_USER}:${RUNTIME_GROUP}" "${TARGET_HOME}/.tmux.conf" 2>/dev/null || true
run_with_sudo chown -R "${RUNTIME_USER}:${RUNTIME_GROUP}" "${TARGET_HOME}/.tmux" 2>/dev/null || true

# Clean up
run_with_sudo apt-get clean

# Final logging
log_debug "=== TMUX-NEOVIM-GIT INSTALL COMPLETED ==="
log_debug "Log file location: $LOG_FILE"
echo "Installation complete. Debug log available at: $LOG_FILE"

# Auto-trigger build Tue Sep 24 00:15:00 BST 2025
# Auto-trigger build Sun Sep 28 03:47:34 BST 2025
