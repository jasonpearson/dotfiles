return {
  {
    "lewis6991/gitsigns.nvim",
    opts = function(_, opts)
      local original_on_attach = opts.on_attach
      opts.on_attach = function(buffer)
        if original_on_attach then
          original_on_attach(buffer)
        end

        local gs = package.loaded.gitsigns

        local function map_hunk(lhs, dir, fallback)
          vim.keymap.set("n", lhs, function()
            if vim.wo.diff then
              vim.cmd.normal({ fallback, bang = true })
              return
            end

            if gs and gs.nav_hunk then
              gs.nav_hunk(dir)
            end
          end, {
            buffer = buffer,
            desc = dir == "next" and "Next Hunk" or "Prev Hunk",
            silent = true,
          })
        end

        map_hunk("]c", "next", "]c")
        map_hunk("[c", "prev", "[c")
      end
    end,
  },
}
