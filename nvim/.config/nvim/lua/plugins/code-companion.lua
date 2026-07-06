return {
	"olimorris/codecompanion.nvim",
	version = "^19.0.0",
	cond = function()
		return not vim.g.vscode
	end,
	opts = {},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		{
			"MeanderingProgrammer/render-markdown.nvim",
			ft = { "markdown", "codecompanion" },
		},
	},
	config = function()
		require("codecompanion").setup({
			interactions = {
				chat = {
					adapter = {
						name = "opencode",
						model = "claude-sonnet-4",
					},
				},
			},
			display = {
				chat = {
					window = {
						position = "right",
					},
				},
			},
			extensions = {},
		})

		vim.keymap.set({ "n", "v" }, "<leader>A", "<cmd>CodeCompanionActions<cr>", { noremap = true, silent = true })
		vim.keymap.set(
			{ "n", "v" },
			"<leader>a",
			"<cmd>CodeCompanionChat Toggle<cr>",
			{ noremap = true, silent = true }
		)
		vim.keymap.set("v", "ga", "<cmd>CodeCompanionChat Add<cr>", { noremap = true, silent = true })

		-- Expand 'cc' into 'CodeCompanion' in the command line
		vim.cmd([[cab cc CodeCompanion]])
	end,
}
