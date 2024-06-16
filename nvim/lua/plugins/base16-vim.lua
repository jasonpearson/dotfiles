return {
	"tinted-theming/base16-vim",
	config = function()
		vim.cmd("colorscheme base16-default-dark")
		vim.api.nvim_set_hl(0, "Visual", { ctermbg = 141, ctermfg = 236 })
		vim.api.nvim_set_hl(0, "TelescopeSelection", { ctermbg = 141, ctermfg = 236 })
		vim.api.nvim_set_hl(0, "TelescopeMatching", { ctermfg = 2 })
	end,
}
