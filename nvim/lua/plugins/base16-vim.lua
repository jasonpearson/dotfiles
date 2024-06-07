return {
	"tinted-theming/base16-vim",
	config = function()
		vim.cmd("colorscheme base16-" .. os.getenv("BASE16_THEME"))
	end,
}
