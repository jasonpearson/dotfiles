local transparent_groups = {
  "Normal",
  "NormalFloat",
  "FloatBorder",
  "Pmenu",
  "Terminal",
  "EndOfBuffer",
  "FoldColumn",
  "Folded",
  "SignColumn",
  "LineNr",
  "CursorLineNr",
  "NormalNC",
  "WhichKeyFloat",
  "TelescopeBorder",
  "TelescopeNormal",
  "TelescopePromptBorder",
  "TelescopePromptTitle",
  "NeoTreeNormal",
  "NeoTreeNormalNC",
  "NeoTreeVertSplit",
  "NeoTreeWinSeparator",
  "NeoTreeEndOfBuffer",
  "NvimTreeNormal",
  "NvimTreeVertSplit",
  "NvimTreeEndOfBuffer",
  "NotifyINFOBody",
  "NotifyERRORBody",
  "NotifyWARNBody",
  "NotifyTRACEBody",
  "NotifyDEBUGBody",
  "NotifyINFOTitle",
  "NotifyERRORTitle",
  "NotifyWARNTitle",
  "NotifyTRACETitle",
  "NotifyDEBUGTitle",
  "NotifyINFOBorder",
  "NotifyERRORBorder",
  "NotifyWARNBorder",
  "NotifyTRACEBorder",
  "NotifyDEBUGBorder",
}

local function apply_transparency()
  for _, name in ipairs(transparent_groups) do
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    if ok then
      hl.bg = nil
      vim.api.nvim_set_hl(0, name, hl)
    end
  end
end

local specs = {
  -- Load all theme plugins but don't apply them. This ensures all colorschemes
  -- are available for Omarchy theme hot-reloading.
  --
  -- Omarchy 4 generates most theme specs from default/themed/neovim.lua.tpl on
  -- top of aether, so the single-theme plugins below (ethereal, vantablack,
  -- white, monokai-pro, miasma) are only reached by Omarchy 3.8, which ships a
  -- neovim.lua per theme. Keep them until 3.8 is out of support.
  {
    "ribru17/bamboo.nvim",
    lazy = true,
    priority = 1000,
  },
  -- Name and branch must match Omarchy 4's generated theme spec
  -- (default/themed/neovim.lua.tpl). lazy merges specs by url and lets an
  -- explicit name rename the merged plugin, so a bare "bjarneo/aether.nvim"
  -- here builds the cache into lazy/aether.nvim while every aether-themed
  -- Omarchy 4 install renames it to lazy/aether at runtime -- a directory the
  -- package never shipped. That cost a network clone on first launch, and the
  -- theme fell back to tokyonight until nvim was restarted.
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    lazy = true,
    priority = 1000,
  },
  {
    "bjarneo/ethereal.nvim",
    lazy = true,
    priority = 1000,
  },
  {
    "bjarneo/hackerman.nvim",
    lazy = true,
    priority = 1000,
  },
  {
    "bjarneo/vantablack.nvim",
    lazy = true,
    priority = 1000,
  },
  {
    "bjarneo/white.nvim",
    lazy = true,
    priority = 1000,
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    priority = 1000,
  },
  {
    "neanias/everforest-nvim",
    lazy = true,
    priority = 1000,
  },
  {
    "kepano/flexoki-neovim",
    lazy = true,
    priority = 1000,
  },
  {
    "ellisonleao/gruvbox.nvim",
    lazy = true,
    priority = 1000,
  },
  {
    "rebelot/kanagawa.nvim",
    lazy = true,
    priority = 1000,
  },
  {
    "tahayvr/matteblack.nvim",
    lazy = true,
    priority = 1000,
  },
  {
    "gthelding/monokai-pro.nvim",
    lazy = true,
    priority = 1000,
  },
  {
    "EdenEast/nightfox.nvim",
    lazy = true,
    priority = 1000,
  },
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = true,
    priority = 1000,
  },
  {
    "ficcdaf/ashen.nvim",
    lazy = true,
    priority = 1000,
  },
  {
    "folke/tokyonight.nvim",
    lazy = true,
    priority = 1000,
  },
  {
    "OldJobobo/miasma.nvim",
    lazy = true,
    priority = 1000,
  },
  {
    "OldJobobo/retro-82.nvim",
    lazy = true,
    priority = 1000,
  },
  {
    "omacom-io/lumon.nvim",
    lazy = true,
    priority = 1000,
  },
}

