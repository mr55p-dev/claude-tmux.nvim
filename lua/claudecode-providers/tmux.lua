-- Tmux terminal provider for claudecode.nvim

local state = {
  pane_id = nil,
  nvim_pane_id = nil,
  config = nil,
  hidden = false,
}

local function tmux_cmd(args)
  local handle = io.popen("tmux " .. args .. " 2>/dev/null")
  if not handle then return nil end
  local result = handle:read("*a")
  handle:close()
  return result and result:gsub("%s+$", "") or nil
end

local function pane_exists()
  if not state.pane_id then return false end
  local result = tmux_cmd("list-panes -F '#{pane_id}'")
  if not result then return false end
  return result:find(state.pane_id, 1, true) ~= nil
end

local function is_pane_focused()
  if not state.pane_id then return false end
  local active_pane = tmux_cmd("display-message -p '#{pane_id}'")
  return active_pane == state.pane_id
end

local function get_current_pane_id()
  return tmux_cmd("display-message -p '#{pane_id}'")
end

local function hide_pane()
  if not state.pane_id or not pane_exists() then return end
  local flag = state.config.split_side == "right" and "-x" or "-y"
  tmux_cmd("resize-pane -t " .. state.pane_id .. " " .. flag .. " 1")
  state.hidden = true
end

local function show_pane()
  if not state.pane_id or not pane_exists() then return end
  local flag = state.config.split_side == "right" and "-x" or "-y"
  tmux_cmd("resize-pane -t " .. state.pane_id .. " " .. flag .. " " .. state.config.split_size .. "%")
  state.hidden = false
end

local function vim_key_to_tmux(vim_key)
  if not vim_key then return nil end
  local key = vim_key
  key = key:gsub("<C%-(%w)>", "C-%1")
  key = key:gsub("<[MA]%-(%w)>", "M-%1")
  key = key:gsub("<CR>", "Enter")
  key = key:gsub("<Enter>", "Enter")
  key = key:gsub("<Tab>", "Tab")
  key = key:gsub("<Space>", "Space")
  key = key:gsub("<Esc>", "Escape")
  key = key:gsub("<BS>", "BSpace")
  key = key:gsub("<F(%d+)>", "F%1")
  return key
end

local function setup_return_binding()
  if not state.pane_id or not state.nvim_pane_id then return end
  local tmux_key = vim_key_to_tmux(state.config.toggle_key)
  if not tmux_key then return end
  local binding_cmd = string.format(
    [[bind -n %s if-shell -F '#{==:#{pane_id},%s}' 'select-pane -t %s' 'send-keys %s']],
    tmux_key, state.pane_id, state.nvim_pane_id, tmux_key
  )
  tmux_cmd(binding_cmd)
end

local function remove_return_binding()
  local tmux_key = vim_key_to_tmux(state.config and state.config.toggle_key)
  if tmux_key then
    tmux_cmd("unbind -n " .. tmux_key)
  end
end

local provider = {}

function provider.setup(config)
  state.config = config
end

function provider.get_config()
  return state.config
end

function provider.is_available()
  return os.getenv("TMUX") ~= nil
end

function provider.open(cmd_string, env_table, effective_config, focus)
  if focus == nil then focus = true end
  if pane_exists() then
    if focus then tmux_cmd("select-pane -t " .. state.pane_id) end
    return
  end

  local env_prefix = ""
  if env_table then
    for key, value in pairs(env_table) do
      local escaped_value = tostring(value):gsub("'", "'\\''")
      env_prefix = env_prefix .. key .. "='" .. escaped_value .. "' "
    end
  end

  local split_size = state.config.split_size
    or (effective_config and effective_config.split_size)
    or 30
  local split_flag = state.config.split_side == "right" and "-h" or "-v"

  local original_pane = get_current_pane_id()
  state.nvim_pane_id = original_pane

  local full_cmd = env_prefix .. cmd_string
  local cwd = vim.fn.getcwd():gsub("'", "'\\''")
  local new_pane_id = tmux_cmd(string.format(
    "split-window %s -l %d%% -c '%s' -P -F '#{pane_id}' '%s'",
    split_flag, split_size, cwd, full_cmd:gsub("'", "'\\''")
  ))

  if new_pane_id and new_pane_id ~= "" then
    state.pane_id = new_pane_id
    state.hidden = false
    setup_return_binding()
  end

  if not focus and original_pane then
    tmux_cmd("select-pane -t " .. original_pane)
  end
end

function provider.close()
  if state.pane_id and pane_exists() then
    tmux_cmd("kill-pane -t " .. state.pane_id)
  end
  remove_return_binding()
  state.pane_id = nil
  state.nvim_pane_id = nil
  state.hidden = false
end

function provider.hide()
  hide_pane()
end

function provider.show()
  show_pane()
  if state.pane_id then
    tmux_cmd("select-pane -t " .. state.pane_id)
  end
end

function provider.is_hidden()
  return state.hidden
end

function provider.simple_toggle(cmd_string, env_table, effective_config)
  if pane_exists() then
    if state.hidden then
      show_pane()
      tmux_cmd("select-pane -t " .. state.pane_id)
    else
      hide_pane()
    end
  else
    provider.open(cmd_string, env_table, effective_config, true)
  end
end

function provider.focus_toggle(cmd_string, env_table, effective_config)
  if not pane_exists() then
    provider.open(cmd_string, env_table, effective_config, true)
  elseif state.hidden then
    show_pane()
    tmux_cmd("select-pane -t " .. state.pane_id)
  elseif is_pane_focused() then
    hide_pane()
    tmux_cmd("last-pane")
  else
    tmux_cmd("select-pane -t " .. state.pane_id)
  end
end

function provider.toggle(cmd_string, env_table, effective_config)
  provider.simple_toggle(cmd_string, env_table, effective_config)
end

function provider.get_active_bufnr()
  return nil
end

function provider._get_terminal_for_test()
  return state.pane_id
end

return provider
