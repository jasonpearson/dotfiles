-- macOS uses pbcopy/pbpaste. Elsewhere, use Wayland when available and send
-- OSC 52 copies in tmux/SSH sessions. Without Wayland, those sessions also
-- query the terminal for paste.
local M = {}

function M.setup()
  if vim.fn.has("mac") == 1 then
    vim.g.clipboard = {
      name = "pbcopy",
      copy = { ["+"] = { "pbcopy" }, ["*"] = { "pbcopy" } },
      paste = { ["+"] = { "pbpaste" }, ["*"] = { "pbpaste" } },
      cache_enabled = 0,
    }
    return
  end

  local in_tmux = vim.env.TMUX ~= nil
  local in_ssh = vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil
  local needs_osc52 = in_tmux or in_ssh
  local has_wayland = vim.env.WAYLAND_DISPLAY ~= nil
    and vim.fn.executable("wl-copy") == 1
    and vim.fn.executable("wl-paste") == 1

  if not (has_wayland or needs_osc52) then
    return
  end

  local osc52 = require("vim.ui.clipboard.osc52")

  local function copy(register)
    local emit = osc52.copy(register)

    return function(lines)
      if has_wayland then
        local cmd = { "wl-copy", "--sensitive", "--type", "text/plain" }
        if register == "*" then
          cmd[#cmd + 1] = "--primary"
        end
        vim.fn.system(cmd, lines)
      end

      if needs_osc52 and vim.g.omarchy_remote_clipboard_osc52 ~= false then
        emit(lines)
      end
    end
  end

  local function paste(register)
    if not has_wayland then
      return osc52.paste(register)
    end

    return function()
      local cmd = { "wl-paste", "--no-newline" }
      if register == "*" then
        cmd[#cmd + 1] = "--primary"
      end

      local lines = vim.fn.systemlist(cmd, "", 1)
      return vim.v.shell_error == 0 and lines or {}
    end
  end

  vim.g.clipboard = {
    name = has_wayland and "WaylandClipboard" or "OmarchyRemoteClipboard",
    copy = { ["+"] = copy("+"), ["*"] = copy("*") },
    paste = { ["+"] = paste("+"), ["*"] = paste("*") },
    cache_enabled = 0,
  }
end

return M
