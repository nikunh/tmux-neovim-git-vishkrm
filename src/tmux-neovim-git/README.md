# Tmux + Neovim + Git - Modern Terminal Workspace

Advanced terminal-based development environment with Tmux session management, modern Neovim configuration, and enhanced Git workflows.

## 🎯 **What You Get**

### **🖥️ Tmux - Terminal Multiplexer**
- **Session Management**: Persistent terminal sessions
- **Window/Pane Management**: Multi-window, split-pane layouts
- **Custom Key Bindings**: Optimized for development workflows
- **Status Bar**: Rich status information with git integration

### **⚡ Modern Neovim Setup**
- **Lazy Plugin Management**: Fast, efficient plugin loading
- **LSP Integration**: Language Server Protocol support for multiple languages
- **AI Development Tools**: Integrated AI coding assistants
- **Git Integration**: Advanced git workflows within the editor
- **Modern UI**: Beautiful, functional interface with statuslines and file trees

### **🔧 Git Enhancements**
- **Interactive Git**: Enhanced git commands and workflows
- **Diff Tools**: Advanced diff and merge capabilities
- **Branch Management**: Visual branch management and workflows

## 🚀 **Getting Started**

### **Launch Tmux Session**
```bash
# Start new session
tmux

# Start named session
tmux new-session -s development

# Attach to existing session
tmux attach -t development

# List sessions
tmux list-sessions
```

### **Launch Neovim**
```bash
# Start Neovim
nvim

# Open specific file
nvim README.md

# Open directory
nvim .
```

## 🎮 **Tmux Usage**

### **Key Bindings** (Prefix: `Ctrl+b`)
```bash
# Session Management
Prefix + d          # Detach from session
Prefix + s          # List and switch sessions
Prefix + $          # Rename session

# Window Management  
Prefix + c          # Create new window
Prefix + n          # Next window
Prefix + p          # Previous window
Prefix + w          # List windows
Prefix + ,          # Rename window

# Pane Management
Prefix + %          # Split horizontally
Prefix + "          # Split vertically
Prefix + arrow      # Navigate panes
Prefix + z          # Toggle pane zoom
Prefix + x          # Close pane
```

### **Custom Commands**
```bash
# Development workspace
tmux-dev            # Create development session with predefined layout

# Quick session attach
ta development      # Attach to development session

# Session management
tk development      # Kill development session
```

## ⚡ **Neovim Configuration**

### **Lazy Plugin Manager**
The configuration uses Lazy.nvim for efficient plugin management:

```bash
# Plugin management in Neovim
:Lazy              # Open plugin manager
:Lazy sync         # Sync plugins
:Lazy update       # Update plugins
:Lazy clean        # Clean unused plugins
```

### **Key Features & Plugins**

#### **🤖 AI Integration**
- **[Copilot](lua/plugins/copilot.lua)**: GitHub Copilot integration
- **[Copilot Chat](lua/plugins/copilot-chat.lua)**: Interactive AI chat
- **[Avante](lua/plugins/avante-nvim.lua)**: Advanced AI assistance
- **[CodeCompanion](lua/plugins/codecompanion-nvim.lua)**: AI coding companion
- **[Ollama Integration](lua/plugins/ollama-nvim.lua)**: Local LLM support

#### **🔧 Development Tools**
- **[Mason](lua/plugins/mason.lua)**: LSP server management
- **[LSP Config](lua/plugins/mason-lspconfig.lua)**: Language server configuration  
- **[Completions](lua/plugins/cmp.lua)**: Advanced autocompletion
- **[Tree-sitter](lua/config/lazy.lua)**: Syntax highlighting and parsing

#### **📁 File Management**
- **[NerdTree](lua/plugins/nerdtree.lua)**: File explorer sidebar
- **Telescope**: Fuzzy finder for files, buffers, and more
- **File navigation**: Enhanced file jumping and management

#### **🔄 Git Integration**
- **Git Signs**: Line-by-line git information
- **Git Integration**: Commit, push, pull from within editor
- **Diff Tools**: Visual diff and merge tools

#### **🎨 UI & Productivity**
- **[Zen Mode](lua/plugins/zen-mode-nvim.lua)**: Distraction-free editing
- **Status Line**: Rich status information
- **Themes**: Multiple color schemes and customization

### **Configuration Files**

```
lua/
├── init.lua                    # Main configuration entry
├── config/
│   └── lazy.lua               # Lazy plugin manager setup
└── plugins/
    ├── avante-nvim.lua        # Avante AI integration
    ├── cmp.lua                # Completion configuration
    ├── codecompanion-nvim.lua # Code companion AI
    ├── copilot-chat.lua       # Copilot chat interface
    ├── copilot-cmp.lua        # Copilot completions
    ├── copilot.lua            # GitHub Copilot
    ├── mason-lspconfig.lua    # LSP server configuration
    ├── mason.lua              # LSP server manager
    ├── nerdtree.lua          # File explorer
    ├── nvim-aider.lua        # Aider integration
    ├── nvim-llama.lua        # Llama model integration
    ├── ollama-nvim.lua       # Ollama local LLM
    └── zen-mode-nvim.lua     # Zen mode configuration
```

