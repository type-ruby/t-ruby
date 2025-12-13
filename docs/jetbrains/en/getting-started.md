<p align="center">
  <img src="https://avatars.githubusercontent.com/u/248530250" alt="T-Ruby" height="120">
</p>

<h1 align="center">T-Ruby for JetBrains</h1>

<p align="center">
  <a href="https://type-ruby.github.io">Official Website</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="https://github.com/type-ruby/t-ruby">GitHub</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="https://plugins.jetbrains.com/plugin/29335-t-ruby">JetBrains Marketplace</a>
</p>

---

Welcome to T-Ruby for JetBrains! This guide will help you install and configure the T-Ruby plugin for a seamless typed Ruby development experience.

> **Note**: This plugin works with all JetBrains IDEs including IntelliJ IDEA, RubyMine, WebStorm, and more.

## Prerequisites

Before installing the plugin, ensure you have:

- **JetBrains IDE** 2023.1 or higher (IntelliJ IDEA, RubyMine, WebStorm, etc.)
- **Ruby** 3.0 or higher
- **T-Ruby Compiler** (`trc`) installed and available in your PATH

### Installing T-Ruby Compiler

```bash
# Install via gem (recommended)
gem install t-ruby
```

Verify the installation:
```bash
trc --version
```

## Installation

### Method 1: JetBrains Marketplace (Recommended)

1. Open your JetBrains IDE
2. Go to `Settings/Preferences` > `Plugins`
3. Search for "T-Ruby" in the `Marketplace` tab
4. Click **Install**
5. Restart the IDE

Or install directly from the [JetBrains Marketplace](https://plugins.jetbrains.com/plugin/29335-t-ruby).

### Method 2: Install from Disk (Coming Soon)

1. Download the `.zip` file from [Releases](https://github.com/type-ruby/t-ruby/releases)
2. Go to `Settings/Preferences` > `Plugins`
3. Click the gear icon > `Install Plugin from Disk...`
4. Select the downloaded file

### Method 3: Build from Source

```bash
# Clone the repository
git clone https://github.com/type-ruby/t-ruby.git
cd t-ruby/editors/jetbrains

# Build with Gradle
./gradlew buildPlugin

# The built plugin will be in build/distributions/
```

## Configuration

After installation, configure the plugin in `Settings/Preferences` > `Languages & Frameworks` > `T-Ruby`:

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| T-Ruby Compiler Path | `trc` | Path to T-Ruby compiler |
| Enable Real-time Diagnostics | `true` | Check errors while typing |
| Enable Autocomplete | `true` | Type-based autocompletion |

## Features

### Syntax Highlighting

The plugin provides full syntax highlighting for:
- `.trb` files (T-Ruby source files)
- `.d.trb` files (T-Ruby declaration files)

Type annotations, interfaces, and type aliases are highlighted distinctly.

### IntelliSense

- **Autocomplete**: Type suggestions for parameters and return types
- **Hover**: View type information by hovering over symbols
- **Go to Definition**: `Ctrl+Click` to navigate to type/function definitions

### Diagnostics

Real-time error checking for:
- Unknown types
- Duplicate definitions
- Syntax errors

### Actions

Access via `Find Action` (`Ctrl+Shift+A` / `Cmd+Shift+A`):

| Action | Description |
|--------|-------------|
| `T-Ruby: Compile Current File` | Compile the active `.trb` file |
| `T-Ruby: Generate Declaration File` | Generate `.d.trb` from source |

## Quick Start Example

1. Create a new file `hello.trb`:

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

2. Save the file - you'll see syntax highlighting and real-time diagnostics

3. Hover over types to see their definitions

4. Use `Ctrl+Space` for autocomplete suggestions

## Troubleshooting

### Plugin not working

1. Check if `trc` is installed: `which trc`
2. Verify the path in settings: `Settings` > `Languages & Frameworks` > `T-Ruby`
3. Check IDE logs: `Help` > `Show Log in Finder/Explorer`

### No syntax highlighting

1. Ensure file has `.trb` or `.d.trb` extension
2. Check file type association: `Settings` > `Editor` > `File Types`

### Performance issues

- Disable diagnostics for large files
- Restart the IDE

## Next Steps

- [Syntax Highlighting Guide](../../syntax-highlighting/en/guide.md)
- [T-Ruby Language Reference](https://github.com/type-ruby/t-ruby/wiki)
- [Report Issues](https://github.com/type-ruby/t-ruby/issues)

## Support

For questions and bug reports, please visit GitHub Issues:
https://github.com/type-ruby/t-ruby/issues
