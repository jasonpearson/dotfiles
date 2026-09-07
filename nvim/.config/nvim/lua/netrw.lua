-- ensure vim-tmux-navigator-style keymap works from netrw
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("UserNetrw", { clear = true }),
	pattern = "netrw",
	callback = function(ev)
		vim.keymap.set("n", "<c-l>", function()
			if vim.env.TMUX then
				vim.fn.jobstart({ "tmux", "select-pane", "-R" }, { detach = true })
			elseif vim.env.HERDR_PANE_ID then
				vim.fn.jobstart({ "herdr", "pane", "focus", "--current", "--direction", "right" }, { detach = true })
			end
		end, { buffer = ev.buf, silent = true, desc = "Go to right pane" })
	end,
})
