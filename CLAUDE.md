# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

claude-providers.nvim is a Neovim plugin that provides terminal providers for [claudecode.nvim](https://github.com/coder/claudecode.nvim). It opens Claude Code in a tmux or kitty split instead of using Neovim's built-in terminal.

## Development

This is a pure Lua Neovim plugin — no build step, no tests, no linter configured. To test changes, load the plugin in Neovim with claudecode.nvim inside a tmux or kitty session.

## Architecture

The plugin lives in `lua/claude-providers/`:

- **`init.lua`** — public API and provider selection
- **`tmux.lua`** — tmux provider implementation
- **`kitty.lua`** — kitty provider implementation

### `init.lua`

Requires both provider modules and exposes:
- `M.setup(opts)` — merges opts with defaults, selects provider (`"auto"` detects kitty then tmux), calls `provider.setup(config)`, returns the provider table for claudecode.nvim
- `M.get_config()` — delegates to the active provider
- `M.is_available()` — true if either provider is available

### `tmux.lua` / `kitty.lua`

Each provider file is self-contained with:
- **`state` table** — mutable state: terminal ID, neovim terminal ID, config, hidden flag; kitty also saves window size before hiding
- **Private helper functions** — shell command runner, terminal existence/focus checks, hide/show logic
- **`provider` table** — implements the claudecode.nvim terminal provider interface

**Provider interface** (both providers implement all of these):
`setup`, `get_config`, `is_available`, `open`, `close`, `hide`, `show`, `is_hidden`, `simple_toggle`, `focus_toggle`, `toggle`, `get_active_bufnr`, `_get_terminal_for_test`

### Key design decisions

**Shared:**
- Uses `io.popen()` to execute shell commands (not Neovim jobs)
- `get_active_bufnr()` returns `nil` since terminals are external to Neovim
- Hide/show resizes the terminal to 1 line/column and back, rather than destroying it
- `split_side = "bottom"` uses a horizontal split (new pane below); `"right"` uses a vertical split (new pane to the right)

**tmux:**
- Terminal identified by pane ID (e.g. `%3`)
- `toggle_key` creates a conditional tmux binding via `if-shell` that only activates when the Claude pane is focused, passing the key through otherwise
- Hide/show uses `tmux resize-pane` with `-y`/`-x` flags and absolute `%` sizing

**kitty:**
- Terminal identified by window ID (integer)
- `toggle_key` is not supported — kitty has no runtime keybinding API; use kitty's built-in window navigation to return to neovim
- Requires `allow_remote_control yes` in `kitty.conf` (or kitty launched with `--listen-on`)
- Hide/show uses `kitty @ resize-window` with incremental sizing; the window size is saved before hiding and restored on show
- Split size uses `kitty @ launch --bias=N`; focus tracking parses `kitty @ ls` JSON

## Code Conventions

- Private functions are module-local (not on `provider`)
- Test helpers prefixed with `_` (e.g., `_get_terminal_for_test`)
- Shell values escaped with `'\\''` single-quote pattern
- LDoc-style annotations (`@param`, `@return`) on public API functions in `init.lua`
