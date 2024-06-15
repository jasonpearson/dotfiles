return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
		vim.opt.showmode = false
		require('lualine').setup({
			tabline = {
				lualine_a = {
					{
						"tabs",
						tab_max_length = 50,
						max_length = 2000,
						mode = 2,
						path = 1
					}
				},
			},
			sections = {
				lualine_b = {},
				lualine_c = {
					{
						'filename',
						path = 1,
					},
				},
				lualine_x = {
					'diff',
					'diagnostics',
				},
			},
			inactive_sections = {
				lualine_c = {
					{
						'filename',
						path = 1,
					},
				},
				lualine_x = {},
			},
			options = {
				theme = "dracula",
				icons_enabled = false,
				component_separators = '|',
				section_separators = '',
			},
		})
  end,
}
