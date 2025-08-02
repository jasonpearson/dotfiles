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

		local accent = "#51376D"

		local unified_theme = {
			normal = {
				a = { bg = accent, fg = "white", gui = "bold" },
				b = { bg = accent, fg = "white" },
				c = { bg = accent, fg = "white" },
				x = { bg = accent, fg = "white" },
				y = { bg = accent, fg = "white" },
				z = { bg = accent, fg = "white" },
			},
			insert = {
				a = { bg = accent, fg = "white", gui = "bold" },
				b = { bg = accent, fg = "white" },
				c = { bg = accent, fg = "white" },
				x = { bg = accent, fg = "white" },
				y = { bg = accent, fg = "white" },
				z = { bg = accent, fg = "white" },
			},
			visual = {
				a = { bg = accent, fg = "white", gui = "bold" },
				b = { bg = accent, fg = "white" },
				c = { bg = accent, fg = "white" },
				x = { bg = accent, fg = "white" },
				y = { bg = accent, fg = "white" },
				z = { bg = accent, fg = "white" },
			},
			replace = {
				a = { bg = accent, fg = "white", gui = "bold" },
				b = { bg = accent, fg = "white" },
				c = { bg = accent, fg = "white" },
				x = { bg = accent, fg = "white" },
				y = { bg = accent, fg = "white" },
				z = { bg = accent, fg = "white" },
			},
			command = {
				a = { bg = accent, fg = "white", gui = "bold" },
				b = { bg = accent, fg = "white" },
				c = { bg = accent, fg = "white" },
				x = { bg = accent, fg = "white" },
				y = { bg = accent, fg = "white" },
				z = { bg = accent, fg = "white" },
			},
			inactive = {
				a = { bg = accent, fg = "gray" },
				b = { bg = accent, fg = "gray" },
				c = { bg = accent, fg = "gray" },
				x = { bg = accent, fg = "gray" },
				y = { bg = accent, fg = "gray" },
				z = { bg = accent, fg = "gray" },
			},
		}

		require("lualine").setup({
			options = {
				globalstatus = true,
				theme = unified_theme,
				component_separators = { left = "", right = "" },
				section_separators = { left = "", right = "" },
				-- ... rest of your options
			},
			sections = {
				lualine_a = { "diff", "diagnostics", CodeCompanion },
				lualine_b = {
					{
						"filename",
						path = 1,
						file_status = true,
					},
				},
				lualine_c = {},
				lualine_x = {},
				lualine_y = {},
				lualine_z = { "lsp_status" },
			},
			inactive_sections = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = { { "filename", path = 0, file_status = true } },
				lualine_x = {},
				lualine_y = {},
				lualine_z = {},
			},
			tabline = {
				-- lualine_a = { { "filename", path = 0 } },
			},
			winbar = {
				lualine_a = {
					{
						"filename",
						path = 4,
						color = { fg = "white", bg = accent, gui = "bold" },
					},
				},
			},
			inactive_winbar = {
				lualine_a = {
					{
						"filename",
						path = 4,
						color = { fg = "8057AB", bg = "none", gui = "none" },
					},
				},
			},
			extensions = {},
		})

		vim.opt.laststatus = 3
	end,
}
