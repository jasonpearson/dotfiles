-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("i", "kj", "<Esc>", { desc = "Escape insert mode" })
-- vim.keymap.set("n", "<C-c>", "<cmd>noh<cr>", { desc = "Clear search highlight" })
-- vim.keymap.set("n", "<leader>w", "<cmd>write<cr>", { desc = "Write file" })
-- vim.keymap.set("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit" })
-- vim.keymap.set("n", "<leader>Q", "<cmd>quitall<cr>", { desc = "Quit all" })
-- vim.keymap.set("n", "<leader>r", "<cmd>set relativenumber!<cr>", { desc = "Toggle relative number" })
-- vim.keymap.set("n", "<leader>W", "<cmd>set wrap!<cr>", { desc = "Toggle wrap" })

local function navigate(direction, tmux_flag, herdr_direction)
  return function()
    local before = vim.api.nvim_get_current_win()
    vim.cmd.wincmd(direction)

    if vim.api.nvim_get_current_win() ~= before then
      return
    end

    if vim.env.TMUX then
      vim.fn.jobstart({ "tmux", "select-pane", tmux_flag }, { detach = true })
    elseif vim.env.HERDR_PANE_ID then
      vim.fn.jobstart({ "herdr", "pane", "focus", "--current", "--direction", herdr_direction }, { detach = true })
    end
  end
end

vim.keymap.set("n", "<C-h>", navigate("h", "-L", "left"), { desc = "Go to left window or pane" })
-- vim.keymap.set("n", "<BS>", navigate("h", "-L", "left"), { desc = "Go to left window or pane" })
vim.keymap.set("n", "<C-j>", navigate("j", "-D", "down"), { desc = "Go to lower window or pane" })
vim.keymap.set("n", "<C-k>", navigate("k", "-U", "up"), { desc = "Go to upper window or pane" })
vim.keymap.set("n", "<C-l>", navigate("l", "-R", "right"), { desc = "Go to right window or pane" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "neo-tree",
  callback = function(event)
    local function focus_outer_left()
      if vim.env.TMUX then
        vim.fn.system({ "tmux", "select-pane", "-L" })
      elseif vim.env.HERDR_PANE_ID then
        vim.fn.system({ "herdr", "pane", "focus", "--current", "--direction", "left" })
      end
    end

    vim.keymap.set("n", "<C-h>", focus_outer_left, { buffer = event.buf, desc = "Go to left pane" })
    vim.keymap.set("n", "<BS>", focus_outer_left, { buffer = event.buf, desc = "Go to left pane" })
  end,
})