## 🎯 **Common Workflows**

### **Development Session Setup**
```bash
# 1. Start tmux session
tmux new-session -s project

# 2. Create window layout
Prefix + %    # Split for editor and terminal
Prefix + "    # Split terminal for tests/logs

# 3. Start Neovim in main pane
nvim .

# 4. Navigate between panes as needed
Prefix + arrow keys
```

### **AI-Assisted Coding**
```bash
# In Neovim:
:Copilot enable          # Enable GitHub Copilot
:CopilotChat            # Open AI chat
:Avante                 # Launch Avante AI
:CodeCompanion          # Open code companion

# Use Tab to accept Copilot suggestions
# Use Alt+] and Alt+[ for next/previous suggestions
```

### **Git Workflow**
```bash
# In Neovim:
:Git status             # Check git status
:Git add %              # Add current file
:Git commit             # Commit changes
:Git push               # Push changes

# Visual diff
:Gvdiffsplit           # Split diff view
:Gdifftool             # Use diff tool
```

### **LSP Development**
```bash
# Language server features:
gd                     # Go to definition
gr                     # Find references  
K                      # Show hover information
<leader>rn             # Rename symbol
<leader>ca             # Code actions
<leader>f              # Format code
```

## 🔧 **Customization**

### **Tmux Configuration**
Edit `tmux/tmux.conf` for custom settings:
```bash
# Custom tmux settings
set -g prefix C-a              # Change prefix key
bind-key | split-window -h     # Custom split binding
set -g status-position top     # Move status bar to top
```

### **Neovim Configuration**
Modify Lua configuration files:
```lua
-- In lua/config/lazy.lua
require('lazy').setup({
  -- Add your custom plugins here
})

-- Custom key mappings
vim.keymap.set('n', '<leader>t', ':NvimTreeToggle<CR>')
```

### **AI Model Configuration**
```lua
-- Configure AI models in respective plugin files
require('copilot').setup({
  suggestion = { enabled = true },
  panel = { enabled = true },
})

-- Ollama local model setup
require('ollama').setup({
  model = 'codellama',
  url = 'http://localhost:11434',
})
```

## 🛠️ **Advanced Features**

### **Session Persistence**
```bash
# Save tmux session
Prefix + Ctrl+s

# Restore tmux session  
Prefix + Ctrl+r

# Auto-restore on startup (configured)
```

### **Multi-Language Support**
Configured LSP servers for:
- **Python**: pylsp, pyright
- **JavaScript/TypeScript**: tsserver
- **Go**: gopls
- **Rust**: rust-analyzer
- **Lua**: lua-language-server
- **And many more via Mason**

### **AI Model Switching**
```bash
# Switch between AI models in Neovim
:CopilotDisable        # Disable Copilot
:Avante switch         # Switch Avante model
:Ollama model llama2   # Use different local model
```

## 📋 **Keyboard Shortcuts Reference**

### **Tmux Shortcuts**
| Key | Action |
|-----|--------|
| `Prefix + c` | New window |
| `Prefix + d` | Detach session |
| `Prefix + %` | Split horizontal |
| `Prefix + "` | Split vertical |
| `Prefix + arrows` | Navigate panes |
| `Prefix + z` | Zoom pane |

### **Neovim Shortcuts**
| Key | Action |
|-----|--------|
| `<leader>e` | Toggle file explorer |
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `gd` | Go to definition |
| `gr` | Find references |
| `K` | Hover information |
| `<leader>ca` | Code actions |

## 🆘 **Troubleshooting**

### **Tmux Issues**
```bash
# List running sessions
tmux list-sessions

# Force kill session
tmux kill-session -t session-name

# Reset tmux configuration
tmux kill-server && tmux
```

### **Neovim Plugin Issues**
```bash
# In Neovim, check plugin status
:checkhealth           # Check system health
:Lazy sync             # Sync plugins
:Mason                 # Check LSP servers

# Reset plugin cache
rm -rf ~/.local/share/nvim/lazy/
:Lazy restore
```

### **LSP Not Working**
```bash
# Check LSP status in Neovim
:LspInfo              # Show LSP status
:Mason                # Install/update language servers

# Common LSP servers
:MasonInstall python-lsp-server
:MasonInstall typescript-language-server
```

### **AI Integration Issues**
```bash
# Check Copilot status
:Copilot status       # GitHub Copilot status
:Copilot auth         # Authenticate Copilot

# Check local AI models
ollama list           # List available models
ollama pull codellama # Pull missing models
```

## 🔗 **Related Documentation**

- **[AI-Assisted Development](../../../docs/04-development/ai-assisted-development.md)** - AI development workflows
- **[Development Guide](../../../docs/04-development/)** - Complete development documentation  
- **[Feature Catalog](../../../docs/08-reference/feature-catalog.md)** - All available features

---

*Modern terminal development environment - part of Shellinator Reloaded*