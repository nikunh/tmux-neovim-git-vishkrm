return {
	"preservim/nerdtree",
	dependencies = {
		"jistr/vim-nerdtree-tabs",
	},
	init = function()
		-- Disable netrw completely
		vim.g.loaded_netrw = 1
		vim.g.loaded_netrwPlugin = 1

		-- Always show hidden files
		vim.g.NERDTreeShowHidden = 1

		-- Configure nerdtree-tabs behavior
		vim.g.nerdtree_tabs_open_on_console_startup = 1 -- Auto-open NERDTree
		vim.g.nerdtree_tabs_smart_startup_focus = 1 -- Focus file when opening files
		vim.g.nerdtree_tabs_autoclose = 1 -- Clean exit when last window
		vim.g.nerdtree_tabs_autofind = 1 -- Auto-find current file
	end,
	cmd = { "NERDTree", "NERDTreeToggle" },
	keys = {
		{ "<leader>e", "<cmd>NERDTreeToggle<cr>", desc = "Explorer" },
	},
}