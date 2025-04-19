vim.g.base16colorspace = 256
vim.g.mapleader = " "
vim.g.netrw_banner = 0
vim.g.netrw_bufsettings = "noma nomod nu nobl nowrap ro"

vim.opt.backspace = "indent,eol,start"
vim.opt.breakindent = true
vim.opt.cursorline = true
vim.opt.equalalways = true
vim.opt.expandtab = true
vim.opt.hlsearch = true
vim.opt.ignorecase = false
vim.opt.mouse = "a"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.smartcase = true
vim.opt.shiftwidth = 2
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.swapfile = false
vim.opt.tabstop = 2
vim.opt.timeoutlen = 300
vim.opt.updatetime = 1000
vim.opt.wildignorecase = true
vim.opt.wrap = false

vim.diagnostic.config({
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "☠️", -- Error
			[vim.diagnostic.severity.WARN] = "😭", -- Warning
			[vim.diagnostic.severity.INFO] = "🤓", -- Information
			[vim.diagnostic.severity.HINT] = "🤔", -- Hint
		},
		numhl = {
			[vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
			[vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
			[vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
			[vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
		},
		texthl = {
			[vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
			[vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
			[vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
			[vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
		},
	},
})

vim.cmd(
	[[                                                                                                                                                                                                                                                                                                                                                                
   autocmd WinEnter * setlocal cursorline                                                                                                                                                                                                                                                                                                                                  
   autocmd WinLeave * setlocal nocursorline                                                                                                                                                                                                                                                                                                                                
 ]]
)
