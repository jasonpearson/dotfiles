return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		vim.opt.showmode = false

		local accent = "#94e2d5"

		-- Every mode looks the same except insert, which inverts section a
		local function mode_theme(fg)
			local theme = { z = { bg = "none", fg = fg } }
			for _, section in ipairs({ "a", "b", "c", "x", "y" }) do
				theme[section] = { bg = "black", fg = fg }
			end
			return theme
		end

		local unified_theme = {
			normal = mode_theme(accent),
			visual = mode_theme(accent),
			replace = mode_theme(accent),
			command = mode_theme(accent),
			inactive = mode_theme("gray"),
			insert = vim.tbl_extend("force", mode_theme(accent), {
				a = { bg = accent, fg = "black" },
			}),
		}

		local function cwd_short()
			return vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
		end

		require("lualine").setup({
			options = {
				always_show_tabline = false,
				globalstatus = false,
				theme = unified_theme,
				component_separators = { left = "", right = "" },
				section_separators = { left = "", right = "" },
				refresh = {
					statusline = 200,
					tabline = 200,
					winbar = 200,
				},
			},
			sections = {
				lualine_a = {
					{
						"filename",
						path = 1,
						file_status = true,
						padding = { left = 1, right = 1 },
						fmt = function(str)
							if str:find("%[No Name%]") then
								return cwd_short()
							end
							return str
						end,
					},
				},
				lualine_b = {
					{
						"diff",
						"diagnostics",
						function()
							return "%l:%c"
						end,
						padding = 0,
						icon = "",
						color = { fg = "D6C8DE", gui = "none" },
					},
					"searchcount",
				},
				lualine_c = {},
				lualine_x = {},
				lualine_y = {},
				lualine_z = {
					{ "branch", color = { bg = "black", fg = "7f849c", gui = "none" }, padding = 1 },
				},
			},
			inactive_sections = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = { { "filename", path = 1, file_status = true } },
				lualine_x = {},
				lualine_y = {},
				lualine_z = {},
			},
			tabline = {
				lualine_a = {
					{
						"tabs",
						mode = 2,
						max_length = vim.o.columns,
						tab_max_length = 100,
						show_modified_status = true,
						tabs_color = {
							active = { fg = "white", bg = "black", gui = "bold" },
							inactive = { fg = "gray", bg = "black" },
						},
						-- Label each tab with its buffer's parent directory
						fmt = function(name, context)
							local buflist = vim.fn.tabpagebuflist(context.tabnr)
							if not buflist or #buflist == 0 then
								return name
							end

							local bufnr = buflist[vim.fn.tabpagewinnr(context.tabnr)]
							local buf_name = vim.api.nvim_buf_get_name(bufnr)

							if buf_name == "" or buf_name:match("^%%w+://") then
								return cwd_short()
							end

							local dir_part = vim.fn.fnamemodify(vim.fn.fnamemodify(buf_name, ":."), ":h")
							if dir_part == "." or not dir_part:find("/") then
								return "./"
							end
							return vim.fn.fnamemodify(dir_part, ":h") .. "/"
						end,
					},
				},
				lualine_b = {},
				lualine_c = {},
				lualine_x = {},
				lualine_y = {},
			},
			extensions = {},
		})

		vim.opt.laststatus = 2
	end,
}
