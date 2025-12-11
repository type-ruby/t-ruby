# frozen_string_literal: true

# T-Ruby WASM Bootstrap
# This file initializes the T-Ruby compiler in a WebAssembly environment

require "json"

# Add T-Ruby lib to load path
$LOAD_PATH.unshift("/t-ruby/lib")

# Load T-Ruby compiler
require "t_ruby"

# Global compiler instance (lazy initialized)
$trb_compiler = nil

def get_compiler
  $trb_compiler ||= TRuby::Compiler.new
end

# Compile T-Ruby code to Ruby and RBS
#
# @param code [String] T-Ruby source code
# @return [String] JSON result with success, ruby, rbs, errors keys
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
      errors: [format_error(e)]
    }.to_json
  rescue StandardError => e
    {
      success: false,
      ruby: "",
      rbs: "",
      errors: ["Compilation error: #{e.message}"]
    }.to_json
  end
end

# Format error message with line/column info if available
def format_error(error)
  if error.respond_to?(:line) && error.respond_to?(:column)
    "Line #{error.line}, Column #{error.column}: #{error.message}"
  else
    error.message
  end
end

# Check if T-Ruby is properly loaded
def __trb_health_check__
  {
    loaded: defined?(TRuby) == "constant",
    version: defined?(TRuby::VERSION) ? TRuby::VERSION : "unknown",
    ruby_version: RUBY_VERSION
  }.to_json
end

# Version info
def __trb_version__
  {
    t_ruby: defined?(TRuby::VERSION) ? TRuby::VERSION : "unknown",
    ruby: RUBY_VERSION
  }.to_json
end

puts "[T-Ruby WASM] Bootstrap loaded successfully"
puts "[T-Ruby WASM] Ruby version: #{RUBY_VERSION}"
puts "[T-Ruby WASM] T-Ruby version: #{TRuby::VERSION}" if defined?(TRuby::VERSION)
