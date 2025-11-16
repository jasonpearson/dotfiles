return {
	"olimorris/codecompanion.nvim",
	cond = function()
		return not vim.g.vscode
	end,
	opts = {},
	dependencies = {
		-- "ravitemer/mcphub.nvim",
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		"echasnovski/mini.diff",
	},
	config = function()
		local diff = require("mini.diff")
		diff.setup({
			source = diff.gen_source.none(),
		})

		-- require("mcphub").setup({
		-- 	config = vim.fn.expand("~/.config/ai/mcpServers.json"),
		-- 	extensions = {
		-- 		codecompanion = {
		-- 			-- Show the mcp tool result in the chat buffer
		-- 			show_result_in_chat = true,
		-- 			-- Make chat #variables from MCP server resources
		-- 			make_vars = true,
		-- 			-- Create slash commands for prompts
		-- 			make_slash_commands = true,
		-- 		},
		-- 	},
		-- })

		require("codecompanion").setup({
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
			extensions = {
				-- mcphub = {
				-- 	callback = "mcphub.extensions.codecompanion",
				-- 	opts = {
				-- 		make_vars = true,
				-- 		make_slash_commands = true,
				-- 		show_result_in_chat = true,
				-- 	},
				-- },
			},
			strategies = {
				chat = {
					adapter = "copilot",
				},
				inline = {
					adapter = "copilot",
				},
			},
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
