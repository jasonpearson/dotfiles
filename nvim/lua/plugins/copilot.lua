return {
	"zbirenbaum/copilot.lua",
	cmd = "Copilot",
	event = "InsertEnter",
	config = function()
		require("copilot").setup({
			panel = {
				enabled = true,
			},
			suggestion = {
				enabled = true,
				auto_trigger = true,
				keymap = {
					accept = "<C-y>",
					accept_word = false,
					accept_line = false,
					next = "<C-l>",
					prev = "<C-h>",
					dismiss = "<C-n>",
				},
			},
		})
	end,
}
