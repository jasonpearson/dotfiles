return {
	"neovim/nvim-lspconfig",
	dependencies = {
		"folke/snacks.nvim",
		"saghen/blink.cmp",
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
	},
	config = function()
		local capabilities = require("blink.cmp").get_lsp_capabilities()
		local lspconfig = require("lspconfig")
		local mason = require("mason")
		local mason_lspconfig = require("mason-lspconfig")
		local mason_tool_installer = require("mason-tool-installer")

		mason.setup({
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		})

		mason_lspconfig.setup({
			ensure_installed = {
				"cssls",
				"eslint",
				"graphql",
				"html",
				"jdtls",
				"kotlin_language_server",
				"lua_ls",
				"tailwindcss",
				"ts_ls",
			},
			automatic_installation = true,
		})

		mason_tool_installer.setup({
			ensure_installed = {
				"eslint",
				"prettier",
				"stylua",
			},
		})

		lspconfig["graphql"].setup({
			capabilities = capabilities,
			-- on_attach = on_attach,
		})

		lspconfig["kotlin_language_server"].setup({
			capabilities = capabilities,
			-- on_attach = on_attach,
		})

		lspconfig["jdtls"].setup({
			capabilities = capabilities,
			-- on_attach = on_attach,
		})

		lspconfig["lua_ls"].setup({
			capabilities = capabilities,
			-- on_attach = on_attach,
			settings = {
				Lua = {
					diagnostics = {
						globals = { "vim" },
					},
				},
			},
		})

		lspconfig["ts_ls"].setup({
			capabilities = capabilities,
			root_dir = lspconfig.util.root_pattern("package.json"),
			-- single_file_support = false,
		})

		vim.api.nvim_create_autocmd("LspAttach", {

			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				-- Enable completion triggered by <c-x><c-o>
				vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

				local Snacks = require("snacks")
				local opts = { buffer = ev.buf }

				vim.keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts)
				vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
				vim.keymap.set({ "n" }, "<C-k>", vim.lsp.buf.signature_help, opts)
				vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
				vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
				vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, opts)
				vim.keymap.set("n", "<leader>f", function()
					vim.lsp.buf.format({ async = true })
				end, opts)

				vim.keymap.set("n", "<leader>ss", function()
					Snacks.picker.lsp_symbols()
				end, vim.tbl_deep_extend("force", opts, { desc = "LSP Symbols" }))

				-- vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, opts)
				vim.keymap.set("n", "gd", function()
					Snacks.picker.lsp_definitions()
				end, vim.tbl_deep_extend("force", opts, { desc = "Goto Defintiion" }))

				vim.keymap.set("n", "gr", function()
					Snacks.picker.lsp_references()
				end, vim.tbl_deep_extend("force", opts, { desc = "References", nowait = true }))

				-- vim.keymap.set("n", "<leader>gy", vim.lsp.buf.type_definition, opts)
				vim.keymap.set("n", "gy", function()
					Snacks.picker.lsp_type_definitions()
				end, vim.tbl_deep_extend("force", opts, { desc = "Goto T[y]pe Definition" }))

				-- vim.keymap.set("n", "<leader>gi", vim.lsp.buf.implementation, opts)
				vim.keymap.set("n", "gi", function()
					Snacks.picker.lsp_implementations()
				end, vim.tbl_deep_extend("force", opts, { desc = "Goto Implementation" }))

				-- vim.keymap.set("n", "<leader>gD", vim.lsp.buf.declaration, opts)
				vim.keymap.set("n", "gD", function()
					Snacks.picker.lsp_declarations()
				end, vim.tbl_deep_extend("force", opts, { desc = "Goto Declaration" }))

				vim.keymap.set("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, opts)
				vim.keymap.set("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, opts)
				vim.keymap.set("n", "<leader>wl", function()
					print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
				end, opts)
				vim.keymap.set("n", "<leader>ws", function()
					Snacks.picker.lsp_workspace_symbols()
				end, vim.tbl_deep_extend("force", opts, { desc = "LSP Workspace Symbols" }))
			end,
		})
	end,
}
