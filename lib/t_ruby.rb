# frozen_string_literal: true

require_relative "t_ruby/version"
require_relative "t_ruby/config"
require_relative "t_ruby/type_alias_registry"
require_relative "t_ruby/parser"
require_relative "t_ruby/union_type_parser"
require_relative "t_ruby/generic_type_parser"
require_relative "t_ruby/intersection_type_parser"
require_relative "t_ruby/type_erasure"
require_relative "t_ruby/error_handler"
require_relative "t_ruby/rbs_generator"
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
require_relative "t_ruby/cache"
require_relative "t_ruby/package_manager"

# Milestone 5: Future Enhancements
require_relative "t_ruby/ir"
require_relative "t_ruby/parser_combinator"
require_relative "t_ruby/smt_solver"
require_relative "t_ruby/bundler_integration"

module TRuby
end
