return {
	"tinted-theming/tinted-vim",
	config = function()
		vim.api.nvim_set_hl(0, "Visual", { ctermbg = 141, ctermfg = 236 })
		vim.api.nvim_set_hl(0, "TelescopeSelection", { ctermbg = 141, ctermfg = 236 })
		vim.api.nvim_set_hl(0, "PmenuSel", { ctermbg = 141, ctermfg = 236 })
	end,
}
