/**
 * T-Ruby WASM - Compile T-Ruby (.trb) to Ruby (.rb) in the browser
 *
 * @example Browser usage:
 * ```typescript
 * import { DefaultRubyVM } from '@ruby/wasm-wasi/dist/browser';
 * import { initTRubyCompiler, RUBY_WASM_CDN_URL } from 't-ruby-wasm';
 *
 * // Load Ruby WASM
 * const response = await fetch(RUBY_WASM_CDN_URL);
 * const module = await WebAssembly.compileStreaming(response);
 * const { vm } = await DefaultRubyVM(module);
 *
 * // Initialize T-Ruby compiler
 * const compiler = await initTRubyCompiler(vm);
 *
 * // Compile T-Ruby code
 * const result = compiler.compile(`
 *   def greet(name: String): String
 *     "Hello, #{name}!"
 *   end
 * `);
 *
 * console.log(result.ruby);  // Ruby code without type annotations
 * console.log(result.rbs);   // RBS type signatures
 * ```
 */

export interface CompileResult {
  success: boolean;
  ruby: string;
  rbs: string;
  errors: string[];
}

export interface HealthCheckResult {
  loaded: boolean;
  version: string;
  ruby_version: string;
}

export interface VersionInfo {
  t_ruby: string;
  ruby: string;
}

export interface TRubyCompiler {
  compile(code: string): CompileResult;
  healthCheck(): HealthCheckResult;
  getVersion(): VersionInfo;
}

export interface InitOptions {
  libPath?: string;
}

/**
 * CDN URL for the Ruby WASM binary with stdlib
 */
export const RUBY_WASM_CDN_URL = 'https://cdn.jsdelivr.net/npm/@ruby/3.3-wasm-wasi@2.7.0/dist/ruby+stdlib.wasm';

/**
 * Bootstrap Ruby code for initializing T-Ruby compiler in WASM
 */
const BOOTSTRAP_CODE = `
require "json"

$trb_compiler = nil

def get_compiler
  $trb_compiler ||= TRuby::Compiler.new
end

def __trb_compile__(code)
  compiler = get_compiler

  begin
    result = compiler.compile_string(code)

    {
      success: result[:errors].empty?,
      ruby: result[:ruby] || "",
      rbs: result[:rbs] || "",
      errors: result[:errors] || []
    }.to_json
  rescue TRuby::ParseError => e
    {
      success: false,
      ruby: "",
      rbs: "",
      errors: [e.message]
    }.to_json
  rescue StandardError => e
    {
      success: false,
      ruby: "",
      rbs: "",
      errors: ["Compilation error: " + e.message]
    }.to_json
  end
end

def __trb_health_check__
  {
    loaded: defined?(TRuby) == "constant",
    version: defined?(TRuby::VERSION) ? TRuby::VERSION : "unknown",
    ruby_version: RUBY_VERSION
  }.to_json
end

def __trb_version__
  {
    t_ruby: defined?(TRuby::VERSION) ? TRuby::VERSION : "unknown",
    ruby: RUBY_VERSION
  }.to_json
end

puts "[T-Ruby WASM] Compiler initialized"
`;

/**
 * Initialize the T-Ruby compiler with a Ruby VM instance
 */
export async function initTRubyCompiler(vm: any, options: InitOptions = {}): Promise<TRubyCompiler> {
  const libPath = options.libPath || '/t-ruby/lib';

  // Add T-Ruby lib to Ruby load path and require it
  vm.eval(`
    $LOAD_PATH.unshift("${libPath}")
    require "t_ruby"
  `);

  // Initialize the bootstrap code
  vm.eval(BOOTSTRAP_CODE);

  return {
    compile(code: string): CompileResult {
      const resultJson = vm.eval(`__trb_compile__(${JSON.stringify(code)})`);
      return JSON.parse(resultJson.toString());
    },

    healthCheck(): HealthCheckResult {
      const resultJson = vm.eval('__trb_health_check__');
      return JSON.parse(resultJson.toString());
    },

    getVersion(): VersionInfo {
      const resultJson = vm.eval('__trb_version__');
      return JSON.parse(resultJson.toString());
    }
  };
}

export default {
  RUBY_WASM_CDN_URL,
  initTRubyCompiler
};
