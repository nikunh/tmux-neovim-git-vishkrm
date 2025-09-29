#!/usr/bin/env zsh
# tmux UTF-8 and locale configuration fragment

# Force UTF-8 mode in tmux (fixes Unicode rendering issues)
# Note: ZSH_TMUX_UNICODE=true is now set in main zshrc before Oh My Zsh loads

# Set UTF-8 locale for better compatibility
export LANG=${LANG:-C.utf8}
export LC_ALL=${LC_ALL:-C.utf8}
export LC_CTYPE=${LC_CTYPE:-C.utf8}

# Tmux popup help function for prompt symbols
tmux-help() {
    if [ -n "$TMUX" ]; then
        tmux display-popup -E -w 60 -h 20 "cat << 'EOF'
========================================
     PROMPT SYMBOLS & INDICATORS
========================================

Branch Status:
  🏠       - On main/master branch
  🏗️       - On local/custom branch
  🔀       - On any other branch

Git Status:
  ✓ ✔     - Success/Up-to-date
  ✗ ✘     - Error/Failed
  *       - Modified/Changed
  !       - Warning/Attention needed
  ?       - Unknown/Untracked

Git Sync:
  ⇣N      - Behind remote by N commits
  ⇡N      - Ahead of remote by N commits
  ⇠N      - Behind push remote
  ⇢N      - Ahead of push remote

Prompt:
  ╭─╮     - Top corners
  ╰─╯     - Bottom corners
  ➜       - Command prompt indicator

Press 'q' or ESC to close
EOF
"
    else
        # If not in tmux, just print the help
        cat << 'EOF'
========================================
     PROMPT SYMBOLS & INDICATORS
========================================

Branch Status:
  🏠       - On main/master branch
  🏗️       - On local/custom branch
  🔀       - On any other branch

Git Status:
  ✓ ✔     - Success/Up-to-date
  ✗ ✘     - Error/Failed
  *       - Modified/Changed
  !       - Warning/Attention needed
  ?       - Unknown/Untracked

Git Sync:
  ⇣N      - Behind remote by N commits
  ⇡N      - Ahead of remote by N commits
  ⇠N      - Behind push remote
  ⇢N      - Ahead of push remote

Prompt:
  ╭─╮     - Top corners
  ╰─╯     - Bottom corners
  ➜       - Command prompt indicator
EOF
    fi
}

# Create shorter alias for convenience
alias th='tmux-help'

# Add tmux keybinding for help popup (Ctrl-b then ?)
if [ -n "$TMUX" ]; then
    tmux bind-key ? run-shell "tmux display-popup -E -w 60 -h 20 'cat << EOF
========================================
     PROMPT SYMBOLS & INDICATORS
========================================

Branch Status:
  🏠       - On main/master branch
  🏗️       - On local/custom branch
  🔀       - On any other branch

Git Status:
  ✓ ✔     - Success/Up-to-date
  ✗ ✘     - Error/Failed
  *       - Modified/Changed
  !       - Warning/Attention needed
  ?       - Unknown/Untracked

Git Sync:
  ⇣N      - Behind remote by N commits
  ⇡N      - Ahead of remote by N commits
  ⇠N      - Behind push remote
  ⇢N      - Ahead of push remote

Prompt:
  ╭─╮     - Top corners
  ╰─╯     - Bottom corners
  ➜       - Command prompt indicator

Press q or ESC to close
EOF
'" 2>/dev/null || true
fi

echo "tmux UTF-8 settings loaded. Use 'tmux-help' or 'th' for symbol guide."