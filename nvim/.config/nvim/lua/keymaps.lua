vim.keymap.set({ "i" }, "kj", "<Esc>")
vim.keymap.set("n", "<leader>E", "<cmd>Explore<cr>")
vim.keymap.set("n", "<leader>e", "<cmd>e.<cr>")
vim.keymap.set("n", "<leader>t", "<cmd>tabe %:p:h<cr>")
vim.keymap.set("n", "<leader>T", "<cmd>tabe .<cr>")
vim.keymap.set("n", "<leader>ww", "<cmd>write<cr>")

local function navigate(direction, tmux_flag, herdr_direction)
	return function()
		local before = vim.api.nvim_get_current_win()
		vim.cmd.wincmd(direction)

		if vim.api.nvim_get_current_win() ~= before then
			return
		end

		if vim.env.TMUX then
			vim.fn.jobstart({ "tmux", "select-pane", tmux_flag }, { detach = true })
		elseif vim.env.HERDR_PANE_ID then
			vim.fn.jobstart({ "herdr", "pane", "focus", "--current", "--direction", herdr_direction }, { detach = true })
		end
	end
end

vim.keymap.set("n", "<C-h>", navigate("h", "-L", "left"), { desc = "Go to left window or pane" })
vim.keymap.set("n", "<C-j>", navigate("j", "-D", "down"), { desc = "Go to lower window or pane" })
vim.keymap.set("n", "<C-k>", navigate("k", "-U", "up"), { desc = "Go to upper window or pane" })
vim.keymap.set("n", "<C-l>", navigate("l", "-R", "right"), { desc = "Go to right window or pane" })

vim.keymap.set("n", "<leader>yp", function()
  vim.fn.setreg("+", vim.fn.expand("%"))
  vim.notify("Copied relative file path")
end, { desc = "Copy relative file path" })

vim.keymap.set("n", "<leader>yP", function()
  vim.fn.setreg("+", vim.fn.expand("%:p"))
  vim.notify("Copied absolute file path")
end, { desc = "Copy absolute file path" })
