vim.keymap.set({ "i" }, "kj", "<Esc>")
vim.keymap.set("n", "<C-c>", "<cmd>:noh<cr>")
vim.keymap.set("n", "<leader>t", "<cmd>tabe %:p:h<cr>")
vim.keymap.set("n", "<leader>T", "<cmd>tabe .<cr>")
vim.keymap.set("n", "<leader>w", "<cmd>write<cr>")
vim.keymap.set("n", "<leader>q", "<cmd>quit<cr>")
vim.keymap.set("n", "<leader>pl", "<cmd>Lazy<cr>", { desc = "Lazy Plugin Manager" })
vim.keymap.set("n", "<leader>v", "<cmd>vsp %:p:h<cr>")
vim.keymap.set("n", "<leader>V", "<cmd>vsp .<cr>")
vim.keymap.set("n", "<leader>W", "<cmd>set wrap!<cr>")
vim.keymap.set({ "v" }, "<leader>y", '"+y') -- yank to system clipboard

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
vim.keymap.set("n", "<C-j>", navigate("j", "-D", "down"), { desc = "Go to lower window or pane" })
vim.keymap.set("n", "<C-k>", navigate("k", "-U", "up"), { desc = "Go to upper window or pane" })
vim.keymap.set("n", "<C-l>", navigate("l", "-R", "right"), { desc = "Go to right window or pane" })

vim.keymap.set("n", "<leader>yp", function()
  vim.fn.setreg("+", vim.fn.expand("%"))
  vim.notify("Copied relative file path")
end, { desc = "Copy relative file path" })

vim.keymap.set("n", "<leader>yP", function()
  vim.fn.setreg("+", vim.fn.expand("%:p"))
  vim.notify("Copied absolute file path")
end, { desc = "Copy absolute file path" })

if vim.lsp.inlay_hint then
  vim.keymap.set("n", "<leader>uh", function()
    local enabled = vim.lsp.inlay_hint.is_enabled()
    vim.lsp.inlay_hint.enable(not enabled)
    vim.notify((enabled and "Disabled" or "Enabled") .. " inlay hints")
  end, { desc = "Toggle Inlay Hints" })
end

local function git_root_for_file(file)
  local dir = vim.fs.dirname(file)
  local root = vim.trim(vim.fn.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }))
  if vim.v.shell_error ~= 0 or root == "" then
    return nil
  end
  return root
end

local function open_file_from_git_ref(file, ref)
  local root = git_root_for_file(file)
  if not root then
    vim.notify("Current file is not in a git repository", vim.log.levels.WARN)
    return
  end

  local abs_file = vim.fs.normalize(file):gsub("\\", "/")
  local abs_root = vim.fs.normalize(root):gsub("\\", "/")
  local rel = abs_file
  if rel:find(abs_root, 1, true) == 1 then
    rel = rel:sub(#abs_root + 2)
  end

  local lines = vim.fn.systemlist({ "git", "-C", abs_root, "show", ref .. ":" .. rel })
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to read " .. rel .. " from " .. ref, vim.log.levels.ERROR)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, string.format("git:%s:%s", ref, rel))
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local ft = vim.filetype.match({ filename = file })
  if ft then
    vim.api.nvim_set_option_value("filetype", ft, { buf = buf })
  end
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("readonly", true, { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, buf)
end

local function choose_ref_and_open_file()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end

  local root = git_root_for_file(file)
  if not root then
    vim.notify("Current file is not in a git repository", vim.log.levels.WARN)
    return
  end

  local refs = {}
  local seen = {}
  local function add_ref(ref)
    if ref == "" then
      return
    end
    if seen[ref] then
      return
    end
    seen[ref] = true
    refs[#refs + 1] = ref
  end

  -- Make main/master the first quick choices.
  add_ref("main")
  add_ref("master")

  local branches = vim.fn.systemlist({ "git", "-C", root, "branch", "--format=%(refname:short)" })
  if vim.v.shell_error == 0 then
    for _, ref in ipairs(branches) do
      add_ref(vim.trim(ref))
    end
  end

  table.insert(refs, 1, "<enter custom ref...>")

  vim.ui.select(refs, {
    prompt = "Open current file from git ref",
  }, function(choice)
    if not choice then
      return
    end
    if choice == "<enter custom ref...>" then
      vim.ui.input({ prompt = "Git ref (branch/commit/tag): " }, function(input)
        if not input or input == "" then
          return
        end
        open_file_from_git_ref(file, input)
      end)
      return
    end
    open_file_from_git_ref(file, choice)
  end)
end

vim.keymap.set("n", "<leader>gM", function()
  choose_ref_and_open_file()
end, { desc = "View current file from another git ref" })

-- Unmap LazyVim's default save shortcut so <C-s> is free for Flash.
vim.keymap.del({ "i", "n", "x", "s" }, "<C-s>")
