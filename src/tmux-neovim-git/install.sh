#!/bin/bash
set -e

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

# Install Neovim via AppImage extraction (more reliable than PPA)
apt-get update
apt-get install -y curl fuse libfuse2
cd /tmp
curl -LO "https://github.com/neovim/neovim/releases/latest/download/${NVIM_APPIMAGE}"
chmod u+x "${NVIM_APPIMAGE}"
./"${NVIM_APPIMAGE}" --appimage-extract
mv squashfs-root /opt/nvim
ln -sf /opt/nvim/AppRun /usr/local/bin/nvim
ln -sf /usr/local/bin/nvim /usr/local/bin/vim
rm "${NVIM_APPIMAGE}"

# SSH setup
if [ ! -d ~/.ssh ]; then
  mkdir -p ~/.ssh
fi
RUNTIME_USER=$(get_runtime_user)
sudo chown -R "${RUNTIME_USER}:${RUNTIME_USER}" "$HOME/.ssh"
sudo find "$HOME/.ssh" -type d -exec chmod 700 {} \;
sudo find "$HOME/.ssh" -type f -exec chmod 600 {} \;
sudo find "$HOME/.ssh" -name "*.pub" -type f -exec chmod 644 {} \;
if ! grep -q "github.com" ~/.ssh/known_hosts; then
  ssh-keyscan github.com >> ~/.ssh/known_hosts
fi
if ! grep -q "StrictHostKeyChecking no" ~/.ssh/config; then
  echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
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
if [ ! -f "${TARGET_HOME}/.tmux.conf" ] && [ -f /etc/static/configs/tmux/.tmux.conf ]; then
  cp /etc/static/configs/tmux/.tmux.conf "${TARGET_HOME}/.tmux.conf"
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

# Copy .tmux.conf to home directory from tmux folder
cp -n "$(dirname "$0")/tmux/.tmux.conf" "${TARGET_HOME}/.tmux.conf" 2>/dev/null || true

# Fix permissions for runtime user (prevents LazyVim permission errors)
echo "Fixing permissions for runtime user '${RUNTIME_USER}' configuration..."
chown -R "${RUNTIME_USER}:${RUNTIME_USER}" "${TARGET_HOME}/.config" 2>/dev/null || true 
chown -R "${RUNTIME_USER}:${RUNTIME_USER}" "${TARGET_HOME}/.local" 2>/dev/null || true
chown -R "${RUNTIME_USER}:${RUNTIME_USER}" "${TARGET_HOME}/.tmux.conf" 2>/dev/null || true

# Clean up
sudo apt-get clean
