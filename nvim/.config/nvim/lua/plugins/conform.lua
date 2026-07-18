local format_opts = {
	lsp_fallback = true,
	async = false,
	timeout_ms = 1000,
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
	"stevearc/conform.nvim",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		formatters_by_ft = formatters_by_ft,
		format_on_save = function(bufnr)
			-- Leave JVM languages to their own LSP formatting
			local ft = vim.bo[bufnr].filetype
			if ft == "kotlin" or ft == "java" then
				return nil
			end
			return format_opts
		end,
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
}
