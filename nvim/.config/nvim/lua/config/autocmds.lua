-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local function is_empty_unnamed_buffer(buf)
  if not vim.api.nvim_buf_is_loaded(buf) then
    return false
  end

  if vim.api.nvim_buf_get_name(buf) ~= "" or vim.bo[buf].buftype ~= "" or vim.bo[buf].modified then
    return false
  end

  return vim.api.nvim_buf_line_count(buf) == 1 and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

local function cleanup_empty_unnamed_buffers()
  vim.schedule(function()
    local current = vim.api.nvim_get_current_buf()

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if is_empty_unnamed_buffer(buf) then
        if buf == current then
          vim.bo[buf].buflisted = false
        else
          pcall(vim.api.nvim_buf_delete, buf, {})
        end
      end
    end
  end)
end

vim.api.nvim_create_autocmd({ "BufAdd", "BufEnter", "VimEnter" }, {
  callback = cleanup_empty_unnamed_buffers,
})

cleanup_empty_unnamed_buffers()
