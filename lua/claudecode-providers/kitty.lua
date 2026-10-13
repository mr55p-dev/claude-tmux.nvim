-- Kitty terminal provider for claudecode.nvim
--
-- Requires kitty to be running with remote control enabled.
-- Set `allow_remote_control yes` in kitty.conf, or launch kitty with
-- `--listen-on unix:/tmp/kitty`.
--
-- Note: kitty has no runtime keybinding API, so toggle_key is not supported.
-- Use kitty's built-in window navigation to return to neovim.

local state = {
  window_id = nil,
  nvim_window_id = nil,
  config = nil,
  hidden = false,
  saved_size = nil,  -- {lines, columns} snapshot taken before hiding, restored on show
}

local function kitty_cmd(args)
  local handle = io.popen("kitty @ " .. args .. " 2>/dev/null")
  if not handle then return nil end
  local result = handle:read("*a")
  handle:close()
  return result and result:gsub("%s+$", "") or nil
end

local function window_exists()
  if not state.window_id then return false end
  local result = kitty_cmd("ls")
  if not result then return false end
  return result:find('"id": ?' .. state.window_id, 1, false) ~= nil
end

local function is_window_focused()
  if not state.window_id then return false end
  local result = kitty_cmd("ls")
  if not result then return false end
  local pos = result:find('"id": ?' .. state.window_id)
  if not pos then return false end
  -- Check within the next ~300 chars (same window object in the JSON)
  return result:sub(pos, pos + 300):find('"is_focused":%s*true') ~= nil
end

local function get_window_size()
  if not state.window_id then return nil end
  local result = kitty_cmd("ls")
  if not result then return nil end
  local pos = result:find('"id": ?' .. state.window_id)
  if not pos then return nil end
  local snippet = result:sub(pos, pos + 500)
  local lines = snippet:match('"lines":%s*(%d+)')
  local columns = snippet:match('"columns":%s*(%d+)')
  if lines and columns then
    return { lines = tonumber(lines), columns = tonumber(columns) }
  end
  return nil
end

local function hide_window()
  if not state.window_id or not window_exists() then return end
  local axis = state.config.split_side == "right" and "horizontal" or "vertical"
  local size = get_window_size()
  if size then
    state.saved_size = size
    local current = axis == "vertical" and size.lines or size.columns
    local shrink_by = current - 1
    if shrink_by > 0 then
      kitty_cmd(string.format(
        "resize-window --match id:%s --axis %s --increment -%d",
        state.window_id, axis, shrink_by
      ))
    end
  end
  state.hidden = true
end

local function show_window()
  if not state.window_id or not window_exists() then return end
  local axis = state.config.split_side == "right" and "horizontal" or "vertical"
  if state.saved_size then
    local target = axis == "vertical" and state.saved_size.lines or state.saved_size.columns
    local size = get_window_size()
    local current = size and (axis == "vertical" and size.lines or size.columns) or 1
    local grow_by = target - current
    if grow_by > 0 then
      kitty_cmd(string.format(
        "resize-window --match id:%s --axis %s --increment %d",
        state.window_id, axis, grow_by
      ))
    end
    state.saved_size = nil
  else
    kitty_cmd("resize-window --match id:" .. state.window_id .. " --axis reset")
  end
  state.hidden = false
end

local provider = {}

function provider.setup(config)
  state.config = config
end

function provider.get_config()
  return state.config
end

function provider.is_available()
  return os.getenv("KITTY_WINDOW_ID") ~= nil
end

function provider.open(cmd_string, env_table, effective_config, focus)
  if focus == nil then focus = true end
  if window_exists() then
    if focus then kitty_cmd("focus-window --match id:" .. state.window_id) end
    return
  end

  local split_size = state.config.split_size
    or (effective_config and effective_config.split_size)
    or 30
  local location = state.config.split_side == "right" and "vsplit" or "hsplit"

  state.nvim_window_id = os.getenv("KITTY_WINDOW_ID")

  local env_flags = ""
  local current_path = os.getenv("PATH")
  if current_path then
    local escaped_path = current_path:gsub("'", "'\\''")
    env_flags = string.format(" --env 'PATH=%s'", escaped_path)
  end
  if env_table then
    for key, value in pairs(env_table) do
      local escaped_value = tostring(value):gsub("'", "'\\''")
      env_flags = env_flags .. string.format(" --env '%s=%s'", key, escaped_value)
    end
  end

  local escaped_cmd = cmd_string:gsub("'", "'\\''")
  local cwd = vim.fn.getcwd():gsub("'", "'\\''")
  local output = kitty_cmd(string.format(
    "launch --type=window --location=%s --bias=%d --cwd='%s'%s -- bash -c '%s'",
    location, split_size, cwd, env_flags, escaped_cmd
  ))

  if output and output ~= "" then
    -- kitty @ launch prints the new window ID on stdout
    state.window_id = output:match("(%d+)")
    state.hidden = false
  end

  if not focus and state.nvim_window_id then
    kitty_cmd("focus-window --match id:" .. state.nvim_window_id)
  end
end

function provider.close()
  if state.window_id and window_exists() then
    kitty_cmd("close-window --match id:" .. state.window_id)
  end
  state.window_id = nil
  state.nvim_window_id = nil
  state.hidden = false
  state.saved_size = nil
end

function provider.hide()
  hide_window()
end

function provider.show()
  show_window()
  if state.window_id then
    kitty_cmd("focus-window --match id:" .. state.window_id)
  end
end

function provider.is_hidden()
  return state.hidden
end

function provider.simple_toggle(cmd_string, env_table, effective_config)
  if window_exists() then
    if state.hidden then
      show_window()
      kitty_cmd("focus-window --match id:" .. state.window_id)
    else
      hide_window()
    end
  else
    provider.open(cmd_string, env_table, effective_config, true)
  end
end

function provider.focus_toggle(cmd_string, env_table, effective_config)
  if not window_exists() then
    provider.open(cmd_string, env_table, effective_config, true)
  elseif state.hidden then
    show_window()
    kitty_cmd("focus-window --match id:" .. state.window_id)
  elseif is_window_focused() then
    hide_window()
    if state.nvim_window_id then
      kitty_cmd("focus-window --match id:" .. state.nvim_window_id)
    end
  else
    kitty_cmd("focus-window --match id:" .. state.window_id)
  end
end

function provider.toggle(cmd_string, env_table, effective_config)
  provider.simple_toggle(cmd_string, env_table, effective_config)
end

function provider.get_active_bufnr()
  return nil
end

function provider._get_terminal_for_test()
  return state.window_id
end

return provider
