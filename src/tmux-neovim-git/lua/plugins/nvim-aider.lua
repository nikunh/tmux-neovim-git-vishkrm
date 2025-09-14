return {
    "GeorgesAlkhouri/nvim-aider",
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
}
