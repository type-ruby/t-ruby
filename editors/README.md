# T-Ruby Editor Integration

This directory contains editor plugins and configurations for T-Ruby language support.

## VS Code Extension

### Installation

1. Navigate to the `vscode` directory
2. Run `npm install` to install dependencies
3. Run `npm run compile` to build the extension
4. Copy the entire folder to your VS Code extensions directory:
   - Windows: `%USERPROFILE%\.vscode\extensions\`
   - macOS/Linux: `~/.vscode/extensions/`

Or install from source:
```bash
cd editors/vscode
npm install
npm run compile
code --install-extension .
```

### Features

- Syntax highlighting for `.trb` and `.d.trb` files
- LSP integration with autocomplete, hover, and diagnostics
- Commands:
  - `T-Ruby: Compile Current File` - Compile the current `.trb` file
  - `T-Ruby: Generate Declaration File` - Generate `.d.trb` file
  - `T-Ruby: Restart Language Server` - Restart the LSP server

### Configuration

```json
{
  "t-ruby.lspPath": "trc",
  "t-ruby.enableLSP": true,
  "t-ruby.diagnostics.enable": true,
  "t-ruby.completion.enable": true
}
```

## Vim/Neovim

### Installation

Copy the vim plugin files to your Vim configuration:

```bash
# For Vim
cp -r editors/vim/* ~/.vim/

# For Neovim
cp -r editors/vim/* ~/.config/nvim/
```

Or use a plugin manager like vim-plug:

```vim
" In your .vimrc or init.vim
Plug 'type-ruby/t-ruby', { 'rtp': 'editors/vim' }
```

### Features

- Syntax highlighting based on Ruby with T-Ruby extensions
- Filetype detection for `.trb` and `.d.trb` files
- Proper indentation and folding
- Key mappings:
  - `<leader>tc` - Compile current file
  - `<leader>td` - Generate declaration file

## Neovim with Native LSP

### Installation

Copy the Lua configuration to your Neovim config:

```bash
cp editors/nvim/lua/t-ruby-lsp.lua ~/.config/nvim/lua/
```

### Configuration with nvim-lspconfig

Add to your `init.lua`:

```lua
-- Basic setup with nvim-lspconfig
require("t-ruby-lsp").setup()

-- Or with custom configuration
require("t-ruby-lsp").setup({
    cmd = { "/path/to/trc", "--lsp" },
    settings = {},
})

-- Create user commands
require("t-ruby-lsp").create_commands()
```

### Manual Setup (without nvim-lspconfig)

```lua
require("t-ruby-lsp").setup_manual()
require("t-ruby-lsp").create_commands()
```

### User Commands

- `:TRubyCompile` - Compile current T-Ruby file
- `:TRubyDecl` - Generate declaration file
- `:TRubyLspInfo` - Check LSP status

## Neovim with coc.nvim

Add the contents of `nvim/coc-settings.json` to your coc-settings:

```json
{
  "languageserver": {
    "t-ruby": {
      "command": "trc",
      "args": ["--lsp"],
      "filetypes": ["truby"],
      "rootPatterns": ["trbconfig.yml", ".git/"]
    }
  }
}
```

## Prerequisites

All editor integrations require the T-Ruby compiler (`trc`) to be installed and available in your PATH:

```bash
# Install T-Ruby
gem install t-ruby

# Or build from source
cd /path/to/t-ruby
bundle install
rake install
```

Verify installation:
```bash
trc --version
```

## Troubleshooting

### LSP not starting

1. Verify `trc` is in your PATH: `which trc`
2. Test LSP manually: `echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | trc --lsp`
3. Check editor output/logs for error messages

### Syntax highlighting not working

1. Ensure the plugin files are in the correct location
2. Run `:set filetype?` in Vim to check detected filetype
3. Try `:set filetype=truby` manually

### Performance issues

- The LSP server performs full document sync
- For large files, consider disabling real-time diagnostics temporarily
