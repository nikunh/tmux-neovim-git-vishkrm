return {
	"CopilotC-Nvim/CopilotChat.nvim",
	branch = "main",
	cmd = "CopilotChat",
	opts = {
		auto_insert_mode = true, -- Auto-insert responses into buffer
		window = {
			width = 0.4, -- 40% of Neovim window width
		},
	},
	keys = {
		{ "<leader>cc", "<cmd>CopilotChat<cr>", desc = "Toggle Copilot Chat" },
		{ "<leader>ce", "<cmd>CopilotChatExplain<cr>", desc = "Explain code" },
		{ "<leader>cf", "<cmd>CopilotChatFix<cr>", desc = "Fix code" },
		{ "<leader>ct", "<cmd>CopilotChatTests<cr>", desc = "Generate tests" },
	},
}
