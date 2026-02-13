-- claude-tmux.nvim
-- A tmux terminal provider for claudecode.nvim
-- Opens Claude Code in a tmux split at the bottom of the window

local M = {}

-- Default configuration
local defaults = {
  toggle_key = "<C-j>",  -- Key to return to neovim from claude pane
  split_size = 30,       -- Percentage of window height for the split
}

-- State
local state = {
  pane_id = nil,
  nvim_pane_id = nil,
  config = nil,
  hidden = false,
}

-- Helper to run tmux commands and get output
local function tmux_cmd(args)
  local cmd = "tmux " .. args
  local handle = io.popen(cmd .. " 2>/dev/null")
  if not handle then
    return nil
  end
  local result = handle:read("*a")
  handle:close()
  return result and result:gsub("%s+$", "") or nil
end

-- Check if we're inside tmux
local function is_in_tmux()
  return os.getenv("TMUX") ~= nil
end

-- Check if our pane still exists
local function pane_exists()
  if not state.pane_id then
    return false
  end
  local result = tmux_cmd("list-panes -F '#{pane_id}'")
  if not result then
    return false
  end
  return result:find(state.pane_id, 1, true) ~= nil
end

-- Check if our pane is currently focused
local function is_pane_focused()
  if not state.pane_id then
    return false
  end
  local active_pane = tmux_cmd("display-message -p '#{pane_id}'")
  return active_pane == state.pane_id
end

-- Hide the claude pane by resizing to minimum height
local function hide_pane()
  if not state.pane_id or not pane_exists() then
    return
  end
  -- Resize to 1 line (minimum possible)
  tmux_cmd("resize-pane -t " .. state.pane_id .. " -y 1")
  state.hidden = true
end

-- Show the claude pane by restoring its height
local function show_pane()
  if not state.pane_id or not pane_exists() then
    return
  end
  local split_size = (state.config and state.config.split_size) or defaults.split_size
  -- Restore to configured percentage
  tmux_cmd("resize-pane -t " .. state.pane_id .. " -y " .. split_size .. "%")
  state.hidden = false
end

-- Get the current pane ID (the neovim pane)
local function get_current_pane_id()
  return tmux_cmd("display-message -p '#{pane_id}'")
end

-- Convert vim key notation to tmux key notation
local function vim_key_to_tmux(vim_key)
  if not vim_key then
    return nil
  end

  local key = vim_key

  -- Handle <C-x> style control keys
  key = key:gsub("<C%-(%w)>", "C-%1")
  key = key:gsub("<C%-(%w)>", "C-%1")

  -- Handle <M-x> or <A-x> style alt/meta keys
  key = key:gsub("<[MA]%-(%w)>", "M-%1")

  -- Handle special keys
  key = key:gsub("<CR>", "Enter")
  key = key:gsub("<Enter>", "Enter")
  key = key:gsub("<Tab>", "Tab")
  key = key:gsub("<Space>", "Space")
  key = key:gsub("<Esc>", "Escape")
  key = key:gsub("<BS>", "BSpace")

  -- Handle function keys
  key = key:gsub("<F(%d+)>", "F%1")

  return key
end

-- Set up toggle key binding to return to neovim pane (only active when in claude pane)
local function setup_return_binding()
  if not state.pane_id or not state.nvim_pane_id then
    return
  end

  local toggle_key = state.config and state.config.toggle_key
  if not toggle_key then
    return
  end

  local tmux_key = vim_key_to_tmux(toggle_key)
  if not tmux_key then
    return
  end

  -- Create a conditional binding: if in the claude pane, go to nvim pane
  -- Otherwise, let the key pass through normally
  local binding_cmd = string.format(
    [[bind -n %s if-shell -F '#{==:#{pane_id},%s}' 'select-pane -t %s' 'send-keys %s']],
    tmux_key,
    state.pane_id,
    state.nvim_pane_id,
    tmux_key
  )
  tmux_cmd(binding_cmd)
end

-- Remove the toggle key binding when closing
local function remove_return_binding()
  local toggle_key = state.config and state.config.toggle_key
  if not toggle_key then
    return
  end

  local tmux_key = vim_key_to_tmux(toggle_key)
  if tmux_key then
    tmux_cmd("unbind -n " .. tmux_key)
  end
