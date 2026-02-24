return {
	"catppuccin/nvim",
	cond = function()
		return not vim.g.vscode
	end,
	name = "catppuccin",
	priority = 1000,
	init = function()
		require("catppuccin").setup({
			transparent_background = true,
		})
		vim.cmd.colorscheme("catppuccin-macchiato")
	end,
}
