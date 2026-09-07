vim.keymap.set({ "i" }, "kj", "<Esc>")
vim.keymap.set("n", "<C-c>", "<cmd>:noh<cr>")
vim.keymap.set("n", "<leader><space>", "<cmd>buffers<cr>:buffer<Space>")
vim.keymap.set("n", "<leader>d", "<cmd>bd<cr>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>E", "<cmd>Explore<cr>")
vim.keymap.set("n", "<leader>e", "<cmd>e.<cr>")
vim.keymap.set("n", "<leader>n", "<cmd>bn<cr>")
vim.keymap.set("n", "<leader>p", "<cmd>bp<cr>")
vim.keymap.set("n", "<leader>Q", "<cmd>quitall<cr>")
vim.keymap.set("n", "<leader>q", "<cmd>quit<cr>")
vim.keymap.set("n", "<leader>v", "<cmd>vsp %:p:h<cr>")
vim.keymap.set("n", "<leader>V", "<cmd>vsp .<cr>")
vim.keymap.set("n", "<leader>h", "<cmd>Vexplore!<cr>")
vim.keymap.set("n", "<leader>H", "<cmd>topleft vsplit .<cr>")
vim.keymap.set("n", "<leader>s", "<cmd>Se<cr>")
vim.keymap.set("n", "<leader>S", "<cmd>sp .<cr>")
vim.keymap.set("n", "<leader>t", "<cmd>tabe %:p:h<cr>")
vim.keymap.set("n", "<leader>T", "<cmd>tabe .<cr>")
vim.keymap.set("n", "<leader>w", "<cmd>write<cr>")
vim.keymap.set({ "v" }, "<leader>y", '"+y') -- yank to system clipboard
vim.keymap.set({ "n" }, "<leader>y", '<cmd>let @* = fnamemodify(expand("%"), ":~:.")<cr>') -- yank full path to clipboard
vim.keymap.set({ "n" }, "<leader>Y", '<cmd>let @* = fnamemodify(expand("%"), ":t")<cr>') -- yank filename to clipboard

vim.keymap.set("n", "<leader>dd", function()
	vim.diagnostic.open_float(nil, { source = "always" })
end)
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next)
vim.keymap.set("n", "<leader>dl", vim.diagnostic.setloclist)
vim.keymap.set("n", "<C-n>", "<cmd>cnext<cr>")
vim.keymap.set("n", "<C-p>", "<cmd>cprev<cr>")
vim.keymap.set("n", "<leader>r", "<cmd>set relativenumber!<cr>")
vim.keymap.set("n", "<leader>W", "<cmd>set wrap!<cr>")

vim.keymap.set("n", "<leader>fq", function()
	local qf_open = vim.iter(vim.api.nvim_list_wins()):any(function(win)
		return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "qf"
	end)
	vim.cmd(qf_open and "cclose" or "copen")
end, { desc = "Toggle quickfix list" })


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

vim.keymap.set("n", "<leader>cp", function()
	vim.fn.setreg("+", vim.fn.expand("%"))
	vim.notify("Copied relative file path")
end, { desc = "Copy relative file path" })
vim.keymap.set("n", "<leader>cP", function()
	vim.fn.setreg("+", vim.fn.expand("%:p"))
	vim.notify("Copied absolute file path")
end, { desc = "Copy absolute file path" })

local group = vim.api.nvim_create_augroup("UserKeymaps", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
	group = group,
	pattern = "neo-tree",
	callback = function(event)
		local function focus_outer_left()
			if vim.env.TMUX then
				vim.fn.system({ "tmux", "select-pane", "-L" })
			elseif vim.env.HERDR_PANE_ID then
				vim.fn.system({ "herdr", "pane", "focus", "--current", "--direction", "left" })
			end
		end

		vim.keymap.set("n", "<C-h>", focus_outer_left, { buffer = event.buf, desc = "Go to left pane" })
		vim.keymap.set("n", "<BS>", focus_outer_left, { buffer = event.buf, desc = "Go to left pane" })
	end,
})
