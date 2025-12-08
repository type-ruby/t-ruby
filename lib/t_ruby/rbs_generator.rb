# frozen_string_literal: true

module TRuby
  class RBSGenerator
    def initialize
      # RBS generation configuration
    end

    def generate(functions, type_aliases)
      lines = []

      # Add type aliases
      type_aliases.each do |type_alias|
        lines << generate_type_alias(type_alias)
      end

      lines << "" if type_aliases.any? && functions.any?

      # Add function signatures
      functions.each do |func|
        lines << generate_function_signature(func)
      end

      lines.compact.join("\n")
    end

    def generate_type_aliases(aliases)
      aliases.map { |alias_def| generate_type_alias(alias_def) }.join("\n")
    end

    def generate_type_alias(type_alias)
      name = type_alias[:name]
      definition = type_alias[:definition]

      "type #{name} = #{definition}"
    end

    def generate_function_signature(func)
      name = func[:name]
      params = func[:params] || []
      return_type = func[:return_type]

      param_str = format_parameters(params)
      return_str = format_return_type(return_type)

      "def #{name}: (#{param_str}) -> #{return_str}"
    end

    private

    def format_parameters(params)
      return if params.empty?

      param_strs = params.map do |param|
        param_name = param[:name]
        param_type = param[:type] || "Object"

        "#{param_name}: #{param_type}"
      end

      param_strs.join(", ")
    end

    def format_return_type(return_type)
      return "void" if return_type == "void"
      return "nil" if return_type.nil?

      return_type
    end
  end
end
