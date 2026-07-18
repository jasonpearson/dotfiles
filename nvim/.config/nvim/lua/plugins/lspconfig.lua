---@diagnostic disable: undefined-global

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
		-- Installed by mason but deliberately not enabled: cssls, html, tailwindcss
		local install_servers = {
			"cssls",
			"eslint",
			"graphql",
			"html",
			"jdtls",
			"kotlin_language_server",
			"lua_ls",
			"tailwindcss",
			"ts_ls",
		}
		local enable_servers = {
			"eslint",
			"graphql",
			"jdtls",
			"kotlin_language_server",
			"lua_ls",
			"ts_ls",
		}

		require("mason").setup({
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		})

		require("mason-lspconfig").setup({
			ensure_installed = install_servers,
			automatic_installation = true,
			automatic_enable = false,
		})

		require("mason-tool-installer").setup({
			ensure_installed = { "eslint", "prettier", "stylua" },
		})

		vim.lsp.config("*", {
			capabilities = require("blink.cmp").get_lsp_capabilities(),
		})

		vim.lsp.config("kotlin_language_server", {
			init_options = {
				storagePath = vim.fn.stdpath("cache") .. "/kotlin_language_server",
			},
		})

		vim.lsp.config("lua_ls", {
			settings = {
				Lua = {
					diagnostics = { globals = { "vim" } },
					workspace = {
						-- Make the server aware of Neovim runtime files and plugins
						library = {
							[vim.fn.expand("$VIMRUNTIME/lua")] = true,
							[vim.fn.stdpath("config") .. "/lua"] = true,
							[vim.fn.stdpath("data") .. "/lazy/snacks.nvim/lua"] = true,
						},
					},
					completion = { callSnippet = "Replace" },
					-- Recognize the `---@type snacks.Config` annotation
					typeFormat = { enable = true },
				},
			},
		})

		vim.lsp.enable(enable_servers)

		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

				local Snacks = require("snacks")

				local function map(lhs, rhs, desc, mode)
					vim.keymap.set(mode or "n", lhs, rhs, { buffer = ev.buf, desc = desc, nowait = true })
				end

				-- Jump to a definition via `split_cmd` rather than the current window
				local function definition_in(split_cmd)
					return function()
						Snacks.picker.lsp_definitions({
							jump = { tagstack = true, reuse_win = false, close = true },
							confirm = function(picker, item)
								if not item then
									return
								end
								picker:close()
								vim.schedule(function()
									vim.cmd(split_cmd)
									if not item.file then
										return
									end
									local fname = type(item.file) == "string"
											and item.file:match("^file://")
											and vim.uri_to_fname(item.file)
										or item.file
									vim.cmd("edit! " .. vim.fn.fnameescape(fname))
									if item.pos then
										vim.api.nvim_win_set_cursor(0, item.pos)
									end
								end)
							end,
						})
					end
				end

				local function references_no_tests()
					Snacks.picker.lsp_references({
						filter = {
							filter = function(item)
								return not (item.file and item.file:lower():match("test"))
							end,
						},
					})
				end

				map("<leader>rs", "<cmd>LspRestart<cr>", "Restart LSP")
				map("K", vim.lsp.buf.hover, "Hover")
				map("<leader>rn", vim.lsp.buf.rename, "Rename")
				map("<leader>ca", vim.lsp.buf.code_action, "Code Action", { "n", "v" })

				map("gd", Snacks.picker.lsp_definitions, "Goto Definition")
				map("<leader>gdt", definition_in("tabnew"), "Goto Definition in new tab")
				map("<leader>gds", definition_in("split"), "Goto Definition in split")
				map("<leader>gdv", definition_in("vsplit"), "Goto Definition in vsplit")

				map("gr", references_no_tests, "References (no tests)")
				map("<leader>gr", references_no_tests, "References (no tests)")
				map("gR", Snacks.picker.lsp_references, "References (all)")
				map("<leader>gR", Snacks.picker.lsp_references, "References (all)")

				map("gy", Snacks.picker.lsp_type_definitions, "Goto T[y]pe Definition")
				map("gi", Snacks.picker.lsp_implementations, "Goto Implementation")
				map("gD", Snacks.picker.lsp_declarations, "Goto Declaration")
				map("<leader>ss", Snacks.picker.lsp_symbols, "LSP Symbols")
				map("<leader>ws", Snacks.picker.lsp_workspace_symbols, "LSP Workspace Symbols")

				map("<leader>wa", vim.lsp.buf.add_workspace_folder, "Add Workspace Folder")
				map("<leader>wr", vim.lsp.buf.remove_workspace_folder, "Remove Workspace Folder")
				map("<leader>wl", function()
					print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
				end, "List Workspace Folders")
			end,
		})
	end,
}
