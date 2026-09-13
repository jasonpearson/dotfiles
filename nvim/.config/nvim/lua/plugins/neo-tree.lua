local launch_cwd = vim.uv.cwd()

local function current_buffer_parent_dir()
	local buf_name = vim.api.nvim_buf_get_name(0)
	if buf_name == "" then
		return launch_cwd
	end

	return vim.fn.fnamemodify(buf_name, ":p:h")
end

local function focus_neotree_in_current_window(dir)
	local file = vim.api.nvim_buf_get_name(0)
	require("neo-tree.command").execute({
		action = "focus",
		source = "filesystem",
		reveal = true,
		reveal_file = file ~= "" and file or nil,
		reveal_force_cwd = true,
		dir = dir,
		position = "current",
		toggle = false,
	})
end

return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		keys = {
			{
				"<leader>e",
				function()
					focus_neotree_in_current_window(launch_cwd)
				end,
				desc = "Explorer NeoTree root (started here)",
			},
			{
				"<leader>E",
				function()
					focus_neotree_in_current_window(current_buffer_parent_dir())
				end,
				desc = "Explorer NeoTree parent of current buffer",
			},
			{
				"<leader>h",
				function()
					local lazyvim = rawget(_G, "LazyVim")
					local dir = lazyvim and lazyvim.root() or vim.uv.cwd()
					require("neo-tree.command").execute({ toggle = true, reveal = true, dir = dir })
				end,
				desc = "Explorer NeoTree (Root Dir)",
			},
			{
				"<leader>H",
				function()
					require("neo-tree.command").execute({ toggle = true, reveal = true, dir = vim.uv.cwd() })
				end,
				desc = "Explorer NeoTree (cwd)",
			},
		},
		opts = function(_, opts)
			opts.filesystem = opts.filesystem or {}
			opts.filesystem.filtered_items = vim.tbl_deep_extend("force", opts.filesystem.filtered_items or {}, {
				visible = true,
				hide_dotfiles = false,
			})

			-- Make <Enter> exit filter mode and keep the filtered tree, so you can navigate results.
			opts.filesystem.window = opts.filesystem.window or {}
			local ff_map = opts.filesystem.window.fuzzy_finder_mappings or {}
			ff_map["<cr>"] = "close_keep_filter"
			if ff_map[1] and ff_map[1].n then
				ff_map[1].n["<cr>"] = "close_keep_filter"
			else
				ff_map[1] = ff_map[1] or { n = { ["<cr>"] = "close_keep_filter" } }
			end
			opts.filesystem.window.fuzzy_finder_mappings = ff_map

			opts.window = opts.window or {}
			opts.window.mappings = vim.tbl_deep_extend("force", opts.window.mappings or {}, {
				["l"] = {
					function(state)
						local fs_commands = require("neo-tree.sources.filesystem.commands")
						local common_commands = require("neo-tree.sources.common.commands")

						fs_commands.open(state)

						local node = state.tree:get_node()
						if node and node.type == "file" then
							common_commands.close_window(state)
						end
					end,
					desc = "Open file and close explorer",
				},
			})
		end,
	},
}
