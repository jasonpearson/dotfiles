-- ensure vim-tmux-navigator keymap works from netrw
vim.api.nvim_create_autocmd("FileType", {
	pattern = "netrw",
	callback = function(ev)
		vim.keymap.set("n", "<c-l>", "<cmd>TmuxNavigateRight<cr>", { buffer = ev.buf, silent = true })
	end,
})
