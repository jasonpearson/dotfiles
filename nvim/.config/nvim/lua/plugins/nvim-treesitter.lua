return {
	"nvim-treesitter/nvim-treesitter",
	cond = function()
		return not vim.g.vscode
	end,
	build = ":TSUpdate",
	config = function()
		local configs = require("nvim-treesitter.configs")

		configs.setup({
			ensure_installed = {
				"c",
				"elixir",
				"heex",
				"html",
				"javascript",
				"lua",
				"markdown",
				"markdown_inline",
				"query",
				"typescript",
				"tsx",
				"vim",
				"vimdoc",
				"yaml",
			},
			sync_install = false,
			highlight = { enable = true },
			indent = { enable = true },
		})
	end,
}
