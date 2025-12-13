<p align="center">
  <img src="https://avatars.githubusercontent.com/u/248530250" alt="T-Ruby" height="120">
</p>

<h1 align="center">T-Ruby for VS Code</h1>

<p align="center">
  <a href="https://type-ruby.github.io">Official Website</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="https://github.com/type-ruby/t-ruby">GitHub</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="https://marketplace.visualstudio.com/items?itemName=t-ruby.t-ruby">VS Code Marketplace</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="https://open-vsx.org/extension/t-ruby/t-ruby">Cursor Marketplace</a>
</p>

---

Welcome to T-Ruby for Visual Studio Code! This guide will help you install and configure the T-Ruby extension for a seamless typed Ruby development experience.

> **Note**: This extension shares the same source code for both VS Code and Cursor, providing identical functionality in both editors.

## Prerequisites

Before installing the extension, ensure you have:

- **Visual Studio Code** 1.75.0 or higher (or **Cursor**)
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

### Method 1: Marketplace (Recommended)

**VS Code:**
1. Open VS Code
2. Press `Ctrl+Shift+X` (Windows/Linux) or `Cmd+Shift+X` (macOS) to open Extensions
3. Search for "T-Ruby"
4. Click **Install**

Or install directly from the [VS Code Marketplace](https://marketplace.visualstudio.com/items?itemName=t-ruby.t-ruby).

**Cursor:**
1. Open Cursor
2. Press `Ctrl+Shift+X` (Windows/Linux) or `Cmd+Shift+X` (macOS) to open Extensions
3. Search for "T-Ruby"
4. Click **Install**

Or install directly from the [Cursor Marketplace](https://open-vsx.org/extension/t-ruby/t-ruby).

### Method 2: Install from VSIX (Coming Soon)

1. Download the `.vsix` file from [Releases](https://github.com/type-ruby/t-ruby/releases)
2. Open VS Code
3. Press `Ctrl+Shift+P` and type "Install from VSIX"
4. Select the downloaded file

### Method 3: Build from Source

```bash
# Clone the repository
git clone https://github.com/type-ruby/t-ruby.git
cd t-ruby/editors/vscode

# Install dependencies
npm install

# Build the extension
npm run compile

# Install the extension
code --install-extension .
```

## Configuration

After installation, configure the extension in VS Code settings (`Ctrl+,`):

```json
{
  "t-ruby.lspPath": "trc",
  "t-ruby.enableLSP": true,
  "t-ruby.diagnostics.enable": true,
  "t-ruby.completion.enable": true
}
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `t-ruby.lspPath` | string | `"trc"` | Path to T-Ruby compiler |
| `t-ruby.enableLSP` | boolean | `true` | Enable Language Server |
| `t-ruby.diagnostics.enable` | boolean | `true` | Enable real-time diagnostics |
| `t-ruby.completion.enable` | boolean | `true` | Enable autocomplete |

## Features

### Syntax Highlighting

The extension provides full syntax highlighting for:
- `.trb` files (T-Ruby source files)
- `.d.trb` files (T-Ruby declaration files)

Type annotations, interfaces, and type aliases are highlighted distinctly.

### IntelliSense

- **Autocomplete**: Type suggestions for parameters and return types
- **Hover**: View type information by hovering over symbols
- **Go to Definition**: Navigate to type/function definitions

### Diagnostics

Real-time error checking for:
- Unknown types
- Duplicate definitions
- Syntax errors

### Commands

Access via Command Palette (`Ctrl+Shift+P`):

| Command | Description |
|---------|-------------|
| `T-Ruby: Compile Current File` | Compile the active `.trb` file |
| `T-Ruby: Generate Declaration File` | Generate `.d.trb` from source |
| `T-Ruby: Restart Language Server` | Restart the LSP server |

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

### LSP not starting

1. Check if `trc` is installed: `which trc`
2. Verify the path in settings: `t-ruby.lspPath`
3. Check Output panel: View > Output > T-Ruby Language Server

### No syntax highlighting

1. Ensure file has `.trb` or `.d.trb` extension
2. Check file association: View > Command Palette > "Change Language Mode"

### Performance issues

- Disable diagnostics for large files: `"t-ruby.diagnostics.enable": false`
- Restart the language server: Command Palette > "T-Ruby: Restart Language Server"

## Next Steps

- [Syntax Highlighting Guide](../../syntax-highlighting/en/guide.md)
- [T-Ruby Language Reference](https://github.com/type-ruby/t-ruby/wiki)
- [Report Issues](https://github.com/type-ruby/t-ruby/issues)

## Support

For questions and bug reports, please visit GitHub Issues:
https://github.com/type-ruby/t-ruby/issues
