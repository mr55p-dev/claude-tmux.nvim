-- Re-broadcasts the current selection once Claude connects.
--
-- claudecode.nvim only sends `selection_changed` when the selection changes, so a
-- Claude process that connects afterwards doesn't learn the current file until
-- the cursor moves or a visual selection is made.

local M = {}

local POLL_MS = 200
local MAX_TRIES = 150 -- 30s
local SETTLE_MS = 150

function M.send_when_connected()
  local timer = vim.uv.new_timer()
  local tries = 0

  local function stop()
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end

  timer:start(POLL_MS, POLL_MS, vim.schedule_wrap(function()
    tries = tries + 1
    local ok, claudecode = pcall(require, "claudecode")
    if not ok or tries > MAX_TRIES then return stop() end
    if not claudecode.is_claude_connected() then return end
    stop()

    vim.defer_fn(function()
      local sel_ok, selection = pcall(require, "claudecode.selection")
      if not sel_ok or not selection.state.tracking_enabled or not selection.server then return end
      selection.update_selection()
      local latest = selection.get_latest_selection()
      if latest then selection.send_selection_update(latest) end
    end, SETTLE_MS)
  end))
end

return M
