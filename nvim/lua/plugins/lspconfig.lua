-- Neovim loads server definitions from nvim-lspconfig's lsp/ files.
-- blink.cmp registers completion capabilities; mise installs the servers.
return {
  "neovim/nvim-lspconfig",
  dependencies = { "saghen/blink.cmp" },
  config = function()
    -- Locate mise's TypeScript outside the workspace's node_modules.
    local function mise_typescript_lib()
      local bin = vim.fn.exepath("tsserver")
      if bin == "" then
        return nil
      end
      -- .../node_modules/.bin/tsserver -> .../node_modules/typescript/lib
      local lib = vim.fs.joinpath(vim.fs.dirname(vim.fs.dirname(bin)), "typescript", "lib")
      return vim.uv.fs_stat(vim.fs.joinpath(lib, "tsserver.js")) and lib or nil
    end

    -- lazydev.nvim configures lua_ls with Neovim and plugin types.

    vim.lsp.config("ts_ls", {
      before_init = function(params, config)
        -- Prefer the project's TypeScript version; use mise's as a fallback.
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

        -- Avoid the timeout caused by the `gr` mapping in snacks.lua.
        map("<leader>cr", vim.lsp.buf.rename, "Rename")
        map("<leader>ca", vim.lsp.buf.code_action, "Code Action")
      end,
    })
  end,
}
