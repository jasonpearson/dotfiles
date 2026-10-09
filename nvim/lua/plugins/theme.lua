-- Keep an explicit offline-ready inventory: Omarchy 4 ships both native theme
-- specs and generated aether palettes. Only the selected theme is loaded.
local specs = {
  { "ribru17/bamboo.nvim", lazy = true, priority = 1000 },
  -- Match the generated spec exactly, including its installation directory.
  { "bjarneo/aether.nvim", name = "aether", branch = "v3", lazy = true, priority = 1000 },
  { "bjarneo/ethereal.nvim", lazy = true, priority = 1000 },
  { "bjarneo/hackerman.nvim", lazy = true, priority = 1000 },
  { "bjarneo/vantablack.nvim", lazy = true, priority = 1000 },
  { "bjarneo/white.nvim", lazy = true, priority = 1000 },
  { "catppuccin/nvim", name = "catppuccin", lazy = true, priority = 1000 },
  { "neanias/everforest-nvim", lazy = true, priority = 1000 },
  { "kepano/flexoki-neovim", lazy = true, priority = 1000 },
  { "ellisonleao/gruvbox.nvim", lazy = true, priority = 1000 },
  { "rebelot/kanagawa.nvim", lazy = true, priority = 1000 },
  { "tahayvr/matteblack.nvim", lazy = true, priority = 1000 },
  { "EdenEast/nightfox.nvim", lazy = true, priority = 1000 },
  { "rose-pine/neovim", name = "rose-pine", lazy = true, priority = 1000 },
  { "ficcdaf/ashen.nvim", lazy = true, priority = 1000 },
  { "folke/tokyonight.nvim", lazy = true, priority = 1000 },
  { "OldJobobo/miasma.nvim", lazy = true, priority = 1000 },
  { "OldJobobo/retro-82.nvim", lazy = true, priority = 1000 },
  { "omacom-io/lumon.nvim", lazy = true, priority = 1000 },
}

return require("config.theme").specs(specs)
