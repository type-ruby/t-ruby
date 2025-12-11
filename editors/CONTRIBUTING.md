# Contributing to T-Ruby Editor Plugins

Thank you for your interest in contributing to T-Ruby editor plugins!

## Overview

T-Ruby supports multiple editors through dedicated plugins:

| Editor | Directory | Technology |
|--------|-----------|------------|
| VS Code | `vscode/` | TypeScript, LSP Client |
| JetBrains IDEs | `jetbrains/` | Kotlin, IntelliJ Platform |
| Vim | `vim/` | VimScript |
| Neovim | `nvim/` | Lua |

## Version Management

All editor plugins share a single version source:

```
editors/VERSION
```

To update versions across all plugins:

```bash
# Edit the VERSION file
echo "0.3.0" > editors/VERSION

# Run the sync script
./scripts/sync-editor-versions.sh
```

## Development Setup

### VS Code Plugin

```bash
cd editors/vscode

# Install dependencies
npm install

# Compile
npm run compile

# Run tests
npm test

# Watch mode (for development)
npm run watch

# Package for distribution
npm run package
```

### JetBrains Plugin

```bash
cd editors/jetbrains

# Build plugin
./gradlew buildPlugin

# Run tests
./gradlew test

# Verify plugin compatibility
./gradlew verifyPlugin

# Run IDE with plugin for testing
./gradlew runIde
```

### Vim Plugin

```vim
" Add to your .vimrc for development
set runtimepath+=~/path/to/t-ruby/editors/vim
```

### Neovim Plugin

```lua
-- Add to your init.lua for development
vim.opt.runtimepath:append("~/path/to/t-ruby/editors/nvim")
```

## Testing

### VS Code Tests

Tests use `@vscode/test-electron` with Mocha:

```bash
cd editors/vscode
npm test
```

Test files are in `src/test/suite/`:
- `extension.test.ts` - Extension activation and command tests

### JetBrains Tests

Tests use JUnit 5 with IntelliJ Platform Test Framework:

```bash
cd editors/jetbrains
./gradlew test
```

Test files are in `src/test/kotlin/`:
- `TRubyFileTypeTest.kt` - File type recognition tests
- `TRubySettingsTest.kt` - Settings persistence tests

## LSP Integration

All editors connect to the T-Ruby Language Server via `trc --lsp`.

### Features supported:
- Syntax highlighting (via TextMate grammars)
- Diagnostics (errors, warnings)
- Code completion
- Hover information
- Go to definition
- Document symbols

## Pull Request Guidelines

1. **Test your changes** - Ensure all tests pass before submitting
2. **Update VERSION** - If your change warrants a version bump
3. **Update CHANGELOG** - Document your changes
4. **Follow code style** - Run linters (`npm run lint` for VS Code, `./gradlew verifyPlugin` for JetBrains)

## CI/CD Pipeline

Pull requests automatically run:

- VS Code: `npm run lint` + `npm run compile`
- JetBrains: `./gradlew buildPlugin` + `./gradlew verifyPlugin`

## Release Process

1. Update `editors/VERSION`
2. Run `./scripts/sync-editor-versions.sh`
3. Update CHANGELOGs for each plugin
4. Create a git tag: `git tag vX.Y.Z`
5. Push tag: `git push origin vX.Y.Z`

The CI/CD pipeline will automatically:
- Build and test all plugins
- Create GitHub release with artifacts
- Publish to npm (WASM package)
- Publish to RubyGems (gem)

Editor plugins are published manually:
- VS Code: `cd editors/vscode && npm run publish`
- JetBrains: Via JetBrains Marketplace portal

## Questions?

- Open an issue on GitHub
- Check existing documentation in each plugin's README
