return {
	"catppuccin/nvim",
	cond = function()
		return not vim.g.vscode
	end,
	name = "catppuccin",
	priority = 1000,
	init = function()
		require("catppuccin").setup({})
		vim.cmd.colorscheme("catppuccin-macchiato")
	end,
}
