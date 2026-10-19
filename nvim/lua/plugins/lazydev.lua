-- Teaches lua_ls about plugin sources under ~/.local/share/nvim/lazy, so
-- runtime globals like `Snacks` resolve with their annotations instead of
-- reading as undefined. Loads each plugin's types on demand rather than
-- putting all of them in workspace.library, which is slow and known to
-- misbehave when the workspace is your own nvim config.
return {
  "folke/lazydev.nvim",
  ft = "lua",
  opts = {
    library = {
      -- vim.uv is a separate stub that does not ship with the nvim runtime
      { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      -- lazydev pulls a plugin in when it sees `require("mod")`, which never
      -- happens for a plugin that installs a global instead. Map the global
      -- back to the plugin so its annotations get loaded.
      { path = "snacks.nvim", words = { "Snacks" } },
    },
  },
}
