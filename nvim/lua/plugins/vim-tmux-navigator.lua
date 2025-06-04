return {
	"christoomey/vim-tmux-navigator",
	cond = function()
		return not vim.g.vscode
	end,
}
