return {
	"MeanderingProgrammer/render-markdown.nvim",
	ft = { "markdown", "codecompanion" },
	opts = {
		render_modes = true,
		completions = { blink = { enabled = true } },
		sign = {
			enabled = false,
		},
	},
	init = function()
		local renderMarkdown = require("render-markdown")
		renderMarkdown.setup({})

		vim.keymap.set("n", "<leader>md", function()
			renderMarkdown.toggle()
		end, { desc = "Toggle Markdown Preview" })
	end,
}
