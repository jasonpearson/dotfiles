return {
	"windwp/nvim-autopairs",
	cond = function()
		return not vim.g.vscode
	end,
	event = "InsertEnter",
	opts = {
		fast_wrap = {
			map = "<C-f>",
		},
	},
}
