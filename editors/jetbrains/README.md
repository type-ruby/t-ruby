# T-Ruby JetBrains Plugin

[![JetBrains Marketplace](https://img.shields.io/jetbrains/plugin/v/29335-t-ruby.svg)](https://plugins.jetbrains.com/plugin/29335-t-ruby)

T-Ruby language support for JetBrains IDEs (RubyMine, IntelliJ IDEA, WebStorm, etc.).

## Features

- **Syntax Highlighting**: Full syntax highlighting for `.trb` and `.d.trb` files
- **Code Completion**: Type-aware autocomplete suggestions
- **Real-time Diagnostics**: Inline type error reporting
- **Go to Definition**: Navigate to type and function definitions
- **Hover Information**: View type information on hover
- **Compile Command**: Compile T-Ruby files to Ruby directly from the IDE

## Requirements

- JetBrains IDE 2024.2 or later
- [LSP4IJ plugin](https://plugins.jetbrains.com/plugin/23257-lsp4ij) installed
- T-Ruby compiler (`trc`) installed and available in PATH

### Installing T-Ruby Compiler

```bash
gem install t-ruby
```

## Installation

### From JetBrains Marketplace

1. Open your JetBrains IDE
2. Go to **Settings** → **Plugins** → **Marketplace**
3. Search for "T-Ruby"
4. Click **Install**

### Manual Installation

1. Download the latest `.zip` from [Releases](https://github.com/type-ruby/t-ruby/releases)
2. Go to **Settings** → **Plugins** → **⚙️** → **Install Plugin from Disk...**
3. Select the downloaded `.zip` file

## Usage

### Creating T-Ruby Files

Create a new file with `.trb` extension:

```ruby
# example.trb
type UserId = Integer

def greet(name: String): String
  "Hello, #{name}!"
end

def find_user(id: UserId): User | nil
  # ...
end
```

### Compiling

- **Keyboard**: `Ctrl+Shift+T` (or `Cmd+Shift+T` on macOS)
- **Menu**: **Tools** → **T-Ruby** → **Compile T-Ruby File**
- **Context Menu**: Right-click on a `.trb` file → **Compile T-Ruby File**

### Generating Declaration Files

- **Keyboard**: `Ctrl+Shift+D` (or `Cmd+Shift+D` on macOS)
- **Menu**: **Tools** → **T-Ruby** → **Generate Declaration File**

## Configuration

Go to **Settings** → **Tools** → **T-Ruby**:

| Setting | Description | Default |
|---------|-------------|---------|
| T-Ruby compiler path | Path to `trc` executable | `trc` (from PATH) |
| Enable LSP | Enable Language Server Protocol features | `true` |
| Enable diagnostics | Show real-time type errors | `true` |
| Enable completion | Enable code completion | `true` |

## Supported IDEs

- RubyMine 2024.2+
- IntelliJ IDEA 2024.2+ (Ultimate & Community)
- WebStorm 2024.2+
- PyCharm 2024.2+
- GoLand 2024.2+
- Other JetBrains IDEs 2024.2+

## Building from Source

```bash
# Clone the repository
git clone https://github.com/type-ruby/t-ruby.git
cd t-ruby/editors/jetbrains

# Build the plugin
./gradlew buildPlugin

# The plugin ZIP will be in build/distributions/
```

### Running in Development Mode

```bash
./gradlew runIde
```

This launches a sandboxed IDE instance with the plugin installed.

## License

MIT License - see [LICENSE](../../LICENSE) for details.

## Links

- [JetBrains Marketplace](https://plugins.jetbrains.com/plugin/29335-t-ruby)
- [T-Ruby Documentation](https://type-ruby.github.io)
- [GitHub Repository](https://github.com/type-ruby/t-ruby)
- [LSP4IJ Plugin](https://plugins.jetbrains.com/plugin/23257-lsp4ij)
