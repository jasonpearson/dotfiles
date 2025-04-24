return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		vim.opt.showmode = false

		-- Define the CodeCompanion component
		local CodeCompanion = require("lualine.component"):extend()

		CodeCompanion.processing = false
		CodeCompanion.spinner_index = 1

		local spinner_symbols = {
			"🌕",
			"🌖",
			"🌗",
			"🌘",
			"🌑",
			"🌒",
			"🌓",
			"🌔",
			"😎",
			"🔮",
			"💪🏻",
			"🦄",
			"🙌🏻",
			"🌈",
			"🧐",
			"🙏",
			"🌕",
			"🌖",
			"🌗",
			"🌘",
			"🌑",
			"🌒",
			"🌓",
			"🌔",
			"🙈",
			"👾",
			"🔥",
			"🙀",
			"🤯",
			"💥",
			"😵",
			"☠️",
		}
		local spinner_symbols_len = 32

		-- Initializer
		function CodeCompanion:init(options)
			CodeCompanion.super.init(self, options)

			local group = vim.api.nvim_create_augroup("CodeCompanionHooks", {})

			vim.api.nvim_create_autocmd({ "User" }, {
				pattern = "CodeCompanionRequest*",
				group = group,
				callback = function(request)
					if request.match == "CodeCompanionRequestStarted" then
						self.processing = true
					elseif request.match == "CodeCompanionRequestFinished" then
						self.processing = false
					end
				end,
			})
		end

		-- Function that runs every time statusline is updated
		function CodeCompanion:update_status()
			if self.processing then
				self.spinner_index = (self.spinner_index % spinner_symbols_len) + 1
				return spinner_symbols[self.spinner_index]
			else
				return nil
			end
		end

		require("lualine").setup({
			-- 	tabline = {
			-- 		lualine_a = {
			-- 			{
			-- 				"tabs",
			-- 				tab_max_length = 50,
			-- 				max_length = 2000,
			-- 				mode = 2,
			-- 				path = 1,
			-- 			},
			-- 		},
			-- 	},
			options = {
				icons_enabled = true,
				theme = "auto",
				component_separators = { left = "|", right = "|" },
				section_separators = { left = "", right = "" },
				disabled_filetypes = {
					statusline = {},
					winbar = {},
				},
				ignore_focus = {},
				always_divide_middle = true,
				always_show_tabline = true,
				globalstatus = false,
				refresh = {
					statusline = 100,
					tabline = 100,
					winbar = 100,
				},
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { "branch", "diff", "diagnostics", CodeCompanion },
				lualine_c = { "filename" },
				lualine_x = { "lsp_status" },
				lualine_y = { "progress" },
				lualine_z = { "location" },
			},
			inactive_sections = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = { "filename" },
				lualine_x = { "location" },
				lualine_y = {},
				lualine_z = {},
			},
			tabline = {},
			winbar = {},
			inactive_winbar = {},
			extensions = {},
		})
	end,
}
