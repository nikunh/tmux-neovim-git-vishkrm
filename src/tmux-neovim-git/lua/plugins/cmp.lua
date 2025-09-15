-- ~/.config/nvim/lua/plugins/cmp.lua
return {
	"hrsh7th/nvim-cmp",
	event = "InsertEnter",
	dependencies = {
		"zbirenbaum/copilot-cmp", -- Add this dependency
		"hrsh7th/cmp-nvim-lsp",
	},
	---@param opts cmp.ConfigSchema
	opts = function(_, opts)
		-- Ensure 'copilot' source exists before adding
		local has_copilot = false
		for _, source in ipairs(opts.sources) do
			if source.name == "copilot" then
				has_copilot = true
				break
			end
		end
		if not has_copilot then
			table.insert(opts.sources, 1, { name = "copilot" })
		end
	end,
}
