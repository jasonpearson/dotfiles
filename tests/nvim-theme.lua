-- Invoked only by nvim-theme.sh, with HOME and every XDG path isolated.
local repo = assert(vim.env.NVIM_THEME_REPO)
local real = vim.env.NVIM_THEME_INTEGRATION == "1"
local scenario = vim.env.NVIM_THEME_SCENARIO
local root = vim.env.HOME .. "/fixtures"
local theme_dir = vim.env.HOME .. "/.local/state/omarchy/current/theme"
local errors, schemes, entered = {}, 0, 0
vim.notify = function(message, level)
  if level == vim.log.levels.ERROR then
    errors[#errors + 1] = tostring(message)
  end
end
vim.api.nvim_create_autocmd("ColorScheme", { callback = function() schemes = schemes + 1 end })
vim.api.nvim_create_autocmd("VimEnter", { callback = function() entered = entered + 1 end })

local function eq(actual, expected, label)
  assert(vim.deep_equal(actual, expected), (label or "value") .. ": expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
end
local function write(path, contents)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local file = assert(io.open(path, "wb"))
  file:write(contents)
  file:close()
end
local function generate(name, opts, extra)
  local repos = {
    aether = '"bjarneo/aether.nvim", name = "aether", branch = "v3"',
    ethereal = '"bjarneo/ethereal.nvim"',
    catppuccin = '"catppuccin/nvim", name = "catppuccin"',
    nightfox = '"EdenEast/nightfox.nvim"',
  }
  local scheme = name == "nightfox" and "nordfox" or name
  return ("return {{ %s, opts = %s %s }, { 'LazyVim/LazyVim', opts = { colorscheme = %q } }}")
    :format(repos[name], opts or "{}", extra or "", scheme)
end
local function replace(source, mode, marker, name)
  -- Match Omarchy's rm(current/theme) + mv(next-theme, current/theme).
  local next_dir = theme_dir .. "-next"
  vim.fn.delete(next_dir, "rf")
  write(next_dir .. "/neovim.lua", source)
  if mode then
    write(next_dir .. "/colors.toml", 'mode = "' .. mode .. '"\n')
  end
  if marker then
    write(next_dir .. "/light.mode", "")
  end
  vim.fn.delete(theme_dir, "rf")
  assert(vim.uv.fs_rename(next_dir, theme_dir))
  if name then
    write(theme_dir .. ".name", name .. "\n")
  else
    vim.fn.delete(theme_dir .. ".name")
  end
end
local function settle()
  -- Exercise the actual timer; no LazyReload notification is sent by the writer.
  vim.wait(1250, function() return false end, 25)
end
local function changed(source, mode, expected, marker, name)
  local before = schemes
  replace(source, mode, marker, name)
  assert(vim.wait(2500, function() return schemes > before end, 25), "theme did not refresh")
  eq(vim.g.colors_name, expected, "selected colorscheme")
  eq(schemes, before + 1, "one ColorScheme per accepted snapshot")
end

vim.opt.rtp:prepend(repo .. "/nvim")
vim.opt.rtp:prepend(vim.env.NVIM_THEME_LAZY)
if scenario == "ethereal" then
  replace(generate("aether", '{colors = {fg = "#112233", bg = "#101010"}}'), "dark", nil, "ethereal")
elseif scenario == "runtime" then
  replace(generate("aether", '{ colors = { fg = "#112233", bg = "#101010" } }'), "dark")
elseif scenario == "native" then
  replace(generate("catppuccin", '{flavour = "latte"}'), "light")
elseif scenario == "invalid" then
  replace("return {", "dark")
end

-- Import the real repository inventory, while giving every plugin a local
-- directory. No install/check/build task is allowed, even for optional themes.
local inventory = dofile(repo .. "/nvim/lua/plugins/theme.lua")
local overrides = {}
for _, spec in ipairs(inventory) do
  if spec[1] then
    local name = spec.name or require("lazy.core.plugin").Spec.get_name(spec[1])
    local path = real and (vim.env.NVIM_THEME_PLUGIN_ROOT .. "/" .. name) or (root .. "/" .. name)
    if not real then
      vim.fn.mkdir(path, "p")
    end
    overrides[#overrides + 1] = { spec[1], name = name, dir = path }
  end
end

if not real then
  -- Fake plugins deliberately cache setup opts, just like actual theme plugins.
  -- aether uses a Vimscript colors entry to detect reload's double-source trap.
  local function fixture(name, main, defaults, colors)
    write(root .. "/" .. name .. "/lua/" .. main .. "/init.lua", ([[
local M = { opts = %s }
function M.setup(opts)
  M.opts = opts
  vim.g.fixture_setups = (vim.g.fixture_setups or 0) + 1
end
function M.load(name)
  vim.cmd('highlight clear')
  vim.g.colors_name = name
  local fg = (M.opts.colors or {}).fg or '#cdd6f4'
  vim.api.nvim_set_hl(0, 'Normal', { fg = fg, bg = '#1e1e2e' })
  vim.api.nvim_set_hl(0, 'ThemeFixture', { fg = fg, bg = '#123456', bold = true })
  vim.api.nvim_set_hl(0, 'FloatBorder', { link = 'ThemeFixture' })
end
return M
]]):format(defaults))
    for scheme, code in pairs(colors) do
      write(root .. "/" .. name .. "/colors/" .. scheme, code)
    end
  end
  fixture("aether", "aether", "{}", {
    ["aether.vim"] = [[lua require('aether').load('aether')]],
  })
  write(root .. "/aether/lua/aether/hotreload.lua", [[
return { setup = function() error('Competing aether watcher must not start') end }
]])
  -- Both setup() and load() try to register aether's competing watcher.
  local aether = assert(io.open(root .. "/aether/lua/aether/init.lua", "rb"))
  local code = aether:read("*a")
  aether:close()
  code = code:gsub("function M.setup%(opts%)", "function M.setup(opts)\n  require('aether.hotreload').setup()")
  code = code:gsub("function M.load%(name%)", "function M.load(name)\n  require('aether.hotreload').setup()")
  write(root .. "/aether/lua/aether/init.lua", code)
  fixture("catppuccin", "catppuccin", "{}", {
    ["catppuccin.lua"] = [[local c = require('catppuccin'); c.load('catppuccin-' .. (c.opts.flavour or 'mocha'))]],
    ["catppuccin-mocha.lua"] = [[require('catppuccin').load('catppuccin-mocha')]],
    ["catppuccin-latte.lua"] = [[require('catppuccin').load('catppuccin-latte')]],
  })
  fixture("nightfox.nvim", "nightfox", "{}", {
    ["nordfox.lua"] = [[require('nightfox').load('nordfox')]],
  })
  fixture("ethereal.nvim", "ethereal", "{}", {
    ["ethereal.vim"] = [[lua require('ethereal').load('ethereal')]],
  })
end

require("lazy").setup({
  spec = { { import = "plugins.theme" }, overrides },
  root = vim.env.HOME .. "/data/lazy",
  lockfile = vim.env.HOME .. "/lazy-lock.json",
  install = { missing = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
  local_spec = false,
  pkg = { enabled = false },
  rocks = { enabled = false },
  performance = { rtp = { reset = true, paths = { repo .. "/nvim" } } },
})

local function checks()
  local controller = require("config.theme")
  local plugins = require("lazy.core.config").plugins
  eq(plugins.LazyVim, nil, "LazyVim not registered")
  eq(package.loaded.lazyvim, nil, "LazyVim not loaded")
  eq(plugins.aether.branch, "v3", "aether branch")
  eq(plugins.aether.name, "aether", "aether install name")
  eq(entered, 1, "natural VimEnter")
  eq(schemes, 1, "explicit startup colorscheme")
  if scenario == "ethereal" then
    eq(vim.g.colors_name, "ethereal", "Omarchy Ethereal uses native colorscheme at startup")
    eq(plugins.aether._.loaded, nil, "generated Aether plugin is not loaded for Ethereal")
    local function highlights()
      local result = {}
      for _, name in ipairs({ "Normal", "Identifier", "@property", "String" }) do
        result[name] = vim.api.nvim_get_hl(0, { name = name, link = false, create = false })
      end
      return result
    end
    local native = highlights()
    assert(native.Normal.fg ~= 0x112233, "generated Aether options must not leak into native Ethereal")
    local source = generate("aether", '{colors = {fg = "#112233", bg = "#101010"}}')
    eq(table.concat(vim.fn.readfile(theme_dir .. "/neovim.lua"), "\n"), source, "generated state is unchanged")
    vim.cmd.colorscheme("ethereal")
    eq(highlights(), native, "automatic and manual Ethereal highlights match")

    -- A different theme with the exact same generated palette must stay Aether.
    -- This also exercises lazy module unloading when returning to native Ethereal.
    for _ = 1, 2 do
      changed(source, "dark", "aether", nil, "another-theme")
      eq(vim.api.nvim_get_hl(0, { name = "Normal", link = false }).fg, 0x112233)
      changed(source, "dark", "ethereal", nil, "ethereal")
      eq(highlights(), native, "native highlights survive switching away and back")
    end
    local before = schemes
    settle()
    eq(schemes, before, "unchanged Ethereal selection is not reloaded")

    -- Omarchy writes theme.name separately, after swapping the generated files.
    -- A name-only change (or missing name) must invalidate the snapshot too.
    vim.fn.delete(theme_dir .. ".name")
    controller.poll()
    controller.poll()
    eq(vim.g.colors_name, "aether", "missing theme name preserves generated selection")
    write(theme_dir .. ".name", "ethereal\n")
    controller.poll()
    controller.poll()
    eq(vim.g.colors_name, "ethereal", "name-only update selects native Ethereal")
    eq(highlights(), native, "name-only update restores native highlights")
    eq(schemes, before + 2, "one event per name-only update")

    -- Do not override explicit native/custom specs supplied by the user.
    changed(generate("catppuccin", '{flavour = "latte"}'), "light", "catppuccin-latte", nil, "ethereal")
    changed(generate("ethereal", '{colors = {fg = "#abcdef"}}'), "dark", "ethereal", nil, "ethereal")
    eq(vim.api.nvim_get_hl(0, { name = "Normal", link = false }).fg, 0xabcdef, "explicit native options preserved")
    changed(source, "dark", "ethereal", nil, "ethereal")
    eq(highlights(), native, "generated-to-native preference resets old native options")
    eq(errors, {}, "Ethereal startup and runtime errors")
    print(("PASS nvim-theme ethereal (%s)"):format(real and "installed plugins" or "fixtures"))
    return
  end
  if scenario == "native" or scenario == "invalid" then
    eq(vim.g.colors_name, scenario == "native" and "catppuccin-latte" or "catppuccin-mocha")
    eq(vim.o.background, scenario == "native" and "light" or "dark")
    eq(#errors, scenario == "native" and 0 or 1, "startup error reporting")
    print(("PASS nvim-theme %s startup (%s)"):format(scenario, real and "installed plugins" or "fixtures"))
    return
  end
  eq(errors, {}, "startup errors")
  if scenario == "fallback" then
    eq(vim.g.colors_name, "catppuccin-mocha", "portable fallback")
    eq(vim.o.background, "dark")
    eq(vim.api.nvim_get_hl(0, { name = "Normal", link = false }).fg, 0xcdd6f4, "Mocha foreground")
    -- Omarchy may be installed or create its first current/theme after startup.
    changed(generate("aether", '{colors = {fg = "#223344"}}'), "dark", "aether")
  else
    eq(vim.g.colors_name, "aether", "Omarchy startup")
    eq(vim.api.nvim_get_hl(0, { name = "Normal", link = false }).fg, 0x112233, "startup palette")
  end

  -- Same-name palettes must change real plugin options and actual highlights.
  changed(generate("aether", '{colors = {fg = "#445566", bg = "#fafafa"}}'), "light", "aether")
  eq(vim.o.background, "light")
  eq(vim.api.nvim_get_hl(0, { name = "Normal", link = false }).fg, 0x445566, "same-name palette")
  local before = schemes
  settle()
  eq(schemes, before, "unchanged file dedup")
  replace(generate("aether", '{colors = {fg = "#445566", bg = "#fafafa"}}'), "light")
  settle()
  eq(schemes, before, "identical replacement dedup")
  vim.api.nvim_exec_autocmds("User", { pattern = "LazyReload" })
  settle()
  eq(schemes, before, "LazyReload does not recurse")

  -- Missing, syntactically invalid, and invalid-shaped generated state all
  -- preserve the last good scheme; subsequent valid replacement recovers.
  vim.fn.delete(theme_dir, "rf")
  settle()
  eq(schemes, before, "transient missing directory")
  for _, invalid in ipairs({ "return {", "return false", "return {}" }) do
    replace(invalid, "dark")
    settle()
    eq(schemes, before, "invalid file preserves theme")
    eq(vim.o.background, "light", "invalid file preserves mode")
  end
  local error_count = #errors
  settle()
  eq(#errors, error_count, "invalid content notification dedup")
  assert(error_count == 3, "three invalid snapshots must be reported once each")
  errors = {}

  before = schemes
  replace([[return {{'not-installed/theme.nvim'},
    {'LazyVim/LazyVim', opts = {colorscheme = 'missing-theme'}}}]], "dark")
  settle()
  eq(schemes, before, "missing plugin does not reapply the previous scheme")
  eq(vim.o.background, "light", "missing plugin preserves mode")
  eq(#errors, 1, "missing plugin reported without installation")
  errors = {}

  -- A setup/config error also rolls back options, highlights and mode. Lazy's
  -- normal notification-only handling must not mark the broken spec applied.
  replace(generate("aether", '{colors = {fg = "#ffffff"}}',
    ', config = function() error("intentional broken setup") end'), "dark")
  settle()
  eq(vim.g.colors_name, "aether", "config failure rolls back scheme")
  eq(vim.api.nvim_get_hl(0, { name = "Normal", link = false }).fg, 0x445566, "config failure rolls back palette")
  eq(vim.o.background, "light", "config failure rolls back mode")
  eq(#errors, 1, "config failure reported")
  errors = {}

  -- No mode entry: legacy light marker. Also verify function opts + config
  -- semantics, not just table opts, survive lazy spec rebuilds.
  local configured = generate("nightfox", [[function(_, opts)
    opts.options = { transparent = false }
    vim.g.theme_opts_ran = (vim.g.theme_opts_ran or 0) + 1
    return opts
  end]], [[, config = function(_, opts)
    vim.g.theme_config_ran = (vim.g.theme_config_ran or 0) + 1
    require('nightfox').setup(opts)
  end]])
  changed(configured, nil, "nordfox", true)
  -- Real nordfox enforces its dark variant; aether below tests the marker itself.
  eq(vim.g.theme_opts_ran, 1, "function opts evaluated")
  eq(vim.g.theme_config_ran, 1, "custom config evaluated")
  changed(generate("aether", '{colors = {fg = "#667788"}}'), nil, "aether", true)
  eq(vim.o.background, "light", "legacy light.mode marker")
  changed(generate("aether", '{colors = {fg = "#667788"}}'), "dark", "aether")
  eq(vim.o.background, "dark", "metadata-only change")
  local function metadata(colors, expected)
    local prior = schemes
    write(theme_dir .. "/colors.toml", colors)
    controller.poll()
    controller.poll()
    eq(vim.o.background, expected, "legacy metadata mode")
    eq(schemes, prior + 1, "one event for metadata change")
  end
  metadata('theme_type = "light"\n', "light")
  metadata('theme_type = "light"\nmode = "dark"\n', "dark")
  metadata('bg = "#fafafa"\n', "light")
  metadata('color0 = "#101010"\n', "dark")
  metadata('background = "#fafafa"\ncolor0 = "#101010"\n', "light")
  vim.cmd("syntax off")
  eq(vim.fn.exists("syntax_on"), 0, "syntax inactive fixture")

  for _ = 1, 2 do
    changed(generate("catppuccin", '{flavour = "latte"}'), "light", "catppuccin-latte")
    eq(vim.o.background, "light", "native light")
    changed(generate("nightfox"), "dark", "nordfox")
    eq(vim.o.background, "dark", "unnamed native plugin")
    changed(generate("aether", '{colors = {fg = "#8899aa"}}'), "dark", "aether")
    eq(vim.api.nvim_get_hl(0, { name = "Normal", link = false }).fg, 0x8899aa)
    changed(generate("catppuccin", '{flavour = "mocha"}'), "dark", "catppuccin-mocha")
    eq(vim.o.background, "dark", "native options reset")
  end

  eq(vim.fn.exists("syntax_on"), 0, "theme reload does not enable syntax")

  if real and scenario == "runtime" then
    -- Stock 4.0 themes include bare specs and aliases, not just opts tables.
    -- This is optional, read-only coverage when Omarchy is installed locally.
    local stock = "/usr/share/omarchy/themes"
    local function read(path)
      local file = io.open(path, "rb")
      if not file then return nil end
      local contents = file:read("*a")
      file:close()
      return contents
    end
    local count = 0
    for _, name in ipairs({ "catppuccin-latte", "catppuccin", "everforest", "flexoki-light", "gruvbox",
      "hackerman", "kanagawa", "lumon", "matte-black", "nord", "osaka-jade", "retro-82", "rose-pine",
      "solitude", "tokyo-night" }) do
      local source = read(stock .. "/" .. name .. "/neovim.lua")
      if source then
        local colors = assert(read(stock .. "/" .. name .. "/colors.toml"))
        local mode = assert(colors:match('mode%s*=%s*"(%a+)"'))
        local prior = schemes
        replace(source, mode)
        assert(vim.wait(2500, function() return schemes > prior end, 25), name .. " stock theme did not apply")
        eq(schemes, prior + 1, name .. " stock event count")
        eq(vim.o.background, mode, name .. " stock mode")
        eq(errors, {}, name .. " stock errors")
        count = count + 1
      end
    end
    print("Stock native theme checks: " .. count)
  end

  -- Transparency is narrowly scoped, preserves links/other attributes, and
  -- never creates/clears groups absent from a theme.
  vim.api.nvim_set_hl(0, "ThemeUnrelated", { fg = "#abcdef", bg = "#123456", bold = true })
  vim.api.nvim_set_hl(0, "FloatBorder", { link = "ThemeUnrelated" })
  vim.api.nvim_set_hl(0, "Normal", { fg = "#abcdef", bg = "#123456", italic = true })
  local unrelated = vim.api.nvim_get_hl(0, { name = "ThemeUnrelated" })
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  normal.bg = nil
  local missing = vim.api.nvim_get_hl(0, { name = "NotifyDEBUGTitle", create = false })
  vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "test", modeline = false })
  eq(vim.api.nvim_get_hl(0, { name = "Normal" }), normal)
  eq(vim.api.nvim_get_hl(0, { name = "FloatBorder" }), { link = "ThemeUnrelated" })
  eq(vim.api.nvim_get_hl(0, { name = "ThemeUnrelated" }), unrelated)
  eq(vim.api.nvim_get_hl(0, { name = "NotifyDEBUGTitle", create = false }), missing)
  eq(entered, 1, "no synthetic VimEnter")

  local function active_timers()
    local count = 0
    vim.uv.walk(function(handle)
      if handle:get_type() == "timer" and handle:is_active() then
        count = count + 1
      end
    end)
    return count
  end
  local timers_before = active_timers()
  before = schemes
  controller.setup()
  controller.setup()
  eq(schemes, before, "idempotent setup does not reapply")
  eq(#vim.api.nvim_get_autocmds({ group = "OmarchyTheme" }), 2, "isolated autocmds")
  eq(active_timers(), timers_before, "no duplicate timer handles")
  eq(#vim.api.nvim_get_autocmds({ group = "OmarchyTheme", event = "ColorScheme" }), 1)
  if real then
    local state = rawget(_G, "__aether_hotreload_state")
    assert(not state or not state.did_setup, "aether watcher was activated")
  end
  eq(errors, {}, "runtime errors")
  vim.api.nvim_exec_autocmds("VimLeavePre", { modeline = false })
  assert(active_timers() < timers_before, "poll timer must stop on VimLeavePre")
  replace(generate("aether", '{colors = {fg = "#aabbcc"}}'), "dark")
  settle()
  eq(schemes, before, "VimLeavePre stops polling")
  print(("PASS nvim-theme %s (%s)"):format(scenario, real and "installed plugins" or "fixtures"))
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.schedule(function()
      local ok, err = xpcall(checks, debug.traceback)
      if not ok then
        io.stderr:write(err .. "\nNotifications: " .. vim.inspect(errors) .. "\n")
        vim.cmd("cquit 1")
      else
        vim.cmd("qa!")
      end
    end)
  end,
})
