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
vim.keymap.set("n", "<leader>h", "<cmd>Ve<cr>")
vim.keymap.set("n", "<leader>H", "<cmd>topleft vsplit .<cr>")
vim.keymap.set("n", "<leader>s", "<cmd>Se<cr>")
vim.keymap.set("n", "<leader>S", "<cmd>sp .<cr>")
vim.keymap.set("n", "<leader>t", "<cmd>tabe %:p:h<cr>")
vim.keymap.set("n", "<leader>T", "<cmd>tabe .<cr>")
vim.keymap.set("n", "<leader>w", "<cmd>write<cr>")
vim.keymap.set("n", "<leader>Y", '<cmd>let @*=expand("%")<cr>') -- copy filename to clipboard
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

vim.keymap.set("n", "<leader>fq", function()
	local wins = vim.api.nvim_list_wins()
	local qf_open = false

	for _, win in ipairs(wins) do
		local buf = vim.api.nvim_win_get_buf(win)

		if vim.bo[buf].filetype == "qf" then
			qf_open = true
			break
		end
	end

	if qf_open then
		vim.cmd("cclose")
	else
		vim.cmd("copen")
	end
end)
