return {
	"olimorris/codecompanion.nvim",
	opts = {

		adapters = {
			copilot = function()
				return require("codecompanion.adapters").extend("copilot", {
					schema = {
						model = {
							default = "claude-3.7-sonnet",
						},
					},
				})
			end,
		},

		display = {
			chat = {
				window = {
					position = "right",
				},
			},
			diff = {
				provider = "mini_diff", -- default|mini_diff
			},
		},

		strategies = {
			chat = {
				adapter = "copilot",
			},
			inline = {
				adapter = "copilot",
			},
		},
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		{
			"echasnovski/mini.diff",
			version = false,
			config = function()
				local diff = require("mini.diff")
				diff.setup({
					source = diff.gen_source.none(),
				})
			end,
		},
	},

	init = function()
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
