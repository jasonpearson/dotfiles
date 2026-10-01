return {
	{
		"MeanderingProgrammer/render-markdown.nvim",
		keys = {
			{
				"<leader>md",
				function()
					require("render-markdown").toggle()
				end,
				desc = "Toggle Markdown Preview",
			},
		},
	},
	{
		"iamcco/markdown-preview.nvim",
		keys = {
			{ "<leader>cp", false },
			{ "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview" },
		},
	},
	{
		"mfussenegger/nvim-lint",
		optional = true,
		opts = function(_, opts)
			opts.linters = opts.linters or {}
			opts.linters["markdownlint-cli2"] = opts.linters["markdownlint-cli2"] or {}

			local efm = "stdin:%l:%c %m,stdin:%l %m"
			local parser = require("lint.parser").from_errorformat(efm, {
				source = "markdownlint",
				severity = vim.diagnostic.severity.WARN,
			})

			opts.linters["markdownlint-cli2"].parser = function(output, bufnr, linter_cwd)
				return vim.tbl_filter(function(diagnostic)
					return not diagnostic.message:match("MD013/line%-length")
				end, parser(output, bufnr, linter_cwd))
			end
		end,
	},
}
