return {
	{
		"neovim/nvim-lspconfig",
		keys = {
			{
				"<leader>uh",
				function()
					local enabled = vim.lsp.inlay_hint.is_enabled()
					vim.lsp.inlay_hint.enable(not enabled)
					vim.notify((enabled and "Disabled" or "Enabled") .. " inlay hints")
				end,
				desc = "Toggle Inlay Hints",
			},
		},
		opts = {
			inlay_hints = {
				enabled = false,
			},
			servers = {
				graphql = {},
				kotlin_language_server = {
					init_options = {
						storagePath = vim.fn.stdpath("cache") .. "/kotlin_language_server",
					},
				},
				lua_ls = {
					settings = {
						Lua = {
							diagnostics = { globals = { "vim" } },
							workspace = {
								library = {
									[vim.fn.expand("$VIMRUNTIME/lua")] = true,
									[vim.fn.stdpath("config") .. "/lua"] = true,
									[vim.fn.stdpath("data") .. "/lazy/snacks.nvim/lua"] = true,
								},
							},
							completion = { callSnippet = "Replace" },
							typeFormat = { enable = true },
						},
					},
				},
			},
		},
	},
}
