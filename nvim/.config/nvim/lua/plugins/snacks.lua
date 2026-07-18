---@diagnostic disable: undefined-global

local accent = "#94e2d5"

-- Straightforward `Snacks.picker.<name>()` bindings: lhs, picker, description
local pickers = {
	{ "<leader><space>", "smart", "Smart Find Files" },
	{ "<c-p>", "files", "Find Files" },
	{ "<leader>b", "buffers", "Buffers" },
	{ "<leader>/", "grep", "Grep" },
	{ "<leader>:", "command_history", "Command History" },
	-- find
	{ "<leader>fg", "git_files", "Find Git Files" },
	{ "<leader>fp", "projects", "Projects" },
	{ "<leader>fr", "recent", "Recent" },
	-- git
	{ "<leader>gb", "git_branches", "Git Branches" },
	{ "<leader>gl", "git_log", "Git Log" },
	{ "<leader>gL", "git_log_line", "Git Log Line" },
	{ "<leader>gs", "git_status", "Git Status" },
	{ "<leader>gS", "git_stash", "Git Stash" },
	{ "<leader>gd", "git_diff", "Git Diff (Hunks)" },
	{ "<leader>gf", "git_log_file", "Git Log File" },
	-- grep
	{ "<leader>sb", "lines", "Buffer Lines" },
	{ "<leader>?", "grep_buffers", "Grep Open Buffers" },
	-- search
	{ '<leader>"', "registers", "Registers" },
	{ "<leader>s/", "search_history", "Search History" },
	{ "<leader>sa", "autocmds", "Autocmds" },
	{ "<leader>sc", "command_history", "Command History" },
	{ "<leader>sC", "commands", "Commands" },
	{ "<leader>sd", "diagnostics", "Diagnostics" },
	{ "<leader>sD", "diagnostics_buffer", "Buffer Diagnostics" },
	{ "<leader>sh", "help", "Help Pages" },
	{ "<leader>sH", "highlights", "Highlights" },
	{ "<leader>si", "icons", "Icons" },
	{ "<leader>sj", "jumps", "Jumps" },
	{ "<leader>sk", "keymaps", "Keymaps" },
	{ "<leader>sl", "loclist", "Location List" },
	{ "<leader>sm", "marks", "Marks" },
	{ "<leader>sM", "man", "Man Pages" },
	{ "<leader>sp", "lazy", "Search for Plugin Spec" },
	{ "<leader>sq", "qflist", "Quickfix List" },
	{ "<leader>sR", "resume", "Resume" },
	{ "<leader>su", "undo", "Undo History" },
	{ "<leader>uC", "colorschemes", "Colorschemes" },
}

local function pick(name, opts)
	return function()
		Snacks.picker[name](opts)
	end
end

-- Bindings that need arguments or a non-picker entry point
local keys = {
	{
		"<leader>.",
		function()
			Snacks.scratch()
		end,
		desc = "Toggle Scratch Buffer",
	},
	{
		"<leader>S",
		function()
			Snacks.scratch.select()
		end,
		desc = "Select Scratch Buffer",
	},
	{
		"<leader>e",
		function()
			Snacks.explorer()
		end,
		desc = "File Explorer",
	},
	{
		"<leader>gB",
		function()
			Snacks.gitbrowse()
		end,
		desc = "Git Browse",
	},
	{
		"<leader>fc",
		pick("files", { cwd = vim.fn.stdpath("config") }),
		desc = "Find Config File",
	},
	{
		"<leader>sB",
		pick("grep_buffers", {
			search = function(picker)
				return picker:word()
			end,
		}),
		desc = "Grep Open Buffers (word under cursor)",
	},
	{
		"<leader>sw",
		pick("grep_word", { args = { "--word-regexp", "--glob=!*test*", "--glob=!*__tests__*" } }),
		desc = "Visual selection or word (no tests)",
		mode = { "n", "x" },
	},
	{
		"<leader>sW",
		pick("grep_word"),
		desc = "Visual selection or word (all)",
		mode = { "n", "x" },
	},
}

for _, spec in ipairs(pickers) do
	local lhs, name, desc = spec[1], spec[2], spec[3]
	table.insert(keys, { lhs, pick(name), desc = desc })
end

return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	init = function()
		for _, group in ipairs({ "Header", "Icon", "Key", "Desc", "Footer" }) do
			vim.api.nvim_set_hl(0, "SnacksDashboard" .. group, { fg = accent })
		end
	end,
	---@type snacks.Config
	opts = {
		bigfile = { enabled = false },
		dashboard = {
			preset = {
				header = [[
                                                                     
       ████ ██████           █████      ██                     
      ███████████             █████                             
      █████████ ███████████████████ ███   ███████████   
     █████████  ███    █████████████ █████ ██████████████   
    █████████ ██████████ █████████ █████ █████ ████ █████   
  ███████████ ███    ███ █████████ █████ █████ ████ █████  
 ██████  █████████████████████ ████ █████ █████ ████ ██████ 
        ]],
			},
		},
		explorer = { replace_netrw = false },
		gitbrowse = {},
		indent = { enabled = false },
		input = { enabled = false },
		picker = {
			layouts = {
				wide = {
					layout = {
						box = "vertical",
						width = 0.8,
						min_width = 160,
						height = 0.8,
						{
							box = "vertical",
							border = "rounded",
							title = "{title} {live} {flags}",
							{ win = "input", height = 1, border = "bottom" },
							{ win = "list", border = "none" },
						},
						{ win = "preview", title = "{preview}", border = "rounded" },
					},
				},
			},
			layout = { preset = "wide" },
			formatters = { file = { truncate = 200 } },
			win = {
				input = {
					keys = {
						["<c-n>"] = { "preview_scroll_down", mode = { "i", "n" } },
						["<c-p>"] = { "preview_scroll_up", mode = { "i", "n" } },
					},
				},
			},
		},
		notifier = { enabled = false },
		quickfile = { enabled = false },
		scope = { enabled = false },
		scratch = {},
		scroll = { enabled = false },
		terminal = {},
		statuscolumn = { enabled = false },
		words = { enabled = false },
	},
	keys = keys,
}
