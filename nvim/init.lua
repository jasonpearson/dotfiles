vim.g.base16colorspace = 256
vim.g.mapleader = " "
vim.g.netrw_banner = 0

vim.opt.backspace = "indent,eol,start"
vim.opt.breakindent = true
vim.opt.cursorline = true
vim.opt.equalalways = true
vim.opt.expandtab = true
vim.opt.hlsearch = true
vim.opt.ignorecase = false
vim.opt.mouse = "a"
vim.opt.number = true
vim.opt.smartcase = true
vim.opt.shiftwidth = 2
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.swapfile = false
vim.opt.tabstop = 2
vim.opt.timeoutlen = 300
vim.opt.updatetime = 1000
vim.opt.wildignorecase = true
vim.opt.wrap = false

vim.keymap.set({ "i" }, "kj", "<Esc>")
vim.keymap.set({ "n", "x" }, "<leader>y", '"+y') -- yank to system clipboard
vim.keymap.set("n", "<C-c>", "<cmd>:noh<cr>")
vim.keymap.set("n", "<leader><space>", "<cmd>buffers<cr>:buffer<Space>")
vim.keymap.set("n", "<leader>d", "<cmd>bd<cr>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>E", "<cmd>E<cr>")
vim.keymap.set("n", "<leader>e", "<cmd>e.<cr>")
vim.keymap.set("n", "<leader>n", "<cmd>bn<cr>")
vim.keymap.set("n", "<leader>p", "<cmd>bp<cr>")
vim.keymap.set("n", "<leader>Q", "<cmd>quitall<cr>")
vim.keymap.set("n", "<leader>q", "<cmd>quit<cr>")
vim.keymap.set("n", "<leader>V", "<cmd>vsp %:p:h<cr>")
vim.keymap.set("n", "<leader>v", "<cmd>vsp .<cr>")
vim.keymap.set("n", "<leader>VV", "<cmd>topleft vsplit .<cr>")
vim.keymap.set("n", "<leader>vv", "<cmd>Ve<cr>")
vim.keymap.set("n", "<leader>S", "<cmd>Se<cr>")
vim.keymap.set("n", "<leader>s", "<cmd>sp .<cr>")
vim.keymap.set("n", "<leader>t", "<cmd>tabe<cr>")
vim.keymap.set("n", "<leader>w", "<cmd>write<cr>")
vim.keymap.set("n", "<leader>Y", '<cmd>let @*=expand("%")<cr>') -- copy filename to clipboard

vim.cmd([[
augroup netrw_mapping
  autocmd!
  autocmd FileType netrw lua vim.api.nvim_buf_set_keymap(0, "n", "<c-l>", ":TmuxNavigateRight<CR>", { noremap = true, silent = true })
augroup END
]])

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	{ import = "plugins" },
	{ import = "plugins.lsp" },
})
