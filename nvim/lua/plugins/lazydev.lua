-- Load Neovim plugin types on demand for lua_ls.
return {
  "folke/lazydev.nvim",
  ft = "lua",
  opts = {
    library = {
      -- vim.uv types come from the luv library.
      { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      -- Load Snacks types when its global is used without require().
      { path = "snacks.nvim", words = { "Snacks" } },
    },
  },
}
