# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

claude-tmux.nvim is a Neovim plugin that provides a tmux terminal provider for [claudecode.nvim](https://github.com/coder/claudecode.nvim). It opens Claude Code in a tmux split instead of using Neovim's built-in terminal.

## Development

This is a pure Lua Neovim plugin — no build step, no tests, no linter configured. To test changes, load the plugin in Neovim with claudecode.nvim inside a tmux session.

## Architecture

The entire plugin lives in a single file: `lua/claude-tmux/init.lua`.

**Module structure within the file:**
- **`state` table** — mutable state tracking pane IDs, config, and hidden status
- **Private helper functions** — `tmux_cmd()` for shell interaction, `pane_exists()`/`is_pane_focused()` for state queries, `hide_pane()`/`show_pane()` for visibility, `vim_key_to_tmux()` for key notation conversion, `setup_return_binding()`/`remove_return_binding()` for conditional tmux keybindings
- **`provider` table** — implements the claudecode.nvim terminal provider interface (`open`, `close`, `hide`, `show`, `simple_toggle`, `focus_toggle`, `toggle`, `is_available`, `get_active_bufnr`)
- **`M` (public API)** — `setup(opts)` returns the provider table, `get_config()`, `is_available()`

**Key design decisions:**
- Uses `io.popen()` to execute tmux CLI commands (not Neovim jobs)
- Toggle key creates a conditional tmux binding via `if-shell` that only activates in the Claude pane
- `get_active_bufnr()` returns `nil` since the terminal is external to Neovim
- Hide/show resizes the pane to 1 line / configured percentage rather than destroying it
- `split_side` config controls orientation: `"bottom"` uses `-v` (horizontal split), `"right"` uses `-h` (vertical split); hide/show resize on the matching axis (`-y` / `-x`)

## Code Conventions

- Private functions are module-local (not on `M` or `provider`)
- Test helpers prefixed with `_` (e.g., `_get_terminal_for_test`)
- Shell values escaped with `'\\''` single-quote pattern
- LDoc-style annotations (`@param`, `@return`) on public API functions