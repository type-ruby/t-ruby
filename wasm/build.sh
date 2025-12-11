#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== T-Ruby WASM Build ==="
echo "Script directory: $SCRIPT_DIR"
echo "Project root: $PROJECT_ROOT"

# Create dist directory
mkdir -p "$SCRIPT_DIR/dist"

# Install npm dependencies if needed
if [ ! -d "$SCRIPT_DIR/node_modules" ]; then
  echo ""
  echo "=== Installing npm dependencies ==="
  cd "$SCRIPT_DIR"
  npm install
fi

# Copy the Ruby source files to be bundled
echo ""
echo "=== Preparing T-Ruby compiler source ==="
mkdir -p "$SCRIPT_DIR/dist/lib"

# Copy t_ruby library
cp -r "$PROJECT_ROOT/lib/t_ruby" "$SCRIPT_DIR/dist/lib/"
cp "$PROJECT_ROOT/lib/t_ruby.rb" "$SCRIPT_DIR/dist/lib/"

# Copy bootstrap script
cp "$SCRIPT_DIR/src/bootstrap.rb" "$SCRIPT_DIR/dist/"

# Generate TypeScript wrapper
echo ""
echo "=== Generating TypeScript wrapper ==="

cat > "$SCRIPT_DIR/dist/index.js" << 'JSEOF'
/**
 * T-Ruby WASM - Compile T-Ruby (.trb) to Ruby (.rb) in the browser
 *
 * @example
 * ```typescript
 * import { createTRubyCompiler } from 't-ruby-wasm';
 *
 * const compiler = await createTRubyCompiler();
 * const result = compiler.compile(`
 *   def greet(name: String): String
 *     "Hello, #{name}!"
 *   end
 * `);
 * console.log(result.ruby);  // Ruby code without type annotations
 * console.log(result.rbs);   // RBS type signatures
 * ```
 */

// T-Ruby compiler source embedded as base64
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Configuration options for the T-Ruby compiler
 */
export const WASM_CDN_URL = 'https://cdn.jsdelivr.net/npm/@ruby/3.3-wasm-wasi@2.7.0/dist/ruby+stdlib.wasm';

/**
 * Get the bootstrap Ruby code
 */
export function getBootstrapCode() {
  return readFileSync(join(__dirname, 'bootstrap.rb'), 'utf-8');
}

/**
 * Get the T-Ruby library path for bundling
 */
export function getTRubyLibPath() {
  return join(__dirname, 'lib');
}

/**
 * Browser-compatible initialization
 * This is used by the playground to initialize the compiler
 */
export async function initTRubyCompiler(rubyVM) {
  // Load the bootstrap code
  const bootstrapCode = `
$LOAD_PATH.unshift("/t-ruby/lib")
require "t_ruby"

def __trb_compile__(code)
  begin
    compiler = TRuby::Compiler.new

    # Parse the code
    result = compiler.compile_string(code)

    {
      success: true,
      ruby: result[:ruby] || "",
      rbs: result[:rbs] || "",
      errors: []
    }
  rescue TRuby::ParseError => e
    {
      success: false,
      ruby: "",
      rbs: "",
      errors: [e.message]
    }
  rescue => e
    {
      success: false,
      ruby: "",
      rbs: "",
      errors: ["Compilation error: " + e.message]
    }
  end
end
`;

  rubyVM.eval(bootstrapCode);

  return {
    compile: (code) => {
      const resultJson = rubyVM.eval(`__trb_compile__(${JSON.stringify(code)}).to_json`);
      return JSON.parse(resultJson.toString());
    }
  };
}

export default {
  WASM_CDN_URL,
  getBootstrapCode,
  getTRubyLibPath,
  initTRubyCompiler
};
JSEOF

# Generate TypeScript declaration file
cat > "$SCRIPT_DIR/dist/index.d.ts" << 'DTSEOF'
/**
 * T-Ruby WASM - Type definitions
 */

export interface CompileResult {
  success: boolean;
  ruby: string;
  rbs: string;
  errors: string[];
}

export interface TRubyCompiler {
  compile(code: string): CompileResult;
}

/**
 * CDN URL for the Ruby WASM binary
 */
export declare const WASM_CDN_URL: string;

/**
 * Get the bootstrap Ruby code for initializing T-Ruby in WASM
 */
export declare function getBootstrapCode(): string;

/**
 * Get the path to the T-Ruby library files
 */
export declare function getTRubyLibPath(): string;

/**
 * Initialize the T-Ruby compiler with a Ruby VM instance
 * @param rubyVM - A ruby.wasm VM instance
 * @returns A compiler instance with compile() method
 */
export declare function initTRubyCompiler(rubyVM: any): Promise<TRubyCompiler>;

declare const _default: {
  WASM_CDN_URL: string;
  getBootstrapCode: typeof getBootstrapCode;
  getTRubyLibPath: typeof getTRubyLibPath;
  initTRubyCompiler: typeof initTRubyCompiler;
};

export default _default;
DTSEOF

echo ""
echo "=== Build complete ==="
echo "Output directory: $SCRIPT_DIR/dist/"
ls -la "$SCRIPT_DIR/dist/"
