return {
	"tinted-theming/base16-vim",
	config = function()
		vim.cmd("colorscheme base16-" .. os.getenv("BASE16_THEME"))
		vim.api.nvim_command("hi CursorLine ctermbg=19")
	end,
}
