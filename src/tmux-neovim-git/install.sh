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

# Architecture detection for Neovim AppImage
if [ "$(uname -m)" = "x86_64" ]; then
    NVIM_ARCH=""
else
    NVIM_ARCH=".aarch64"
fi

# Install Neovim via AppImage extraction (more reliable than PPA)
apt-get update
apt-get install -y curl fuse libfuse2
cd /tmp
curl -LO "https://github.com/neovim/neovim/releases/latest/download/nvim${NVIM_ARCH}.appimage"
chmod u+x nvim${NVIM_ARCH}.appimage
./nvim${NVIM_ARCH}.appimage --appimage-extract
mv squashfs-root /opt/nvim
ln -sf /opt/nvim/AppRun /usr/local/bin/nvim
ln -sf /usr/local/bin/nvim /usr/local/bin/vim
rm nvim${NVIM_ARCH}.appimage

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
cp -r "$(dirname "$0")/lua/plugins/"* "${TARGET_HOME}/.config/nvim/lua/plugins/" 2>/dev/null || true
cp -r "$(dirname "$0")/lua/config/"* "${TARGET_HOME}/.config/nvim/lua/config/" 2>/dev/null || true
cp -n "$(dirname "$0")/lua/init.lua" "${TARGET_HOME}/.config/nvim/lua/" 2>/dev/null || true

# Copy .tmux.conf to home directory from tmux folder
cp -n "$(dirname "$0")/tmux/.tmux.conf" "${TARGET_HOME}/.tmux.conf" 2>/dev/null || true

# Fix permissions for runtime user (prevents LazyVim permission errors)
echo "Fixing permissions for runtime user '${RUNTIME_USER}' configuration..."
chown -R "${RUNTIME_USER}:${RUNTIME_USER}" "${TARGET_HOME}/.config" 2>/dev/null || true 
chown -R "${RUNTIME_USER}:${RUNTIME_USER}" "${TARGET_HOME}/.local" 2>/dev/null || true
chown -R "${RUNTIME_USER}:${RUNTIME_USER}" "${TARGET_HOME}/.tmux.conf" 2>/dev/null || true

# Clean up
sudo apt-get clean
