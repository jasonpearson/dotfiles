vim.cmd([[
augroup netrw_mapping
  autocmd!
  autocmd FileType netrw lua NetrwMapping()
augroup END
]])

function NetrwMapping()
  vim.api.nvim_buf_set_keymap(0, 'n', '<c-l>', ':TmuxNavigateRight<CR>', { noremap = true, silent = true })
end
