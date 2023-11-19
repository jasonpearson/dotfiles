return {
	"nvim-telescope/telescope.nvim",
	branch = "0.1.4",
	dependencies = {
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		{ "nvim-lua/plenary.nvim" },
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")

		telescope.setup({
			defaults = {
				dynamic_preview_title = true,
				layout_strategy = "vertical",
				layout_config = {
					vertical = { width = 0.8 },
					horizontal = { width = 0.8 },
				},
				mappings = {
					i = {
						["<C-k>"] = actions.move_selection_previous, -- move to prev result
						["<C-j>"] = actions.move_selection_next, -- move to next result
						["<C-s>"] = actions.select_horizontal,
						["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
						["<C-d>"] = actions.delete_buffer,
					},
				},
				path_display = { truncate = 3 },
			},
			pickers = {
				buffers = {
					disable_devicons = true,
					theme = "ivy",
				},
				find_files = {
					layout_strategy = "horizontal",
					disable_devicons = true,
					layout_config = {
						preview_width = 0,
					},
				},
				grep_string = {
					disable_devicons = true,
					vimgrep_arguments = {
						"rg",
						"-l",
					},
				},
				live_grep = {
					disable_devicons = true,
					theme = "ivy",
					vimgrep_arguments = {
						"rg",
						"-l",
					},
				},
				lsp_references = {
					show_line = false,
				},
				lsp_definitions = {
					show_line = false,
				},
			},
		})

		telescope.load_extension("fzf")

		local builtin = require("telescope.builtin")

		vim.keymap.set("n", "<C-f>", builtin.buffers)

		vim.keymap.set("n", "<C-g>", function()
			builtin.live_grep({ vimgrep_arguments = { "rg", "-l", "-g", "!*test*", "--sort", "path" } })
		end)

		vim.keymap.set("n", "<C-p>", builtin.find_files)

		vim.keymap.set("n", "gs", function()
			builtin.grep_string({ vimgrep_arguments = { "rg", "-l", "-g", "!*test*", "--sort", "path" } })
		end)

		vim.keymap.set("n", "gsi", function()
			builtin.grep_string({ vimgrep_arguments = { "rg", "-l", "-i", "-g", "!*test*", "--sort", "path" } })
		end)

		vim.keymap.set("n", "gsa", builtin.grep_string)
	end,
}
