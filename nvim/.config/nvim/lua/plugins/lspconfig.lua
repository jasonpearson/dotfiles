---@diagnostic disable: undefined-global

return {
	"neovim/nvim-lspconfig",
	cond = function()
		return not vim.g.vscode
	end,
	dependencies = {
		"folke/snacks.nvim",
		"saghen/blink.cmp",
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
	},
	config = function()
		local capabilities = require("blink.cmp").get_lsp_capabilities()
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
			automatic_enable = false,
		})

		mason_tool_installer.setup({
			ensure_installed = {
				"eslint",
				"prettier",
				"stylua",
			},
		})

		vim.lsp.config("eslint", {
			capabilities = capabilities,
			-- on_attach = on_attach,
		})
		vim.lsp.enable("eslint")

		vim.lsp.config("graphql", {
			capabilities = capabilities,
			-- on_attach = on_attach,
		})
		vim.lsp.enable("graphql")

		vim.lsp.config("kotlin_language_server", {
			capabilities = capabilities,
			-- on_attach = on_attach,
		})
		vim.lsp.enable("kotlin_language_server")

		vim.lsp.config("jdtls", {
			capabilities = capabilities,
			-- on_attach = on_attach,
		})
		vim.lsp.enable("jdtls")

		vim.lsp.config("lua_ls", {
			capabilities = capabilities,
			-- on_attach = on_attach,
			settings = {
				Lua = {
					diagnostics = {
						globals = { "vim" },
					},
					workspace = {
						-- Make the server aware of Neovim runtime files and plugins
						library = {
							[vim.fn.expand("$VIMRUNTIME/lua")] = true,
							[vim.fn.stdpath("config") .. "/lua"] = true,
							-- Add snacks.nvim plugin path to the library
							[vim.fn.stdpath("data") .. "/lazy/snacks.nvim/lua"] = true,
						},
					},
					-- This helps with completion and type checking
					completion = {
						callSnippet = "Replace",
					},
					-- Tell lua_ls to recognize the `---@type snacks.Config` annotation
					typeFormat = {
						enable = true,
					},
				},
			},
		})
		vim.lsp.enable("lua_ls")

		vim.lsp.config("ts_ls", {
			capabilities = capabilities,
			-- root_dir = vim.lsp.config.util.root_pattern("package.json"),
			-- single_file_support = false,
		})
		vim.lsp.enable("ts_ls")

		vim.api.nvim_create_autocmd("LspAttach", {

			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				-- Enable completion triggered by <c-x><c-o>
				vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

				local Snacks = require("snacks")
				local opts = { buffer = ev.buf }

				vim.keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts)
				vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
				-- vim.keymap.set({ "n" }, "<C-k>", vim.lsp.buf.signature_help, opts)
				vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
				vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
				vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, opts)

				vim.keymap.set("n", "<leader>ss", function()
					Snacks.picker.lsp_symbols()
				end, vim.tbl_deep_extend("force", opts, { desc = "LSP Symbols" }))

				-- vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, opts)
				vim.keymap.set("n", "gd", function()
					Snacks.picker.lsp_definitions()
				end, vim.tbl_deep_extend("force", opts, { desc = "Goto Definition" }))

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

				vim.keymap.set("n", "<leader>gdt", function()
					Snacks.picker.lsp_definitions({
						jump = {
							tagstack = true,
							reuse_win = false, -- Don't reuse existing windows
							close = true,
						},
						confirm = function(picker, item)
							if not item then
								return
							end
							picker:close()
							vim.schedule(function()
								-- Open in new tab
								vim.cmd("tabnew")
								-- Jump to the file and location
								if item.file then
									local fname = type(item.file) == "string"
											and item.file:match("^file://")
											and vim.uri_to_fname(item.file)
										or item.file
									vim.api.nvim_command("edit! " .. vim.fn.fnameescape(fname))
									if item.pos then
										vim.api.nvim_win_set_cursor(0, item.pos)
									end
								end
							end)
						end,
					})
				end, vim.tbl_deep_extend("force", opts, { desc = "Goto Definition in new tab" }))

				vim.keymap.set("n", "<leader>gds", function()
					Snacks.picker.lsp_definitions({
						jump = {
							tagstack = true,
							reuse_win = false,
							close = true,
						},
						confirm = function(picker, item)
							if not item then
								return
							end
							picker:close()
							vim.schedule(function()
								-- Open in a horizontal split
								vim.cmd("split")
								-- Jump to the file and location
								if item.file then
									local fname = type(item.file) == "string"
											and item.file:match("^file://")
											and vim.uri_to_fname(item.file)
										or item.file
									vim.api.nvim_command("edit! " .. vim.fn.fnameescape(fname))
									if item.pos then
										vim.api.nvim_win_set_cursor(0, item.pos)
									end
								end
							end)
						end,
					})
				end, vim.tbl_deep_extend("force", opts, { desc = "Goto Definition in split" }))

				vim.keymap.set("n", "<leader>gdv", function()
					Snacks.picker.lsp_definitions({
						jump = {
							tagstack = true,
							reuse_win = false,
							close = true,
						},
						confirm = function(picker, item)
							if not item then
								return
							end
							picker:close()
							vim.schedule(function()
								-- Open in a vertical split
								vim.cmd("vsplit")
								-- Jump to the file and location
								if item.file then
									local fname = type(item.file) == "string"
											and item.file:match("^file://")
											and vim.uri_to_fname(item.file)
										or item.file
									vim.api.nvim_command("edit! " .. vim.fn.fnameescape(fname))
									if item.pos then
										vim.api.nvim_win_set_cursor(0, item.pos)
									end
								end
							end)
						end,
					})
				end, vim.tbl_deep_extend("force", opts, { desc = "Goto Definition in split" }))

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
