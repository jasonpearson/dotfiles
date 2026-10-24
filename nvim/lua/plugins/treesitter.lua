return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local treesitter = require("nvim-treesitter")
    treesitter.setup()

    local function attach(buf)
      if not vim.api.nvim_buf_is_loaded(buf) then
        return
      end
      local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
      if not lang or not pcall(vim.treesitter.start, buf, lang) then
        return -- Parsers may still be installing on first startup.
      end
      if vim.treesitter.query.get(lang, "indents") then
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end

    local function attach_loaded_buffers()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        attach(buf)
      end
    end

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("TreesitterFeatures", { clear = true }),
      callback = function(ev)
        attach(ev.buf)
      end,
    })
    attach_loaded_buffers()

    treesitter.install({
      "c", "elixir", "heex", "html", "javascript", "lua", "markdown",
      "markdown_inline", "query", "typescript", "tsx", "vim", "vimdoc", "yaml",
    }):await(vim.schedule_wrap(function(err)
      if err then
        vim.notify(tostring(err), vim.log.levels.ERROR, { title = "Treesitter installation" })
      end
      attach_loaded_buffers()
    end))
  end,
}
