return {
	"christoomey/vim-tmux-navigator",
	cond = function()
		return not vim.g.vscode
	end,
	config = function()
		vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-h>", { desc = "Navigate left from terminal" })
		vim.keymap.set("t", "<C-j>", "<C-\\><C-n><C-j>", { desc = "Navigate down from terminal" })
		vim.keymap.set("t", "<C-k>", "<C-\\><C-n><C-k>", { desc = "Navigate up from terminal" })
		vim.keymap.set("t", "<C-l>", "<C-\\><C-n><C-l>", { desc = "Navigate right from terminal" })
	end,
}
