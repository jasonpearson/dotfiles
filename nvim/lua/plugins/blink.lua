return {
	{
		"saghen/blink.cmp",
		version = "1.*",
		dependencies = { "fang2hou/blink-copilot" },
		opts = {
			keymap = {
				preset = "default",
				["<C-k>"] = { "select_prev", "fallback" },
				["<C-j>"] = { "select_next", "fallback" },
				["<C-p>"] = { "scroll_documentation_up", "fallback" },
				["<C-n>"] = { "scroll_documentation_down", "fallback" },
				["<C-e>"] = { "hide" },
			},

			cmdline = {
				completion = {
					menu = {
						auto_show = true,
					},
				},
				keymap = {
					["<C-k>"] = { "select_prev", "fallback" },
					["<C-j>"] = { "select_next", "fallback" },
					["<C-p>"] = { "scroll_documentation_up", "fallback" },
					["<C-n>"] = { "scroll_documentation_down", "fallback" },
					["<C-e>"] = { "hide" },
				},
			},

			appearance = {
				nerd_font_variant = "mono",
			},

			sources = {
				default = {
					"copilot",
					"lsp",
					"path",
					-- "snippets",
					"buffer",
				},
				providers = {
					copilot = {
						name = "copilot",
						module = "blink-copilot",
						score_offset = 100,
						async = true,
					},
				},
			},

			fuzzy = { implementation = "prefer_rust_with_warning" },
		},
		opts_extend = { "sources.default" },
	},
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		event = "InsertEnter",
		opts = {
			suggestion = { enabled = false },
			panel = { enabled = false },
			filetypes = {
				markdown = true,
				help = true,
			},
		},
	},
}
