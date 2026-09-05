local theme = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")

if vim.fn.filereadable(theme) == 1 then
  return dofile(theme)
end

return {}
