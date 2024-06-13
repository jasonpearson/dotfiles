return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		{ "antosha417/nvim-lsp-file-operations", config = true },
	},
	config = function()
		local lspconfig = require("lspconfig")
		local cmp_nvim_lsp = require("cmp_nvim_lsp")
		local opts = { noremap = true, silent = true }

		local on_attach = function(client, bufnr)
			local builtin = require("telescope.builtin")
			opts.buffer = bufnr

			vim.keymap.set("n", "gk", function()
				builtin.lsp_references({ path_display = { "truncate" } })
			end, opts)

			vim.keymap.set("n", "gd", builtin.lsp_definitions, opts)

			vim.keymap.set("n", "<leader>gdv", function()
				builtin.lsp_definitions({ jump_type = "vsplit" })
			end, opts)

			vim.keymap.set("n", "<leader>gdt", function()
				builtin.lsp_definitions({ jump_type = "tab" })
			end, opts)

			vim.keymap.set("n", "<leader>gds", function()
				builtin.lsp_definitions({ jump_type = "split" })
			end, opts)

			vim.keymap.set("n", "<leader>dd", vim.diagnostic.open_float)
			vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
			vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
			vim.keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts)
			vim.keymap.set("n", "gH", "<cmd>Telescope lsp_type_definitions<CR>", opts)
			vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
			vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
			vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
			vim.keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts)
		end

		-- used to enable autocompletion (assign to every lsp server config)
		local capabilities = cmp_nvim_lsp.default_capabilities()

		local signs = { Error = "☠️ ", Warn = "😭", Hint = "🤔", Info = "🤓" }
		for type, icon in pairs(signs) do
			local hl = "DiagnosticSign" .. type
			vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
		end

		lspconfig["cssls"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
		})

		lspconfig["denols"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
			root_dir = lspconfig.util.root_pattern("deno.json", "deno.jsonc"),
		})

		lspconfig["eslint"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
		})

		lspconfig["graphql"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
			filetypes = { "graphql", "gql", "svelte", "typescriptreact", "javascriptreact" },
		})

		lspconfig["html"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
		})

		lspconfig["kotlin_language_server"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
		})

		lspconfig["lua_ls"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
			settings = { -- custom settings for lua
				Lua = {
					-- make the language server recognize "vim" global
					diagnostics = {
						globals = { "vim" },
					},
					workspace = {
						-- make language server aware of runtime files
						library = {
							[vim.fn.expand("$VIMRUNTIME/lua")] = true,
							[vim.fn.stdpath("config") .. "/lua"] = true,
						},
					},
				},
			},
		})

		lspconfig["pyright"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
		})

		lspconfig["tailwindcss"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
		})

		lspconfig["tsserver"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
			root_dir = lspconfig.util.root_pattern("package.json"),
			single_file_support = false,
		})
	end,
}
