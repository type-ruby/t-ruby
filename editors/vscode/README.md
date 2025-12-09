# T-Ruby for Visual Studio Code

TypeScript-style type annotations for Ruby.

## Features

- **Syntax Highlighting** - Full support for `.trb` and `.d.trb` files
- **IntelliSense** - Autocomplete for types, methods, and variables
- **Diagnostics** - Real-time type error reporting
- **Go to Definition** - Jump to type and method definitions
- **Hover Information** - See type information on hover
- **Find References** - Find all usages of types and methods

## Requirements

- [T-Ruby compiler](https://github.com/anthropics/t-ruby) (`trc`) must be installed and available in your PATH

```bash
gem install t-ruby
```

## Quick Start

1. Install the extension
2. Open a `.trb` file
3. Start coding with types!

```ruby
# hello.trb
def greet(name: String): String
  "Hello, #{name}!"
end

type User = { name: String, age: Integer }

interface Printable
  def print(): void
end
```

## Extension Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `t-ruby.lspPath` | `trc` | Path to the T-Ruby compiler executable |
| `t-ruby.enableLSP` | `true` | Enable Language Server Protocol support |
| `t-ruby.diagnostics.enable` | `true` | Enable real-time diagnostics |
| `t-ruby.completion.enable` | `true` | Enable autocomplete suggestions |

## Commands

- **T-Ruby: Compile Current File** - Compile the active `.trb` file to `.rb`
- **T-Ruby: Generate Declaration File** - Generate `.d.trb` declaration file
- **T-Ruby: Restart Language Server** - Restart the LSP server

## Learn More

- [T-Ruby Documentation](https://github.com/anthropics/t-ruby)
- [Language Specification](https://github.com/anthropics/t-ruby/blob/main/.claude/spec/README.md)

## License

MIT
