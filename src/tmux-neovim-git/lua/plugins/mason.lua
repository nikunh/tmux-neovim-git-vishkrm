return {
	"williamboman/mason.nvim",
	version = "^1.0.0", -- Pin to v1.x
	opts = {
		ui = {
			icons = {
				package_installed = "✓",
				package_pending = "➜",
				package_uninstalled = "✗",
			},
		},
	},
}