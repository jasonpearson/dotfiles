local M = {}
local uv = vim.uv or vim.loop
local theme_dir = vim.fn.expand("~/.local/state/omarchy/current/theme")

-- Manual selector for machines without Omarchy. Match Ghostty and Bash there.
local fallback_colorscheme = "catppuccin-mocha"
local fallback = { plugins = {}, colorscheme = fallback_colorscheme, mode = "dark" }
local current, applied, pending, rejected, timer
local busy = false
local names = {}

local transparent_groups = {
  "Normal", "NormalFloat", "FloatBorder", "Pmenu", "Terminal", "EndOfBuffer",
  "FoldColumn", "Folded", "SignColumn", "LineNr", "CursorLineNr", "NormalNC",
  "WhichKeyFloat", "TelescopeBorder", "TelescopeNormal", "TelescopePromptBorder",
  "TelescopePromptTitle", "NeoTreeNormal", "NeoTreeNormalNC", "NeoTreeVertSplit",
  "NeoTreeWinSeparator", "NeoTreeEndOfBuffer", "NvimTreeNormal", "NvimTreeVertSplit",
  "NvimTreeEndOfBuffer", "NotifyINFOBody", "NotifyERRORBody", "NotifyWARNBody",
  "NotifyTRACEBody", "NotifyDEBUGBody", "NotifyINFOTitle", "NotifyERRORTitle",
  "NotifyWARNTitle", "NotifyTRACETitle", "NotifyDEBUGTitle", "NotifyINFOBorder",
  "NotifyERRORBorder", "NotifyWARNBorder", "NotifyTRACEBorder", "NotifyDEBUGBorder",
}

local function apply_transparency()
  for _, name in ipairs(transparent_groups) do
    -- Do not sever links or clear groups the colorscheme never defined.
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, create = false })
    if ok and not hl.link and hl.bg ~= nil then
      hl.bg = nil
      vim.api.nvim_set_hl(0, name, hl)
    end
  end
end

local function notify_error(err)
  vim.notify(tostring(err), vim.log.levels.ERROR, { title = "Omarchy theme" })
end

local function read_file(path)
  local file = io.open(path, "rb")
  if not file then
    return nil
  end
  local contents = file:read("*a")
  file:close()
  return contents
end

local function snapshot()
  local source = read_file(theme_dir .. "/neovim.lua")
  if not source then
    return nil
  end
  local colors = read_file(theme_dir .. "/colors.toml") or ""
  local light = uv.fs_stat(theme_dir .. "/light") ~= nil
  return {
    source = source,
    colors = colors,
    light = light,
    -- Content, not mtime or colorscheme name: aether palettes reuse a name,
    -- and directory replacements can preserve timestamps.
    key = source .. "\0" .. colors .. "\0" .. tostring(light),
  }
end

