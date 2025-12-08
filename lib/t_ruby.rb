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
require_relative "t_ruby/compiler"
require_relative "t_ruby/cli"

module TRuby
end
