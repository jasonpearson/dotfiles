return {
	"christoomey/vim-tmux-navigator",
	"nvim-treesitter/nvim-treesitter",
	"nvim-lua/plenary.nvim",
	"nvim-tree/nvim-web-devicons",
	"RRethy/nvim-base16",
	{
    'numToStr/Comment.nvim',
    opts = {
			toggler = {
				line = '<leader>cc',
				block = '<leader>bc',
			},
			opleader = {
				line = '<leader>c',
				block = '<leader>b',
			},
		},
    lazy = false,
	}
}