local current_theme = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")

local function notify_error(message)
  vim.notify(message, vim.log.levels.ERROR, { title = "Theme hot reload" })
end

local function load_current_theme_spec()
  if vim.fn.filereadable(current_theme) ~= 1 then
    return {}
  end

  local ok, theme_spec = pcall(dofile, current_theme)
  if not ok then
    notify_error("Failed to load current Omarchy theme: " .. theme_spec)
    return {}
  end

  return type(theme_spec) == "table" and theme_spec or {}
end

local function find_theme(theme_spec)
  local theme_plugin_name
  local colorscheme

  for _, spec in ipairs(theme_spec) do
    if type(spec) == "table" then
      if spec[1] == "LazyVim/LazyVim" and spec.opts and spec.opts.colorscheme then
        colorscheme = spec.opts.colorscheme
      elseif spec[1] and spec[1] ~= "LazyVim/LazyVim" and not theme_plugin_name then
        theme_plugin_name = spec.name or spec[1]
      end
    end
  end

  return theme_plugin_name, colorscheme
end

local function unload_plugin_modules(plugin_name)
  if not plugin_name then
    return
  end

  local plugin = require("lazy.core.config").plugins[plugin_name]
  if not plugin or not plugin.dir then
    return
  end

  require("lazy.core.util").walkmods(plugin.dir .. "/lua", function(modname)
    package.loaded[modname] = nil
    package.preload[modname] = nil
  end)
end

local function load_colorscheme(plugin_name, colorscheme)
  if not colorscheme then
    local lazyvim = rawget(_G, "LazyVim")
    local configured = lazyvim and lazyvim.config and lazyvim.config.colorscheme

    if type(configured) == "function" then
      local ok, err = pcall(configured)
      if not ok then
        notify_error("Failed to apply configured colorscheme: " .. err)
      end
      return
    elseif type(configured) == "string" then
      colorscheme = configured
    else
      return
    end
  end

  local plugin = plugin_name and require("lazy.core.config").plugins[plugin_name]
  if plugin and plugin._ and plugin._.loaded then
    require("lazy.core.loader").reload(plugin)
  else
    require("lazy.core.loader").colorscheme(colorscheme)
  end

  vim.defer_fn(function()
    local ok, err = pcall(vim.cmd.colorscheme, colorscheme)
    if not ok then
      notify_error("Failed to apply colorscheme " .. colorscheme .. ": " .. err)
      return
    end

    vim.cmd("redraw!")

    vim.defer_fn(function()
      apply_transparency()

      -- Trigger UI updates for plugins that cache colors.
      vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
      vim.api.nvim_exec_autocmds("VimEnter", { modeline = false })

      vim.cmd("redraw!")
    end, 5)
  end, 5)
end

vim.list_extend(specs, load_current_theme_spec())

specs[#specs + 1] = {
  name = "theme-hotreload",
  dir = vim.fn.stdpath("config"),
  lazy = false,
  priority = 1000,
  config = function()
    local group = vim.api.nvim_create_augroup("Theme", { clear = true })

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = group,
      callback = apply_transparency,
    })

    apply_transparency()

    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "LazyReload",
      callback = function()
        vim.schedule(function()
          local theme_plugin_name, colorscheme = find_theme(load_current_theme_spec())

          vim.cmd("highlight clear")
          if vim.fn.exists("syntax_on") then
            vim.cmd("syntax reset")
          end

          -- Default to dark; light colorschemes can set this back to light.
          vim.o.background = "dark"

          unload_plugin_modules(theme_plugin_name)
          load_colorscheme(theme_plugin_name, colorscheme)
        end)
      end,
    })
  end,
}

return specs
