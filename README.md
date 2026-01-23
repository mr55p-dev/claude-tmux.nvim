# claude-tmux.nvim

A tmux terminal provider for [claudecode.nvim](https://github.com/coder/claudecode.nvim). Opens Claude Code in a tmux split at the bottom of your window instead of using Neovim's built-in terminal.

## Requirements

- Neovim 0.8+
- [claudecode.nvim](https://github.com/coder/claudecode.nvim)
- tmux (must be running inside a tmux session)

## Installation

### lazy.nvim

```lua
{
  "mr55p-dev/claude-tmux.nvim",
  dependencies = {
    "coder/claudecode.nvim",
  },
}
```

### packer.nvim

```lua
use {
  "mr55p-dev/claude-tmux.nvim",
  requires = { "coder/claudecode.nvim" },
}
```

## Setup

```lua
local tmux_provider = require("claude-tmux").setup({
  toggle_key = "<C-j>",  -- Key to return to neovim (default: "<C-j>")
  split_size = 30,       -- Split height as percentage (default: 30)
})

require("claudecode").setup({
  -- your other claudecode options...
  terminal = {
    provider = tmux_provider,
  },
})
```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `toggle_key` | string | `"<C-j>"` | Key binding to return to Neovim from the Claude pane. Uses Vim key notation. Set to `nil` to disable. |
| `split_size` | number | `30` | Height of the tmux split as a percentage of the window. |

### Supported Key Notations

The `toggle_key` option accepts standard Vim key notation:

- Control keys: `<C-j>`, `<C-k>`, etc.
- Alt/Meta keys: `<M-j>`, `<A-j>`, etc.
- Function keys: `<F1>`, `<F12>`, etc.
- Special keys: `<CR>`, `<Tab>`, `<Space>`, `<Esc>`

## How It Works

1. When you open Claude Code, the plugin creates a new tmux pane at the bottom of your current window
2. A conditional keybinding is set up so that pressing the toggle key (default `<C-j>`) while in the Claude pane switches back to Neovim
3. The keybinding only affects the Claude pane - in other panes, the key passes through normally
4. When the Claude terminal is closed, the keybinding is automatically cleaned up

## API

### `require("claude-tmux").setup(opts)`

Initialize the provider with the given options. Returns the provider table to pass to claudecode.nvim.

### `require("claude-tmux").is_available()`

Returns `true` if running inside tmux, `false` otherwise. Useful for conditional setup.

### `require("claude-tmux").get_config()`

Returns the current configuration table.

## Example: Conditional Provider

If you want to use the tmux provider when available, but fall back to the default terminal otherwise:

```lua
local claude_tmux = require("claude-tmux")

local terminal_config = {}
if claude_tmux.is_available() then
  terminal_config.provider = claude_tmux.setup({
    toggle_key = "<C-j>",
    split_size = 25,
  })
end

require("claudecode").setup({
  terminal = terminal_config,
})
```

## Troubleshooting

### "Provider not available"

Make sure you're running Neovim inside a tmux session. The plugin checks for the `$TMUX` environment variable.

### Toggle key not working

1. Verify you're in the Claude pane (not another tmux pane)
2. Check that the key notation is correct (e.g., `<C-j>` not `Ctrl-j`)
3. Ensure no other tmux bindings are conflicting with your chosen key

### Split appears but command doesn't run

Check that Claude Code CLI is installed and available in your PATH.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

### Development

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test with claudecode.nvim
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Style

- Follow existing code patterns
- Add comments for non-obvious logic
- Test changes with both tmux and non-tmux environments

## License

MIT License - see [LICENSE](LICENSE) for details.