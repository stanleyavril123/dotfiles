# Neovim Config

<p align="center">
  <img src="assets/screenshot-dashboard.png" alt="Alpha Dashboard" width="700"/>
</p>

<p align="center">
  <img src="assets/screenshot-editor.png" alt="Editor" width="700"/>
</p>

A Lua-based Neovim configuration focused on project navigation, diagnostics, repeatable tooling, Git review, and external coding-agent workflows.

## Requirements

- Neovim 0.10 or newer; Neovim 0.11+ is recommended
- Git, Make, Node.js, Python 3, and ripgrep
- A Nerd Font configured in the terminal (for example, JetBrainsMono Nerd Font)
- tmux is optional

## Installation

```bash
git clone https://github.com/stanleyavril123/nvim-config.git ~/.config/nvim
nvim
```

Lazy installs plugins and Mason installs the declared language servers and formatters automatically.

## Main Features

- Plugin management with lazy.nvim
- Catppuccin Mocha UI with coordinated dashboard, statusline, pickers, and popups
- Diagnostic-aware buffer tabs and scope-aware indentation guides
- LSP servers and external tools managed by Mason
- Deterministic formatting and format-on-save with conform.nvim
- Treesitter highlighting and indentation
- Telescope project navigation and search
- Trouble diagnostics and quickfix views
- Overseer project tasks and test commands
- Neo-tree file explorer
- Gitsigns, Neogit, and Diffview for reviewing changes
- Persistent undo and automatic detection of files changed by external agents
- Discoverable mappings through which-key.nvim
- Native inline previews for Codex edits

## Keymaps

Leader is `Space`.

| Mapping                     | Action                         |
| --------------------------- | ------------------------------ |
| `<C-p>` / `<leader>sf`      | Find files                     |
| `<leader>sg`                | Live grep project              |
| `<leader>sw`                | Grep word under cursor         |
| `<leader>sb`                | Search current buffer          |
| `<leader>sd`                | Search diagnostics             |
| `<leader>gc`                | Find changed Git files         |
| `<leader>gf`                | Format file or selection       |
| `<leader>xx`                | Workspace diagnostics          |
| `<leader>xb`                | Buffer diagnostics             |
| `<leader>xq`                | Quickfix list                  |
| `<leader>rr`                | Select and run a project task  |
| `<leader>rl`                | Run the last task              |
| `<leader>rt`                | Toggle task list               |
| `<S-h>` / `<S-l>`           | Previous or next buffer        |
| `<leader>bp`                | Pick a visible buffer          |
| `<leader>bd`                | Close buffer with confirmation |
| `<C-n>`                     | Toggle file explorer           |
| `<leader>gg`                | Open Neogit                    |
| `<leader>gd`                | Open Diffview                  |
| `]h` / `[h`                 | Next or previous Git hunk      |
| `]d` / `[d`                 | Next or previous diagnostic    |

Use `:Mason`, `:ConformInfo`, `:OverseerRun`, and `:checkhealth` when diagnosing tooling.

## Structure

```text
~/.config/nvim/
├── init.lua
└── lua/
    ├── config/
    │   ├── autocmds.lua
    │   ├── keymaps.lua
    │   └── options.lua
    └── plugins/
        ├── formatting.lua
        ├── lsp-config.lua
        ├── telescope.lua
        ├── tooling.lua
        ├── workflow.lua
        └── ...
```

## Compatibility

The current machine uses Neovim 0.10, so Mason is pinned to v1 and Overseer uses its `nvim-0.7` compatibility branch. After upgrading Neovim to 0.11+, those compatibility pins can be removed and the LSP configuration can move to the native `vim.lsp.config` API.

## License

MIT - see [LICENSE](LICENSE).
