return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		vim.opt.showmode = false

		local CodeCompanion = require("lualine.component"):extend()
		CodeCompanion.state = {
			processing = false,
		}
		CodeCompanion.spinner_symbols = {
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

		-- Initializer
		function CodeCompanion:init(options)
			CodeCompanion.super.init(self, options)

			local group = vim.api.nvim_create_augroup("CodeCompanionLualine", { clear = true })

			-- Listen for CodeCompanion events
			vim.api.nvim_create_autocmd("User", {
				pattern = "CodeCompanion*",
				group = group,
				callback = function(event)
					if event.match == "CodeCompanionRequestStarted" then
						self.state.processing = true
					elseif event.match == "CodeCompanionRequestFinished" then
						self.state.processing = false
					end

					require("lualine").refresh()
				end,
			})
		end

		function CodeCompanion:update_status()
			if self.state.processing then
				if not self.start_time then
					self.start_time = os.time()
					self.spinner_count = 1
				else
					-- Calculate how many spinners to show based on elapsed time
					local elapsed = os.time() - self.start_time
					self.spinner_count = math.min(1 + math.floor(elapsed / 2), 20) -- Add one every 2 seconds, max 20
				end

				-- Create text with random spinners
				local text = ""
				for i = 1, self.spinner_count do
					-- Choose a random index for each spinner
					local random_index = math.random(#self.spinner_symbols)
					text = text .. self.spinner_symbols[random_index] .. " "
				end

				-- Reset if we've reached the maximum
				if self.spinner_count >= 20 then
					self.start_time = nil -- Reset to start over
				end

				return text
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

		local filename_and_two_parents = {
			"filename",
			path = 1, -- Use relative path as base
			color = { fg = "white", bg = accent, gui = "bold" },
			fmt = function(str)
				-- Split the path
				local path_parts = {}
				for part in string.gmatch(str, "[^/]+") do
					table.insert(path_parts, part)
				end

				-- If we have at least 3 parts (2 dirs + filename), show last 3 parts
				if #path_parts >= 3 then
					return path_parts[#path_parts - 2]
						.. "/"
						.. path_parts[#path_parts - 1]
						.. "/"
						.. path_parts[#path_parts]
				elseif #path_parts == 2 then
					-- If we have 2 parts (1 dir + filename), show both
					return path_parts[1] .. "/" .. path_parts[2]
				else
					-- Just filename
					return str
				end
			end,
		}

		require("lualine").setup({
			options = {
				always_show_tabline = false,
				globalstatus = true,
				theme = unified_theme,
				component_separators = { left = "", right = "" },
				section_separators = { left = "", right = "" },
				refresh = {
					statusline = 500,
					tabline = 1000,
					winbar = 1000,
				},
			},
			sections = {
				lualine_a = {
					{ "branch", icon = "", color = { fg = "D6C8DE", gui = "none" }, padding = 0 },
					{
						"filename",
						path = 1,
						file_status = true,
						padding = { left = 1, right = 0 },
					},
					{
						function()
							return "%l:%c" -- Line:Column format
						end,
						padding = 0,
						icon = "",
						color = { fg = "D6C8DE", gui = "none" },
					},
				},
				lualine_b = {
					"diff",
					"diagnostics",
				},
				lualine_c = { "searchcount" },
				lualine_x = { CodeCompanion },
				lualine_y = { "lsp_status" },
				lualine_z = {},
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
							if buf_name and buf_name ~= "" and not buf_name:match("^%%w+://") then
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
					filename_and_two_parents,
				},
			},
			inactive_winbar = {
				lualine_a = {
					vim.tbl_extend("force", filename_and_two_parents, {
						color = { fg = "8057AB", bg = "none", gui = "none" },
					}),
				},
			},
			extensions = {},
		})

		vim.opt.laststatus = 3
	end,
}
