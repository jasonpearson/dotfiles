return {
	"folke/zen-mode.nvim",
	opts = {
		-- your configuration comes here
		-- or leave it empty to use the default settings
		-- refer to the configuration section below
	},
	init = function()
		-- vim.g.mkdp_filetypes = { "markdown" }
		vim.keymap.set("n", "<leader>z", "<cmd>ZenMode<cr>", { desc = "Zen Mode" })
	end,
}
