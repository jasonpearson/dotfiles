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
				always_show_tabline = false,
				globalstatus = true,
				theme = unified_theme,
				component_separators = { left = "", right = "" },
				section_separators = { left = "", right = "" },
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
				lualine_a = {
					{
						"tabs",
						mode = 2, -- Using mode 2 (shows tab name + index)
						max_length = vim.o.columns, -- Use exactly all available columns
						tab_max_length = 100,
						show_modified_status = true,
						tabs_color = {
							active = { fg = "white", bg = accent, gui = "bold" },
							inactive = { fg = "gray", bg = accent },
						},
						fmt = function(name, context)
							-- Get the buflist for this tab
							local buflist = vim.fn.tabpagebuflist(context.tabnr)
							if not buflist or #buflist == 0 then
								return name -- Fallback to default name if no buffer found
							end

							-- Get the current buffer in this tab
							local winnr = vim.fn.tabpagewinnr(context.tabnr)
							local bufnr = buflist[winnr]

							-- Get the full path of the buffer
							local buf_name = vim.api.nvim_buf_get_name(bufnr)

							-- If there's a valid path
							if buf_name and buf_name ~= "" and not buf_name:match("^%w+://") then
								-- Get the relative path from the current working directory
								local rel_path = vim.fn.fnamemodify(buf_name, ":.")

								-- Extract directory part from the relative path (remove filename)
								local dir_part = vim.fn.fnamemodify(rel_path, ":h")

								-- If we're in the current directory or just one level deep
								if dir_part == "." or not string.find(dir_part, "/") then
									return "./"
								else
									-- Remove the last directory segment
									local parent_dir = vim.fn.fnamemodify(dir_part, ":h")
									return parent_dir .. "/"
								end
							else
								-- For special buffers or unnamed files
								return name
							end
						end,
					},
				},
				lualine_b = {},
				lualine_c = {},
				lualine_x = {},
				lualine_y = {},
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
