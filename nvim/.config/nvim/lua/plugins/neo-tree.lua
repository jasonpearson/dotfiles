return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		keys = {
			{ "<leader>e", false },
			{ "<leader>E", false },
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
