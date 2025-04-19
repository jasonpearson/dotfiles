return {
	"saghen/blink.cmp",
	version = "1.*",
	opts = {
		keymap = {
			preset = "default",
			["<C-k>"] = { "select_prev", "fallback" },
			["<C-j>"] = { "select_next", "fallback" },
			["<C-p>"] = { "scroll_documentation_up", "fallback" },
			["<C-n>"] = { "scroll_documentation_down", "fallback" },
			["<C-e>"] = { "hide" },
		},

		appearance = {
			nerd_font_variant = "mono",
		},

		sources = {
			default = {
				"lsp",
				-- "path",
				-- "snippets",
				"buffer",
			},
		},

		fuzzy = { implementation = "prefer_rust_with_warning" },
	},
	opts_extend = { "sources.default" },
}