local function parse(raw)
  local chunk, err = loadstring(raw.source, "@" .. theme_dir .. "/neovim.lua")
  assert(chunk, err)
  local generated = chunk()
  assert(type(generated) == "table", "Expected a list of theme specs")
  local selected = { plugins = {}, key = raw.key }

  local function filter(spec)
    spec = type(spec) == "string" and { spec } or vim.deepcopy(spec)
    assert(type(spec) == "table" and type(spec[1]) == "string", "Invalid theme plugin spec")
    if spec[1] == "LazyVim/LazyVim" then
      if type(spec.opts) == "table" and spec.opts.colorscheme then
        selected.colorscheme = spec.opts.colorscheme
      end
      return nil -- This is metadata, never an invitation to load the distro.
    end
    assert(not spec.import and not spec.specs, "Theme imports are not supported")
    spec.name = spec.name or names[spec[1]] or require("lazy.core.plugin").Spec.get_name(spec[1])
    spec.lazy = true -- The controller orders setup before applying the scheme.
    if spec.dependencies then
      local dependencies = {}
      for _, dependency in ipairs(spec.dependencies) do
        local filtered = filter(dependency)
        if filtered then
          dependencies[#dependencies + 1] = filtered
        end
      end
      spec.dependencies = dependencies
    end
    return spec
  end

  for _, spec in ipairs(generated) do
    local filtered = filter(spec)
    if filtered then
      selected.plugins[#selected.plugins + 1] = filtered
    end
  end
  assert(type(selected.colorscheme) == "string" and selected.colorscheme:match("^[%w_.%-]+$"),
    "Missing or invalid Omarchy colorscheme selector")
  assert(#selected.plugins > 0, "Missing Omarchy theme plugin")
  for line in raw.colors:gmatch("[^\r\n]+") do
    local mode = line:match("^%s*mode%s*=%s*[\"']([%a]+)[\"']")
    if mode then
      assert(mode == "light" or mode == "dark", "Invalid Omarchy theme mode")
      selected.mode = mode
      break
    end
  end
  -- Older themes use a `light` marker, with dark as the implicit default.
  selected.mode = selected.mode or (raw.light and "light" or "dark")
  return selected
end

-- aether v3 has an unconditional watcher setup (no disable option). We own
-- Omarchy reloads for ALL themes, so suppress that hook before setup/load can
-- register handles or emit extra ColorScheme/LazyReload events. Do not patch
-- files or global libuv functions. Reinstall the hook after module unloading.
local function configure_aether(plugin, opts, config)
  local ok, hotreload = pcall(require, "aether.hotreload")
  if ok then
    hotreload.setup = function() end
  end
  if type(config) == "function" then
    config(plugin, opts)
  else
    require("aether").setup(opts)
  end
end

-- Called on every lazy spec rebuild. The staged snapshot is the only source;
-- do not reread a half-written generated file while lazy is rebuilding.
function M.specs(inventory)
  for _, spec in ipairs(inventory) do
    names[spec[1]] = spec.name or require("lazy.core.plugin").Spec.get_name(spec[1])
  end
  if not current then
    local raw = snapshot()
    local ok, selected = pcall(parse, raw or {})
    current = ok and selected or fallback
    if raw and not ok then
      rejected = raw.key
      notify_error(selected)
    end
  end
  vim.list_extend(inventory, vim.deepcopy(current.plugins))
  -- This final fragment also covers native themes that depend on aether.
  local aether_config
  local function find_aether(specs)
    for _, spec in ipairs(specs) do
      if spec.name == "aether" then
        aether_config = spec.config
      end
      find_aether(spec.dependencies or {})
    end
  end
  find_aether(current.plugins)
  inventory[#inventory + 1] = {
    "bjarneo/aether.nvim",
    name = "aether",
    branch = "v3",
    opts = {},
    config = function(plugin, opts)
      configure_aether(plugin, opts, aether_config)
    end,
  }
  inventory[#inventory + 1] = {
    name = "theme-hotreload",
    dir = vim.fn.stdpath("config"),
    lazy = false,
    priority = 10000,
    config = M.setup,
  }
  return inventory
end

local function apply(selected, on_start)
  local config = require("lazy.core.config")
  local loader = require("lazy.core.loader")
  local plugins, seen = {}, {}
  local function visit(name)
    if seen[name] then
      return
    end
    seen[name] = true
    local plugin = assert(config.plugins[name], "Unknown theme plugin: " .. name)
    assert(plugin._.installed, "Theme plugin is not installed: " .. name)
    for _, dependency in ipairs(plugin.dependencies or {}) do
      visit(dependency)
    end
    plugins[#plugins + 1] = plugin
  end
  for _, spec in ipairs(selected.plugins) do
    visit(spec.name)
  end
  -- Also locate the owning plugin for the portable fallback.
  local scheme = "colors/" .. selected.colorscheme
  local available = #vim.api.nvim_get_runtime_file(scheme .. ".lua", false) > 0
    or #vim.api.nvim_get_runtime_file(scheme .. ".vim", false) > 0
  for name, plugin in pairs(config.plugins) do
    if uv.fs_stat(plugin.dir .. "/" .. scheme .. ".lua") or uv.fs_stat(plugin.dir .. "/" .. scheme .. ".vim") then
      visit(name)
      available = true
      break
    end
  end
  assert(available, "Colorscheme is not installed: " .. selected.colorscheme)
  if on_start then
    on_start()
  end

  -- Changing 'background' with colors_name set automatically reapplies the OLD
  -- theme. Suppress that extra load/event; apply the new scheme just once below.
  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end
  vim.g.colors_name = nil
  vim.o.background = selected.mode
  for _, plugin in ipairs(plugins) do
    -- Equivalent to lazy's reload, but don't re-source previously loaded
    -- colors/*.vim scripts (loader.reload does, causing duplicate applies).
    -- The freshly rebuilt spec must be in place BEFORE clearing cached opts.
    loader.deactivate(plugin)
    plugin._.cache = nil
    if loader.init_done and plugin.init then
      plugin.init(plugin)
    end
    -- Run config with lazy's resolved opts, but let errors reach our rollback
    -- rather than lazy's notification-only error handler.
    local configure = plugin.config
    local has_config = configure or plugin.opts
    local opts = has_config and require("lazy.core.plugin").values(plugin, "opts", false)
    plugin.config = function() end
    loader.load(plugin, { start = "theme" })
    plugin.config = configure
    if has_config then
      if type(configure) == "function" then
        configure(plugin, opts)
      else
        local main = assert(loader.get_main(plugin), "No setup module for " .. plugin.name)
        require(main).setup(opts)
      end
    end
  end
  if vim.g.colors_name ~= selected.colorscheme then
    vim.cmd.colorscheme(selected.colorscheme)
  end
  apply_transparency()
  vim.cmd.redraw()
end

local function activate(selected, rebuild)
  local previous = applied
  current = selected
  local changed = false
  local ok, err = pcall(function()
    if rebuild then
      require("lazy.core.plugin").load()
    end
    apply(selected, function() changed = true end)
  end)
  if ok then
    applied = selected
    return true
  end
  -- Missing/broken new plugins should not replace an already-working theme.
  current = previous or fallback
  local restored, restore_err = pcall(function()
    require("lazy.core.plugin").load()
    if changed or not previous then
      apply(current)
    end
  end)
  if restored then
    applied = current
  else
    notify_error(restore_err)
  end
  notify_error(err)
  return false
end

function M.poll()
  if busy then
    return
  end
  local raw = snapshot()
  if not raw then
    pending = nil -- rm/mv window: never switch to the portable fallback here.
    return
  end
  if (applied and raw.key == applied.key) or raw.key == rejected then
    pending = nil
    return
  end
  -- Two identical samples debounce bursty writes and mixed directory snapshots.
  if not pending or pending.key ~= raw.key then
    pending = raw
    return
  end
  pending = nil
  local ok, selected = pcall(parse, raw)
  if not ok then
    rejected = raw.key
    notify_error(selected)
    return
  end
  busy = true
  if not activate(selected, true) then
    rejected = raw.key
  else
    rejected = nil
  end
  busy = false
end

function M.stop()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end

function M.setup()
  M.stop()
  local group = vim.api.nvim_create_augroup("OmarchyTheme", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = apply_transparency })
  vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = M.stop })
  if not applied then
    activate(current or fallback, false)
  end
  -- Poll the pathname, not a replaceable inode. This works even if Omarchy is
  -- installed after startup, and survives any number of rm/mv theme swaps.
  timer = assert(uv.new_timer())
  local handle = timer
  timer:start(500, 500, vim.schedule_wrap(function()
    if timer == handle then
      M.poll()
    end
  end))
end

return M
