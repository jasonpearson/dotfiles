return {
	"hrsh7th/nvim-cmp",
	event = "InsertEnter",
	dependencies = {
		"hrsh7th/cmp-buffer", -- source for text in buffer
		"hrsh7th/cmp-path", -- source for file system paths
		"L3MON4D3/LuaSnip", -- snippet engine
		"saadparwaiz1/cmp_luasnip", -- for autocompletion
		"rafamadriz/friendly-snippets", -- useful snippets
		"onsails/lspkind.nvim",
	},
	config = function()
		local cmp = require("cmp")
		local luasnip = require("luasnip")
		local lspkind = require("lspkind")

		require("luasnip.loaders.from_vscode").lazy_load()

		local function confirm_or_copilot(fallback)
			if cmp.visible() then
				local entry = cmp.get_selected_entry()
				if entry then
					-- Confirm the selected completion item
					cmp.confirm({ select = true })

					-- Dismiss Copilot suggestion if it is active
					local copilot_status, copilot_result = pcall(vim.fn["copilot#Dismiss"])
					if not copilot_status then
						print("Error dismissing Copilot: " .. copilot_result)
					end
				else
					-- No entry selected, fallback to Copilot or default action
					fallback()
				end
			else
				-- Accept Copilot's suggestion if no completion is visible
				local copilot_status, copilot_result = pcall(vim.fn["copilot#Accept"])
				if not copilot_status then
					print("Error accepting Copilot: " .. copilot_result)
					fallback() -- If Copilot is not available or fails, use fallback action
				elseif copilot_result == "" then
					fallback() -- If Copilot has no suggestion, use fallback action
				end
			end
		end

		cmp.setup({
			completion = {
				completeopt = "menu,menuone,preview,noselect",
			},
			formatting = {
				format = lspkind.cmp_format({
					mode = "text",
					menu = {
						buffer = "[Buffer]",
						nvim_lsp = "[LSP]",
						luasnip = "[LuaSnip]",
						nvim_lua = "[Lua]",
						latex_symbols = "[Latex]",
					},
				}),
			},
			snippet = { -- configure how nvim-cmp interacts with snippet engine
				expand = function(args)
					luasnip.lsp_expand(args.body)
				end,
			},
			mapping = cmp.mapping.preset.insert({
				["<C-k>"] = cmp.mapping.select_prev_item(),
				["<C-j>"] = cmp.mapping.select_next_item(),
				["<C-b>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-y>"] = cmp.mapping(confirm_or_copilot, { "i", "s" }),
				["<C-n>"] = cmp.mapping.abort(),
				["<C-Space>"] = cmp.mapping(function(fallback)
					if cmp.visible() then
						if luasnip.expandable() then
							luasnip.expand()
						else
							cmp.confirm({ select = true })
						end
					else
						fallback()
					end
				end),

				["<Tab>"] = cmp.mapping(function(fallback)
					if luasnip.locally_jumpable(1) then
						luasnip.jump(1)
					else
						fallback()
					end
				end, { "i", "s" }),

				["<S-Tab>"] = cmp.mapping(function(fallback)
					if luasnip.locally_jumpable(-1) then
						luasnip.jump(-1)
					else
						fallback()
					end
				end, { "i", "s" }),
			}),
			sources = cmp.config.sources({
				{ name = "buffer" },
				{ name = "path" },
				{ name = "luasnip" },
				{ name = "nvim_lsp" },
			}),
		})
	end,
}
