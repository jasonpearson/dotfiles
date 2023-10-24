-- options
vim.g.base16_colorspace = 256
vim.g.mapleader = ' '
vim.g.netrw_banner = 0

vim.opt.breakindent = true
vim.opt.expandtab = false
vim.opt.hlsearch = false
vim.opt.ignorecase = true
vim.opt.mouse = 'a'
vim.opt.number = true
vim.opt.smartcase = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.wrap = false

-- plain keymaps
vim.keymap.set({'i'}, 'kj', '<Esc>')
vim.keymap.set({'n', 'x'}, 'y', '"+y') -- copy to system clipboard

-- leader keymaps
vim.keymap.set('n', '<leader><space>', '<cmd>buffers<cr>:buffer<Space>')
vim.keymap.set('n', '<leader>c', '<cmd>let @*=expand("%")<cr>')
vim.keymap.set('n', '<leader>d', '<cmd>bd<cr>')
vim.keymap.set('n', '<leader>E', '<cmd>E<cr>')
vim.keymap.set('n', '<leader>e', '<cmd>e.<cr>')
vim.keymap.set({'n', 'x', 'o'}, '<leader>h', '^')
vim.keymap.set('n', '<leader>n', '<cmd>bn<cr>')
vim.keymap.set('n', '<leader>p', '<cmd>bp<cr>')
vim.keymap.set('n', '<leader>q', '<cmd>quit<cr>')
vim.keymap.set('n', '<leader>V', '<cmd>Ve<cr>')
vim.keymap.set('n', '<leader>v', '<cmd>vsp .<cr>')
vim.keymap.set('n', '<leader>S', '<cmd>Se<cr>')
vim.keymap.set('n', '<leader>s', '<cmd>sp .<cr>')
vim.keymap.set('n', '<leader>t', '<cmd>tabe<cr>')
vim.keymap.set('n', '<leader>U', '<cmd>echo @%<cr>')
vim.keymap.set('n', '<leader>u', '<cmd>echo expand("%:~:.")<cr>')
vim.keymap.set('n', '<leader>w', '<cmd>write<cr>')

-- plugins
require("me.lazy")
require("mason").setup()

