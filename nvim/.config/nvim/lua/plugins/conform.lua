local format_opts = {
	timeout_ms = 1000,
	async = false,
	lsp_format = "fallback",
}

local prettier_filetypes = {
	"css",
	"graphql",
	"html",
	"json",
	"jsonc",
	"liquid",
	"markdown",
	"yaml",
}

local formatters_by_ft = {
	javascript = { "biome" },
	javascriptreact = { "biome" },
	typescript = { "biome" },
	typescriptreact = { "biome" },
	lua = { "stylua" },
	python = { "isort", "black" },
}

for _, ft in ipairs(prettier_filetypes) do
	formatters_by_ft[ft] = { "prettier" }
end

return {
	{
		"stevearc/conform.nvim",
		opts = {
			default_format_opts = format_opts,
			formatters_by_ft = formatters_by_ft,
		},
		keys = {
			{
				"<leader>l",
				function()
					require("conform").format(format_opts)
				end,
				mode = { "n", "v" },
				desc = "Format file or range (in visual mode)",
			},
		},
	},
	{
		"mason-org/mason.nvim",
		opts = {
			ensure_installed = { "biome", "prettier", "isort", "black", "stylua" },
		},
	},
}
