# T-Ruby for Neovim - Getting Started

Welcome to T-Ruby for Neovim! This guide covers setting up T-Ruby with full LSP support, syntax highlighting, and advanced features in Neovim.

## Prerequisites

Before installation, ensure you have:

- **Neovim** 0.8.0 or higher (0.9+ recommended for best LSP support)
- **Ruby** 3.0 or higher
- **T-Ruby Compiler** (`trc`) installed and in PATH

### Installing T-Ruby Compiler

```bash
# Install via gem (recommended)
gem install t-ruby

# Or build from source
git clone https://github.com/type-ruby/t-ruby.git
cd t-ruby
bundle install
rake install
```

Verify installation:
```bash
trc --version
```

## Installation

### Method 1: Using lazy.nvim (Recommended)

Add to your `~/.config/nvim/lua/plugins/t-ruby.lua`:

```lua
return {
  "type-ruby/t-ruby",
  ft = { "truby" },
  config = function()
    require("t-ruby-lsp").setup()
    require("t-ruby-lsp").create_commands()
  end,
}
```

### Method 2: Using packer.nvim

Add to your `~/.config/nvim/lua/plugins.lua`:

```lua
use {
  'type-ruby/t-ruby',
  ft = { 'truby' },
  config = function()
    require('t-ruby-lsp').setup()
    require('t-ruby-lsp').create_commands()
  end
}
```

### Method 3: Manual Installation

```bash
# Clone repository
git clone https://github.com/type-ruby/t-ruby.git

# Copy Vim plugin files
cp -r t-ruby/editors/vim/* ~/.config/nvim/

# Copy Neovim Lua configuration
mkdir -p ~/.config/nvim/lua
cp t-ruby/editors/nvim/lua/t-ruby-lsp.lua ~/.config/nvim/lua/
```

Then add to your `init.lua`:

```lua
require('t-ruby-lsp').setup()
require('t-ruby-lsp').create_commands()
```

## LSP Configuration

### With nvim-lspconfig (Recommended)

If you use `nvim-lspconfig`, the T-Ruby LSP integrates seamlessly:

```lua
-- In your LSP configuration file
require('t-ruby-lsp').setup({
  cmd = { "trc", "--lsp" },
  filetypes = { "truby" },
  settings = {},
})
```

### Manual LSP Setup (without nvim-lspconfig)

For a minimal setup without additional plugins:

```lua
require('t-ruby-lsp').setup_manual()
```

### With coc.nvim

If you prefer coc.nvim, add to `:CocConfig`:

```json
{
  "languageserver": {
    "t-ruby": {
      "command": "trc",
      "args": ["--lsp"],
      "filetypes": ["truby"],
      "rootPatterns": [".trb.yml", ".git/"]
    }
  }
}
```

## Features

### LSP Features

With LSP enabled, you get:

- **Autocomplete**: Intelligent type suggestions
- **Hover**: View type information (`K` by default)
- **Go to Definition**: Jump to type/function definitions (`gd`)
- **Diagnostics**: Real-time error checking
- **Document Symbols**: Navigate symbols in file

### Syntax Highlighting

Full highlighting for:
- Type aliases and interfaces
- Function definitions with type annotations
- Union, intersection, and generic types
- T-Ruby keywords and built-in types

### User Commands

After calling `create_commands()`:

| Command | Description |
|---------|-------------|
| `:TRubyCompile` | Compile current file |
| `:TRubyDecl` | Generate declaration file |
| `:TRubyLspInfo` | Check LSP status |

## Configuration Options

```lua
require('t-ruby-lsp').setup({
  -- Path to T-Ruby compiler
  cmd = { "trc", "--lsp" },

  -- File types to activate
  filetypes = { "truby", "trb" },

  -- Root directory detection
  root_dir = function(fname)
    return vim.fn.getcwd()
  end,

  -- LSP settings
  settings = {},
})
```

## Key Mappings

Recommended key mappings for T-Ruby (add to your config):

```lua
-- T-Ruby specific mappings
vim.api.nvim_create_autocmd("FileType", {
  pattern = "truby",
  callback = function()
    local opts = { buffer = true, silent = true }

    -- Compile current file
    vim.keymap.set("n", "<leader>tc", ":TRubyCompile<CR>", opts)

    -- Generate declaration
    vim.keymap.set("n", "<leader>td", ":TRubyDecl<CR>", opts)

    -- LSP mappings (if using native LSP)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
  end,
})
```

## Quick Start Example

1. Create `hello.trb`:

```ruby
type UserId = String

interface User
  id: UserId
  name: String
  age: Integer
end

def greet(user: User): String
  "Hello, #{user.name}!"
end
```

2. Open in Neovim:
```bash
nvim hello.trb
```

3. Try these features:
   - Hover over `User` and press `K` to see type info
   - Press `gd` on `UserId` to go to its definition
   - Type `:` after a parameter name for autocomplete
   - Save the file to see diagnostics

4. Compile:
```vim
:TRubyCompile
```

## Integration with Popular Plugins

### With nvim-cmp (Completion)

The LSP completions integrate automatically with nvim-cmp:

```lua
-- In your nvim-cmp config
sources = cmp.config.sources({
  { name = 'nvim_lsp' },
  -- T-Ruby completions will appear through LSP
})
```

### With telescope.nvim

```lua
-- Find T-Ruby files
vim.keymap.set("n", "<leader>ft", function()
  require("telescope.builtin").find_files({
    find_command = { "fd", "-e", "trb" }
  })
end)
```

### With trouble.nvim

Diagnostics integrate automatically with trouble.nvim:

```vim
:Trouble diagnostics
```

## Troubleshooting

### LSP not starting

1. Check if `trc` is available:
```vim
:!trc --version
```

2. Check LSP status:
```vim
:TRubyLspInfo
```

3. View LSP logs:
```vim
:lua vim.cmd('e ' .. vim.lsp.get_log_path())
```

### No syntax highlighting

1. Check filetype:
```vim
:set filetype?
```

2. Set manually if needed:
```vim
:set filetype=truby
```

3. Ensure syntax files are loaded:
```vim
:echo globpath(&rtp, 'syntax/truby.vim')
```

### Completion not working

1. Verify LSP is attached:
```vim
:lua print(vim.inspect(vim.lsp.get_active_clients()))
```

2. Check for errors:
```vim
:lua print(vim.inspect(vim.diagnostic.get()))
```

## Next Steps

- [Syntax Highlighting Guide](../../syntax-highlighting/en/guide.md)
- [Vim Setup](../../vim/en/getting-started.md) (basic Vim without LSP)
- [T-Ruby Language Reference](https://github.com/type-ruby/t-ruby/wiki)

## Support

For questions and bug reports:
- GitHub Issues: https://github.com/type-ruby/t-ruby/issues
- Discussions: https://github.com/type-ruby/t-ruby/discussions
