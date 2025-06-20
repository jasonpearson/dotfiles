return {
	"kylechui/nvim-surround",
	cond = function()
		return not vim.g.vscode
	end,
	version = "*", -- Use for stability; omit to use `main` branch for the latest features
	event = "VeryLazy",
	config = function()
		require("nvim-surround").setup({
			-- Configuration here, or leave empty to use defaults
		})
	end,
}
