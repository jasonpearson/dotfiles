local function notify_error(message)
	vim.notify(message, vim.log.levels.ERROR, { title = "Theme hot reload" })
end

local function load_theme_spec()
	package.loaded["plugins.theme"] = nil

	local ok, theme_spec = pcall(require, "plugins.theme")
	if not ok then
		notify_error("Failed to load plugins.theme: " .. theme_spec)
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
			require("transparency").apply()

			-- Trigger UI updates for plugins that cache colors.
			vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
			vim.api.nvim_exec_autocmds("VimEnter", { modeline = false })

			vim.cmd("redraw!")
		end, 5)
	end, 5)
end

return {
	{
		name = "theme-hotreload",
		dir = vim.fn.stdpath("config"),
		lazy = false,
		priority = 1000,
		config = function()
			vim.api.nvim_create_autocmd("User", {
				group = vim.api.nvim_create_augroup("ThemeHotReload", { clear = true }),
				pattern = "LazyReload",
				callback = function()
					vim.schedule(function()
						local theme_plugin_name, colorscheme = find_theme(load_theme_spec())

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
	},
}
