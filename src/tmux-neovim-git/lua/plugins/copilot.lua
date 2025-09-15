return {
	"zbirenbaum/copilot.lua",
	cmd = "Copilot",
	event = "InsertEnter",
	config = function()
		require("copilot").setup({
			suggestion = {
				enabled = false, -- Disable inline ghost text (use cmp instead)
				auto_trigger = true,
			},
			panel = { enabled = false }, -- Disable Copilot panel
		})
	end,
}
