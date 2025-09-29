local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                            "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- import/override with your plugins
    { import = "plugins" },
    {
      -- "olimorris/codecompanion.nvim", -- replace with actual plugin path
      config = function()
        require('plugins/nvim-aider').setup({
          cmd = {
            "AiderTerminalToggle",
          },
          keys = {
            { "<leader>a/", "<cmd>AiderTerminalToggle<cr>", desc = "Open Aider" },
            { "<leader>as", "<cmd>AiderTerminalSend<cr>", desc = "Send to Aider", mode = { "n", "v" } },
            { "<leader>ac", "<cmd>AiderQuickSendCommand<cr>", desc = "Send Command To Aider" },
            { "<leader>ab", "<cmd>AiderQuickSendBuffer<cr>", desc = "Send Buffer To Aider" },
            { "<leader>a+", "<cmd>AiderQuickAddFile<cr>", desc = "Add File to Aider" },
            { "<leader>a-", "<cmd>AiderQuickDropFile<cr>", desc = "Drop File from Aider" },
          },
          dependencies = {
            "folke/snacks.nvim",
            "nvim-telescope/telescope.nvim",
            --- The below dependencies are optional
            "catppuccin/nvim",
          },
          config = true,
          args = {
              "--no-auto-commits",
              "--pretty",
              "--stream",
              "--watch-files",
            },

            -- Theme colors (automatically uses Catppuccin flavor if available)
            theme = {
              user_input_color = "#a6da95",
              tool_output_color = "#8aadf4",
              tool_error_color = "#ed8796",
              tool_warning_color = "#eed49f",
              assistant_output_color = "#c6a0f6",
              completion_menu_color = "#cad3f5",
              completion_menu_bg_color = "#24273a",
              completion_menu_current_color = "#181926",
              completion_menu_current_bg_color = "#f4dbd6",
            },

            -- Other snacks.terminal.Opts options
            config = {
              os = { editPreset = "nvim-remote" },
              gui = { nerdFontsVersion = "3" },
            },

            win = {
              style = "nvim_aider",
              position = "bottom",
            },
        })
        require("plugins/codecompanion").setup({
          -- add your codecompanion configuration here
          display = {
            diff = {
              provider = "mini_diff",
            },
          },
          opts = {
            log_level = "TRACE",
          },
          strategies = {
            chat = {
              adapter = "ollama",
            },
            inline = {
              adapter = "ollama",
            },
            agent = {
              adapter = "ollama",
            },
          },
          adapters = {
            ollama = function()
              return require("codecompanion.adapters").extend("ollama", {

                env = {
                  url = "$ollama_url",
                  api_key = "OLLAMA_API_KEY",
                  model = "deepseek-coder-v2:latest",
                },
                headers = {
                  ["Content-Type"] = "application/json",
                  ["Authorization"] = "Bearer ${api_key}",
                },
                schema = {
                  model = {
                    default = "deepseek-coder-v2:latest",
                  },
                  parameters = {
                    sync = true,
                  },
                }
              })
            end,
          },
        })
        require("plugins/avante").setup(
          {
            ---@alias Provider "claude" | "openai" | "azure" | "gemini" | "cohere" | "copilot" | "ollama" | string
            --provider = "claude", -- Recommend using Claude
            --auto_suggestions_provider = "claude", -- Since auto-suggestions are a high-frequency operation and therefore expensive, it is recommended to specify an inexpensive provider or even a free provider: copilot
            provider = "ollama",                  -- Change provider to ollama
            auto_suggestions_provider = "ollama", -- Change to ollama for auto-suggestions
            --- existing configuration ...
            vendors = {
              ---@type AvanteProvider
              ollama = {
                ["local"] = true,
                endpoint = "$ollama_url/v1",
                model = "deepseek-coder-v2",
                parse_curl_args = function(opts, code_opts)
                  return {
                    url = opts.endpoint .. "/chat/completions",
                    headers = {
                      ["Accept"] = "application/json",
                      ["Content-Type"] = "application/json",
                    },
                    body = {
                      model = opts.model,
                      messages = require("avante.providers").copilot.parse_message(code_opts), -- you can make your own message, but this is very advanced
                      max_tokens = 2048,
                      stream = true,
                    },
                  }
                end,
                parse_response_data = function(data_stream, event_state, opts)
                  require("avante.providers").openai.parse_response(data_stream, event_state, opts)
                end,
              },
            },
            claude = {
              endpoint = "https://api.anthropic.com",
              model = "claude-3-5-sonnet-20240620",
              temperature = 0,
              max_tokens = 4096,
            },
            behaviour = {
              auto_suggestions = false, -- Experimental stage
              auto_set_highlight_group = true,
              auto_set_keymaps = true,
              auto_apply_diff_after_generation = false,
              support_paste_from_clipboard = false,
            },
            mappings = {
              --- @class AvanteConflictMappings
              diff = {
                ours = "co",
                theirs = "ct",
                all_theirs = "ca",
                both = "cb",
                cursor = "cc",
                next = "]x",
                prev = "[x",
              },
              suggestion = {
                accept = "<M-l>",
                next = "<M-]>",
                prev = "<M-[>",
                dismiss = "<C-]>",
              },
              jump = {
                next = "]]",
                prev = "[[",
              },
              submit = {
                normal = "<CR>",
                insert = "<C-s>",
              },
              sidebar = {
                switch_windows = "<Tab>",
                reverse_switch_windows = "<S-Tab>",
              },
            },
            hints = { enabled = true },
            windows = {
              ---@type "right" | "left" | "top" | "bottom"
              position = "right", -- the position of the sidebar
              wrap = true,        -- similar to vim.o.wrap
              width = 30,         -- default % based on available width
              sidebar_header = {
                align = "center", -- left, center, right for title
                rounded = true,
              },
            },
            highlights = {
              ---@type AvanteConflictHighlights
              diff = {
                current = "DiffText",
                incoming = "DiffAdd",
              },
            },
            --- @class AvanteConflictUserConfig
            diff = {
              autojump = true,
              ---@type string | fun(): any
              list_opener = "copen",
            },
          }
        )
      end
    },

  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = {
    enabled = true, -- check for plugin updates periodically
    notify = false, -- notify on update
  },                -- automatically check for plugin updates
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
