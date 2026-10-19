-- nvim 0.12 resolves server configs from `lsp/<name>.lua` on the runtimepath;
-- nvim-lspconfig is here only to supply those files, so nothing calls into its
-- `lspconfig` module. blink.cmp registers completion capabilities on
-- `vim.lsp.config("*")` from its own `plugin/` file, so listing it as a
-- dependency is all the wiring completion needs.
--
-- The servers themselves are installed by mise, see mise/config.toml.
return {
  "neovim/nvim-lspconfig",
  dependencies = { "saghen/blink.cmp" },
  config = function()
    -- typescript-language-server locates tsserver.js by walking the workspace's
    -- node_modules; mise installs TypeScript into its own prefix, which that
    -- walk never reaches. Derive the lib directory from the `tsserver` shim
    -- mise puts on PATH.
    local function mise_typescript_lib()
      local bin = vim.fn.exepath("tsserver")
      if bin == "" then
        return nil
      end
      -- .../node_modules/.bin/tsserver -> .../node_modules/typescript/lib
      local lib = vim.fs.joinpath(vim.fs.dirname(vim.fs.dirname(bin)), "typescript", "lib")
      return vim.uv.fs_stat(vim.fs.joinpath(lib, "tsserver.js")) and lib or nil
    end

    -- lua_ls needs no block here: lazydev.nvim owns its settings, setting
    -- runtime.version and feeding workspace.library the nvim runtime plus each
    -- plugin's sources as they are referenced. See plugins/lazydev.lua.

    vim.lsp.config("ts_ls", {
      before_init = function(params, config)
        -- An explicit tsserver.path wins over the server's own workspace
        -- lookup, so only fill it in when the project ships no TypeScript of
        -- its own -- otherwise a project pinned to a different version would
        -- silently be served by mise's copy.
        local root = config.root_dir
        if root and vim.uv.fs_stat(vim.fs.joinpath(root, "node_modules", "typescript", "lib", "tsserver.js")) then
          return
        end

        local lib = mise_typescript_lib()
        if not lib then
          return
        end

        params.initializationOptions = vim.tbl_deep_extend(
          "force",
          params.initializationOptions or {},
          { tsserver = { path = lib } }
        )
      end,
    })

    vim.lsp.enable({
      "lua_ls",
      "ts_ls",
    })

    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("LspKeymaps", { clear = true }),
      callback = function(ev)
        local function map(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc })
        end

        -- Aliases for nvim's built-in `grn`/`gra`, which are reachable but
        -- cost a `timeoutlen` wait: `gr` in snacks.lua is a complete match on
        -- the way to them.
        map("<leader>cr", vim.lsp.buf.rename, "Rename")
        map("<leader>ca", vim.lsp.buf.code_action, "Code Action")
      end,
    })
  end,
}
