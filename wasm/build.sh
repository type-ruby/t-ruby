#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== T-Ruby WASM Build ==="
echo "Script directory: $SCRIPT_DIR"
echo "Project root: $PROJECT_ROOT"

# Create dist directory
rm -rf "$SCRIPT_DIR/dist"
mkdir -p "$SCRIPT_DIR/dist/lib/t_ruby"

# Copy only the core compilation files needed for WASM
# Excluded: lsp_server, watcher, cli, cache, package_manager, bundler_integration, benchmark, doc_generator
# These require external gems (listen, etc.) not available in WASM
echo ""
echo "=== Copying T-Ruby core compilation files ==="

CORE_FILES=(
  "version.rb"
  "config.rb"
  "ir.rb"
  "parser_combinator.rb"
  "smt_solver.rb"
  "type_alias_registry.rb"
  "parser.rb"
  "union_type_parser.rb"
  "generic_type_parser.rb"
  "intersection_type_parser.rb"
  "type_erasure.rb"
  "error_handler.rb"
  "rbs_generator.rb"
  "declaration_generator.rb"
  "compiler.rb"
  "constraint_checker.rb"
  "type_inferencer.rb"
  "runtime_validator.rb"
  "type_checker.rb"
)

for file in "${CORE_FILES[@]}"; do
  echo "  Copying: t_ruby/$file"
  cp "$PROJECT_ROOT/lib/t_ruby/$file" "$SCRIPT_DIR/dist/lib/t_ruby/"
done

# Process compiler.rb to remove fileutils require (not available in WASM)
echo ""
echo "=== Processing compiler.rb for WASM compatibility ==="
sed -i.bak 's/^require "fileutils"$/# require "fileutils" # Not available in WASM/' "$SCRIPT_DIR/dist/lib/t_ruby/compiler.rb"
rm -f "$SCRIPT_DIR/dist/lib/t_ruby/compiler.rb.bak"

# Generate manifest.json with file list
echo ""
echo "=== Generating manifest.json ==="
VERSION=$(node -p "require('$SCRIPT_DIR/package.json').version")
cat > "$SCRIPT_DIR/dist/manifest.json" << EOF
{
  "version": "$VERSION",
  "files": [
$(printf '    "%s",\n' "${CORE_FILES[@]}" | sed '$ s/,$//')
  ]
}
EOF

echo ""
echo "=== Build complete ==="
echo "Output directory: $SCRIPT_DIR/dist/"
ls -la "$SCRIPT_DIR/dist/"
ls -la "$SCRIPT_DIR/dist/lib/t_ruby/"
