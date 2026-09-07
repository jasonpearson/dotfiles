return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      opts.filesystem = opts.filesystem or {}
      opts.filesystem.filtered_items = vim.tbl_deep_extend("force", opts.filesystem.filtered_items or {}, {
        visible = true,
        hide_dotfiles = false,
      })

      opts.filesystem.window = opts.filesystem.window or {}
      opts.filesystem.window.mappings = vim.tbl_deep_extend("force", opts.filesystem.window.mappings or {}, {
        ["l"] = {
          function(state)
            local fs_commands = require("neo-tree.sources.filesystem.commands")
            local common_commands = require("neo-tree.sources.common.commands")

            fs_commands.open(state)

            local node = state.tree:get_node()
            if node and node.type == "file" then
              common_commands.close_window(state)
            end
          end,
          desc = "Open file and close explorer",
        },
      })
    end,
  },
}
