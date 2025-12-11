#!/bin/bash
# sync-editor-versions.sh
# Synchronize editor plugin versions from editors/VERSION

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="$ROOT_DIR/editors/VERSION"

if [[ ! -f "$VERSION_FILE" ]]; then
    echo "Error: VERSION file not found at $VERSION_FILE"
    exit 1
fi

VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')

if [[ -z "$VERSION" ]]; then
    echo "Error: VERSION file is empty"
    exit 1
fi

echo "Syncing editor versions to: $VERSION"

# VSCode - package.json
VSCODE_PACKAGE="$ROOT_DIR/editors/vscode/package.json"
if [[ -f "$VSCODE_PACKAGE" ]]; then
    echo "  Updating VSCode package.json..."
    # Use node to update version properly
    node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('$VSCODE_PACKAGE', 'utf8'));
        pkg.version = '$VERSION';
        fs.writeFileSync('$VSCODE_PACKAGE', JSON.stringify(pkg, null, 2) + '\n');
    "
    echo "  ✓ VSCode: $VERSION"
else
    echo "  ⚠ VSCode package.json not found"
fi

# JetBrains - build.gradle.kts
JETBRAINS_GRADLE="$ROOT_DIR/editors/jetbrains/build.gradle.kts"
if [[ -f "$JETBRAINS_GRADLE" ]]; then
    echo "  Updating JetBrains build.gradle.kts..."
    sed -i "s/^version = \".*\"/version = \"$VERSION\"/" "$JETBRAINS_GRADLE"
    echo "  ✓ JetBrains: $VERSION"
else
    echo "  ⚠ JetBrains build.gradle.kts not found"
fi

# Vim - plugin version comment (optional)
VIM_PLUGIN="$ROOT_DIR/editors/vim/plugin/t-ruby.vim"
if [[ -f "$VIM_PLUGIN" ]]; then
    echo "  Updating Vim plugin..."
    sed -i "s/^\" Version: .*/\" Version: $VERSION/" "$VIM_PLUGIN"
    echo "  ✓ Vim: $VERSION"
else
    echo "  ⚠ Vim plugin not found"
fi

# Neovim - plugin version comment (optional)
NVIM_PLUGIN="$ROOT_DIR/editors/nvim/lua/t-ruby/init.lua"
if [[ -f "$NVIM_PLUGIN" ]]; then
    echo "  Updating Neovim plugin..."
    sed -i "s/^-- Version: .*/-- Version: $VERSION/" "$NVIM_PLUGIN"
    echo "  ✓ Neovim: $VERSION"
else
    echo "  ⚠ Neovim plugin not found"
fi

echo ""
echo "Version sync complete: $VERSION"
echo ""
echo "Files updated:"
echo "  - editors/vscode/package.json"
echo "  - editors/jetbrains/build.gradle.kts"
echo ""
echo "Don't forget to:"
echo "  1. Update CHANGELOG.md for each editor"
echo "  2. Commit the changes"
echo "  3. Create a git tag: git tag v$VERSION"
