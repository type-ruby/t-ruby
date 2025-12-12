# T-Ruby for Vim - Getting Started

Welcome to T-Ruby for Vim! This guide will help you set up T-Ruby syntax highlighting and integration in Vim.

## Prerequisites

Before installing the plugin, ensure you have:

- **Vim** 8.0 or higher (with `+syntax` feature)
- **Ruby** 3.0 or higher (optional, for compilation)
- **T-Ruby Compiler** (`trc`) for compilation features

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

## Installation

### Method 1: Using vim-plug (Recommended)

Add to your `~/.vimrc`:

```vim
call plug#begin('~/.vim/plugged')

Plug 'type-ruby/t-ruby', { 'rtp': 'editors/vim' }

call plug#end()
```

Then run:
```vim
:PlugInstall
```

### Method 2: Using Vundle

Add to your `~/.vimrc`:

```vim
Plugin 'type-ruby/t-ruby', { 'rtp': 'editors/vim' }
```

Then run:
```vim
:PluginInstall
```

### Method 3: Using Pathogen

```bash
cd ~/.vim/bundle
git clone https://github.com/type-ruby/t-ruby.git
```

### Method 4: Manual Installation

```bash
# Clone the repository
git clone https://github.com/type-ruby/t-ruby.git

# Copy plugin files to your Vim directory
cp -r t-ruby/editors/vim/* ~/.vim/
```

Or for specific directories:
```bash
cp t-ruby/editors/vim/syntax/truby.vim ~/.vim/syntax/
cp t-ruby/editors/vim/ftdetect/truby.vim ~/.vim/ftdetect/
cp t-ruby/editors/vim/ftplugin/truby.vim ~/.vim/ftplugin/
```

## Verification

After installation, verify the plugin is working:

1. Create a file with `.trb` extension
2. Open it in Vim
3. Run `:set filetype?` - should show `filetype=truby`

## Features

### Syntax Highlighting

The plugin provides syntax highlighting for:
- Type aliases (`type Name = Type`)
- Interface definitions (`interface Name ... end`)
- Function definitions with type annotations
- Union types (`String | Integer`)
- Generic types (`Array<String>`)
- Intersection types (`Readable & Writable`)

### File Type Detection

Automatic detection for:
- `.trb` files - T-Ruby source files
- `.d.trb` files - T-Ruby declaration files

### Key Mappings

Default key mappings (in normal mode):

| Key | Action |
|-----|--------|
| `<leader>tc` | Compile current file |
| `<leader>td` | Generate declaration file |

### Indentation

Ruby-compatible indentation:
- 2 spaces per indent level
- Automatic indent after `def`, `interface`, `class`, etc.
- Auto-dedent on `end`

### Folding

Code folding is supported:
- Fold by indent level
- Use `za` to toggle fold
- Use `zR` to open all folds
- Use `zM` to close all folds

## Configuration

Add to your `~/.vimrc` for customization:

```vim
" Set custom leader key (default is \)
let mapleader = ","

" Custom T-Ruby settings
augroup truby_settings
  autocmd!
  " Use 4 spaces instead of 2
  autocmd FileType truby setlocal shiftwidth=4 softtabstop=4

  " Enable spell checking in comments
  autocmd FileType truby setlocal spell

  " Set custom compiler
  autocmd FileType truby setlocal makeprg=/path/to/trc\ %
augroup END

" Custom key mappings
autocmd FileType truby nnoremap <buffer> <F5> :!trc %<CR>
autocmd FileType truby nnoremap <buffer> <F6> :!trc --decl %<CR>
```

## Quick Start Example

1. Create a file `hello.trb`:

```bash
vim hello.trb
```

2. Enter the following code:

```trb
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

3. You should see:
   - `type`, `interface`, `def`, `end` highlighted as keywords
   - Type names (`UserId`, `User`, `String`, `Integer`) highlighted as types
   - Proper indentation when pressing Enter

4. Compile with `<leader>tc` or `:!trc %`

## Troubleshooting

### No syntax highlighting

1. Check filetype: `:set filetype?`
2. Manually set filetype: `:set filetype=truby`
3. Verify syntax file exists: `:echo globpath(&rtp, 'syntax/truby.vim')`

### Wrong file type detected

Add to `~/.vimrc`:
```vim
autocmd BufRead,BufNewFile *.trb set filetype=truby
autocmd BufRead,BufNewFile *.d.trb set filetype=truby
```

### Key mappings not working

1. Check your leader key: `:echo mapleader`
2. Verify mappings: `:map <leader>tc`
3. Check for conflicts: `:verbose map <leader>tc`

### Compilation errors

1. Verify `trc` is in PATH: `:!which trc`
2. Check makeprg setting: `:set makeprg?`
3. Test manually: `:!trc --version`

## Integration with Other Plugins

### With ALE (Asynchronous Lint Engine)

```vim
" Add T-Ruby linter
let g:ale_linters = {
\   'truby': ['trc'],
\}
```

### With vim-polyglot

The T-Ruby plugin is compatible with vim-polyglot. If both are installed, T-Ruby settings will take precedence for `.trb` files.

## Next Steps

- [Syntax Highlighting Guide](../../syntax-highlighting/en/guide.md)
- [Neovim Setup](../../neovim/en/getting-started.md) (for LSP support)
- [T-Ruby Language Reference](https://github.com/type-ruby/t-ruby/wiki)

## Support

For questions and bug reports:
- GitHub Issues: https://github.com/type-ruby/t-ruby/issues
- Discussions: https://github.com/type-ruby/t-ruby/discussions
