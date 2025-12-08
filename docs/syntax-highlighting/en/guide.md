# T-Ruby Syntax Highlighting Guide

This guide explains how to set up and customize syntax highlighting for T-Ruby in various editors.

## Overview

T-Ruby syntax highlighting provides visual distinction for:

- **Keywords**: `type`, `interface`, `def`, `end`
- **Types**: `String`, `Integer`, `Boolean`, `Array`, `Hash`, etc.
- **Type Annotations**: Parameter and return type declarations
- **Type Operators**: `|` (union), `&` (intersection), `<>` (generics)
- **Comments**: `#` single-line comments
- **Strings**: Both single and double-quoted
- **Numbers**: Integers and floats
- **Symbols**: `:symbol_name`

## Highlighted Elements

### Type Aliases

```ruby
type UserId = String           # 'type' keyword, 'UserId' as type name
type Age = Integer             # '=' operator, built-in type
type UserMap = Hash<UserId, User>  # Generic type
```

### Interfaces

```ruby
interface Printable            # 'interface' keyword, interface name
  to_string: String           # Member name, type annotation
  print: void
end                           # 'end' keyword
```

### Functions with Type Annotations

```ruby
def greet(name: String): String    # Function name, param with type, return type
  "Hello, #{name}!"
end

def process(items: Array<String>, count: Integer): Hash<String, Integer>
  # Generic types are highlighted
end
```

### Union and Intersection Types

```ruby
type StringOrInt = String | Integer    # Union type with '|'
type ReadWrite = Readable & Writable   # Intersection type with '&'
type MaybeString = String | nil        # Nullable type
```

## Editor-Specific Setup

### VS Code

The VS Code extension automatically provides syntax highlighting. Install it from:
- VS Code Marketplace: Search "T-Ruby"
- Or manually from the `editors/vscode` directory

**Theme Customization:**

Add to your `settings.json`:

```json
{
  "editor.tokenColorCustomizations": {
    "[Your Theme]": {
      "textMateRules": [
        {
          "scope": "keyword.declaration.type.t-ruby",
          "settings": {
            "foreground": "#C678DD"
          }
        },
        {
          "scope": "entity.name.type.t-ruby",
          "settings": {
            "foreground": "#E5C07B"
          }
        },
        {
          "scope": "support.type.builtin.t-ruby",
          "settings": {
            "foreground": "#56B6C2"
          }
        }
      ]
    }
  }
}
```

### Vim/Neovim

Copy syntax files to your configuration:

```bash
# Vim
cp editors/vim/syntax/truby.vim ~/.vim/syntax/
cp editors/vim/ftdetect/truby.vim ~/.vim/ftdetect/

# Neovim
cp editors/vim/syntax/truby.vim ~/.config/nvim/syntax/
cp editors/vim/ftdetect/truby.vim ~/.config/nvim/ftdetect/
```

**Color Customization:**

Add to your `~/.vimrc` or `init.vim`:

```vim
" Custom T-Ruby highlighting colors
augroup truby_colors
  autocmd!
  autocmd ColorScheme * highlight tRubyKeyword ctermfg=176 guifg=#C678DD
  autocmd ColorScheme * highlight tRubyTypeName ctermfg=180 guifg=#E5C07B
  autocmd ColorScheme * highlight tRubyBuiltinType ctermfg=73 guifg=#56B6C2
  autocmd ColorScheme * highlight tRubyInterface ctermfg=114 guifg=#98C379
augroup END
```

For Neovim with Lua:

```lua
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "tRubyKeyword", { fg = "#C678DD" })
    vim.api.nvim_set_hl(0, "tRubyTypeName", { fg = "#E5C07B" })
    vim.api.nvim_set_hl(0, "tRubyBuiltinType", { fg = "#56B6C2" })
  end,
})
```

## Syntax Groups Reference

### VS Code TextMate Scopes

| Element | Scope |
|---------|-------|
| `type`, `interface` keywords | `keyword.declaration.type.t-ruby` |
| Type names | `entity.name.type.t-ruby` |
| Built-in types | `support.type.builtin.t-ruby` |
| Function names | `entity.name.function.t-ruby` |
| Parameters | `variable.parameter.t-ruby` |
| Type operators (`\|`, `&`) | `keyword.operator.type.t-ruby` |
| Generic brackets | `punctuation.definition.generic.t-ruby` |

### Vim Highlight Groups

| Element | Group |
|---------|-------|
| Keywords | `tRubyKeyword` |
| Type names | `tRubyTypeName` |
| Built-in types | `tRubyBuiltinType` |
| Interfaces | `tRubyInterface` |
| Interface members | `tRubyInterfaceMember` |
| Type annotations | `tRubyTypeAnnotation` |
| Return types | `tRubyReturnType` |
| Type operators | `tRubyTypeOperator` |

## Example Files

### Simple Example

```ruby
# simple.trb - Basic T-Ruby syntax

type UserId = String
type Score = Integer

def get_score(user_id: UserId): Score
  100
end
```

### Complex Example

```ruby
# complex.trb - Advanced T-Ruby syntax

type UserId = String
type Email = String
type Timestamp = Integer

interface Identifiable
  id: UserId
end

interface Timestamped
  created_at: Timestamp
  updated_at: Timestamp
end

interface User
  id: UserId
  name: String
  email: Email
  age: Integer | nil
  roles: Array<String>
  metadata: Hash<String, String>
end

type UserWithTimestamp = User & Timestamped

def create_user(name: String, email: Email): User
  # Implementation
end

def find_user(id: UserId): User | nil
  # Implementation
end

def get_users_by_role(role: String): Array<User>
  # Implementation
end
```

## Troubleshooting

### Highlighting Not Applied

1. **Check file extension**: Must be `.trb` or `.d.trb`
2. **Verify filetype detection**:
   - VS Code: Check bottom-right status bar
   - Vim: Run `:set filetype?`
3. **Check syntax file is loaded**:
   - Vim: `:echo exists("g:truby_syntax_loaded")`

### Wrong Colors

1. **Check color scheme compatibility**
2. **Verify highlight group links**:
   - Vim: `:highlight tRubyKeyword`
3. **Override with custom colors** (see above)

### Partial Highlighting

1. **Complex nested types** may require syntax reload:
   - Vim: `:syntax sync fromstart`
2. **Check for syntax errors** that break parsing

## Integration with Themes

### One Dark Theme

The T-Ruby syntax is designed to work well with One Dark and similar themes:

| Element | One Dark Color |
|---------|---------------|
| Keywords | `#C678DD` (purple) |
| Types | `#E5C07B` (yellow) |
| Built-in types | `#56B6C2` (cyan) |
| Functions | `#61AFEF` (blue) |
| Strings | `#98C379` (green) |

### Dracula Theme

| Element | Dracula Color |
|---------|--------------|
| Keywords | `#FF79C6` (pink) |
| Types | `#8BE9FD` (cyan) |
| Functions | `#50FA7B` (green) |
| Strings | `#F1FA8C` (yellow) |

## Next Steps

- [VS Code Setup](../../vscode/en/getting-started.md)
- [Vim Setup](../../vim/en/getting-started.md)
- [Neovim Setup](../../neovim/en/getting-started.md)

## Support

For syntax highlighting issues:
- GitHub Issues: https://github.com/type-ruby/t-ruby/issues
- Include your editor version and theme name when reporting
