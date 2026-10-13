-- claude-providers.nvim
-- Terminal providers for claudecode.nvim: tmux and kitty

local M = {}

local tmux = require("claudecode-providers.tmux")
local kitty = require("claudecode-providers.kitty")

local defaults = {
  provider = "auto",     -- "auto", "tmux", or "kitty"
  toggle_key = "<C-j>",  -- tmux only: key to return to neovim from the claude pane
  split_size = 30,       -- percentage of window height/width for the split
  split_side = "bottom", -- where to open the split: "bottom" or "right"
}

local active_provider = nil

--- Setup the provider and return it for claudecode.nvim
--- @param opts table|nil Configuration options
--- @param opts.provider string|nil "auto", "tmux", or "kitty" (default: "auto")
--- @param opts.toggle_key string|nil tmux only: key to return to neovim (default: "<C-j>")
--- @param opts.split_size number|nil Percentage of window for the split (default: 30)
--- @param opts.split_side string|nil Where to open: "bottom" or "right" (default: "bottom")
--- @return table provider The terminal provider for claudecode.nvim
function M.setup(opts)
  opts = opts or {}
  local config = vim.tbl_deep_extend("force", {}, defaults, opts)

  local provider_name = config.provider
  if provider_name == "auto" then
    if kitty.is_available() then
      provider_name = "kitty"
    elseif tmux.is_available() then
      provider_name = "tmux"
    else
      error("claude-providers: not running inside kitty or tmux")
    end
  end

  if provider_name == "kitty" then
    kitty.setup(config)
    active_provider = kitty
  else
    tmux.setup(config)
    active_provider = tmux
  end

  return active_provider
end

--- Get the current configuration
--- @return table config
function M.get_config()
  if active_provider then return active_provider.get_config() end
  return defaults
end

--- Check if any supported terminal provider is available
--- @return boolean
function M.is_available()
  return kitty.is_available() or tmux.is_available()
end

return M
