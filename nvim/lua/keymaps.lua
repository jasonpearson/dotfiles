vim.keymap.set({ "i" }, "kj", "<Esc>")
vim.keymap.set({ "n", "x" }, "<leader>y", '"+y') -- yank to system clipboard
vim.keymap.set("n", "<C-c>", "<cmd>:noh<cr>")
vim.keymap.set("n", "<leader><space>", "<cmd>buffers<cr>:buffer<Space>")
vim.keymap.set("n", "<leader>d", "<cmd>bd<cr>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>E", "<cmd>Explore<cr>")
vim.keymap.set("n", "<leader>ff", "<cmd>EslintFixAll<cr>")
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
