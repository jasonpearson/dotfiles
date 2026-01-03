return {
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "markdown", "codecompanion" },
		opts = {
			render_modes = { "n" },
			completions = { blink = { enabled = true } },
			sign = {
				enabled = false,
			},
		},
		init = function()
			local renderMarkdown = require("render-markdown")
			renderMarkdown.setup({
				anti_conceal = { enabled = false },
			})

			vim.keymap.set("n", "<leader>md", function()
				renderMarkdown.toggle()
			end, { desc = "Toggle Markdown Preview" })
		end,
	},
	{
		"iamcco/markdown-preview.nvim",
		cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
		build = "cd app && yarn install",
		init = function()
			vim.g.mkdp_filetypes = { "markdown" }
			vim.keymap.set("n", "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", { desc = "Markdown Preview" })
		end,
		ft = { "markdown" },
	},
}
