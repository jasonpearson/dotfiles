-- Options are automatically loaded before lazy.nvim startup.
require("config.remote_clipboard").setup()

vim.opt.backspace = "indent,eol,start"
vim.opt.breakindent = true
vim.opt.cursorline = true
vim.opt.equalalways = true
vim.opt.expandtab = true
vim.opt.foldlevelstart = 99
vim.opt.foldenable = false
vim.opt.hlsearch = true
vim.opt.ignorecase = false
vim.opt.number = true
vim.opt.relativenumber = true
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

vim.g.autoformat = false
