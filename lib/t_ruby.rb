# frozen_string_literal: true

require_relative "t_ruby/version"
require_relative "t_ruby/version_checker"
require_relative "t_ruby/ruby_version"
require_relative "t_ruby/code_emitter"
require_relative "t_ruby/config"

# Core infrastructure (must be loaded first)
require_relative "t_ruby/string_utils"
require_relative "t_ruby/ir"
require_relative "t_ruby/parser_combinator"
require_relative "t_ruby/scanner"
require_relative "t_ruby/smt_solver"

# Basic components
require_relative "t_ruby/type_alias_registry"
require_relative "t_ruby/heredoc_detector"
require_relative "t_ruby/parser"
require_relative "t_ruby/union_type_parser"
require_relative "t_ruby/generic_type_parser"
require_relative "t_ruby/intersection_type_parser"
require_relative "t_ruby/type_erasure"
require_relative "t_ruby/error_handler"
require_relative "t_ruby/diagnostic"
require_relative "t_ruby/declaration_generator"
require_relative "t_ruby/compiler"
require_relative "t_ruby/lsp_server"
require_relative "t_ruby/watcher"
require_relative "t_ruby/cli"

# Milestone 4: Advanced Features
require_relative "t_ruby/constraint_checker"
require_relative "t_ruby/type_inferencer"
require_relative "t_ruby/runtime_validator"
require_relative "t_ruby/type_checker"
require_relative "t_ruby/type_env"
require_relative "t_ruby/ast_type_inferrer"
require_relative "t_ruby/cache"
require_relative "t_ruby/package_manager"

# Milestone 5: Bundler Integration
require_relative "t_ruby/bundler_integration"

# Milestone 6: Quality & Documentation
require_relative "t_ruby/benchmark"
require_relative "t_ruby/doc_generator"

# Milestone -7: Documentation Verification
require_relative "t_ruby/docs_example_extractor"
require_relative "t_ruby/docs_example_verifier"
require_relative "t_ruby/docs_badge_generator"

module TRuby
  # Parse error for T-Ruby source code
  class ParseError < StandardError
    attr_reader :line, :column, :source

    def initialize(message, line: nil, column: nil, source: nil)
      @line = line
      @column = column
      @source = source
      super(message)
    end
  end
end