end

-- Provider implementation
local provider = {}

function provider.setup(config)
  -- This is called by claudecode.nvim, merge with our config
  if config then
    state.config = vim.tbl_deep_extend("force", state.config or {}, config)
  end
end

function provider.open(cmd_string, env_table, effective_config, focus)
  if focus == nil then
    focus = true
  end

  -- If pane already exists and is running, just focus it
  if pane_exists() then
    if focus then
      tmux_cmd("select-pane -t " .. state.pane_id)
    end
    return
  end

  -- Build environment variable prefix for the command
  local env_prefix = ""
  if env_table then
    for key, value in pairs(env_table) do
      -- Escape single quotes in values
      local escaped_value = tostring(value):gsub("'", "'\\''")
      env_prefix = env_prefix .. key .. "='" .. escaped_value .. "' "
    end
  end

  -- Get split size from our config or effective_config
  local split_size = (state.config and state.config.split_size)
    or (effective_config and effective_config.split_size)
    or defaults.split_size

  -- Remember current pane (neovim) to return to if not focusing and for toggle key binding
  local original_pane = get_current_pane_id()
  state.nvim_pane_id = original_pane

  -- Create a new split at the bottom
  local full_cmd = env_prefix .. cmd_string

  -- Split and run command, capturing the new pane ID
  -- Using -P to print pane info and -F to format it
  local new_pane_id = tmux_cmd(
    string.format(
      "split-window -v -l %d%% -P -F '#{pane_id}' '%s'",
      split_size,
      full_cmd:gsub("'", "'\\''")
    )
  )

  if new_pane_id and new_pane_id ~= "" then
    state.pane_id = new_pane_id
    state.hidden = false
    -- Set up toggle key to return to neovim from the claude pane
    setup_return_binding()
  end

  -- Return focus to neovim if not focusing terminal
  if not focus and original_pane then
    tmux_cmd("select-pane -t " .. original_pane)
  end
end

function provider.close()
  if state.pane_id and pane_exists() then
    tmux_cmd("kill-pane -t " .. state.pane_id)
  end
  -- Clean up the toggle key binding
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
      -- Pane is hidden, show it and focus
      show_pane()
      tmux_cmd("select-pane -t " .. state.pane_id)
    else
      -- Pane is visible, hide it
      hide_pane()
    end
  else
    -- Pane doesn't exist, open it
    provider.open(cmd_string, env_table, effective_config, true)
  end
end

function provider.focus_toggle(cmd_string, env_table, effective_config)
  if not pane_exists() then
    -- Terminal doesn't exist, open it
    provider.open(cmd_string, env_table, effective_config, true)
  elseif state.hidden then
    -- Terminal is hidden, show it and focus
    show_pane()
    tmux_cmd("select-pane -t " .. state.pane_id)
  elseif is_pane_focused() then
    -- Terminal is focused, hide it and return to neovim
    hide_pane()
    tmux_cmd("last-pane")
  else
    -- Terminal exists but not focused, focus it
    tmux_cmd("select-pane -t " .. state.pane_id)
  end
end

function provider.toggle(cmd_string, env_table, effective_config)
  -- Default to simple_toggle for backward compatibility
  provider.simple_toggle(cmd_string, env_table, effective_config)
end

function provider.get_active_bufnr()
  -- Tmux panes don't have neovim buffer numbers
  -- Return nil since the terminal is external to neovim
  return nil
end

function provider.is_available()
  return is_in_tmux()
end

function provider._get_terminal_for_test()
  return state.pane_id
end

--- Setup the claude-tmux provider
--- @param opts table|nil Configuration options
--- @param opts.toggle_key string|nil Key to return to neovim from claude pane (default: "<C-j>")
--- @param opts.split_size number|nil Percentage of window height for the split (default: 30)
--- @return table provider The terminal provider for claudecode.nvim
function M.setup(opts)
  opts = opts or {}
  state.config = vim.tbl_deep_extend("force", {}, defaults, opts)
  return provider
end

--- Get the current configuration
--- @return table config The current configuration
function M.get_config()
  return state.config or defaults
end

--- Check if the provider is available (running inside tmux)
--- @return boolean
function M.is_available()
  return is_in_tmux()
end

return M
