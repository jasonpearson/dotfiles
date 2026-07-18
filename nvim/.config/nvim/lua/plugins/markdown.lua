return {
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "markdown" },
		opts = {
			-- Off by default; toggled with <leader>md
			enabled = false,
			render_modes = { "n" },
			anti_conceal = { enabled = false },
			completions = { blink = { enabled = true } },
			sign = { enabled = false },
		},
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
		ft = { "markdown" },
		cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
		build = "cd app && yarn install",
		init = function()
			vim.g.mkdp_filetypes = { "markdown" }
		end,
		keys = {
			{ "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview" },
		},
	},
}
