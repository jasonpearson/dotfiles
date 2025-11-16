-- ensure vim-tmux-navigator keymap works from netrw
vim.cmd([[
augroup netrw_mapping
  autocmd!
  autocmd FileType netrw lua vim.api.nvim_buf_set_keymap(0, "n", "<c-l>", ":TmuxNavigateRight<CR>", { noremap = true, silent = true })
augroup END
]])
