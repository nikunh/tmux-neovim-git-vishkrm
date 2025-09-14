-- bootstrap lazy.nvim, LazyVim and you r plugins
require("config.lazy")
-- enable show hidden files in NERDTree
-- vim.g.NERDTreeShowHidden = 1
-- autocmd VimEnter * Explore
vim.keymap.set("n", "<F5>", ":NERDTreeFocus<CR>", { desc = "Focus NERDTree" })
vim.opt.wrap = true -- Enable soft wrapping
vim.opt.linebreak = true -- (Optional) Wrap at word boundaries, not mid-word
vim.g.nerdtree_tabs_open_on_console_startup = 1
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		vim.cmd("NERDTree")
	end,
})
vim.api.nvim_create_user_command("TermHere", function()
	vim.cmd("split | lcd %:p:h | terminal")
end, {})