# frozen_string_literal: true

module TRuby
  class Parser
    # Type names that are recognized as valid
    VALID_TYPES = %w[String Integer Boolean Array Hash Symbol void nil].freeze

    def initialize(source)
      @source = source
      @lines = source.split("\n")
    end

    def parse
      functions = []
      type_aliases = []
      i = 0

      while i < @lines.length
        line = @lines[i]

        # Match type alias definitions
        if line.match?(/^\s*type\s+\w+/)
          alias_info = parse_type_alias(line)
          if alias_info
            type_aliases << alias_info
          end
        end

        # Match function definitions
        if line.match?(/^\s*def\s+\w+/)
          func_info = parse_function_definition(line)
          if func_info
            functions << func_info
          end
        end

        i += 1
      end

      {
        type: :success,
        functions: functions,
        type_aliases: type_aliases
      }
    end

    private

    def parse_type_alias(line)
      # Match: type AliasName = TypeDefinition
      match = line.match(/^\s*type\s+(\w+)\s*=\s*(.+?)\s*$/)

      return nil unless match

      alias_name = match[1]
      definition = match[2].strip

      {
        name: alias_name,
        definition: definition
      }
    end

    def parse_function_definition(line)
      # Match: def function_name(params): return_type or def function_name(params)
      match = line.match(/^\s*def\s+(\w+)\s*\((.*?)\)\s*(?::\s*(\w+))?\s*$/)

      return nil unless match

      function_name = match[1]
      params_str = match[2]
      return_type = match[3]

      params = parse_parameters(params_str)

      {
        name: function_name,
        params: params,
        return_type: return_type
      }
    end

    def parse_parameters(params_str)
      return [] if params_str.empty?

      parameters = []
      # Split by comma, but be careful with nested structures
      param_list = params_str.split(",").map(&:strip)

      param_list.each do |param|
        param_info = parse_single_parameter(param)
        parameters << param_info if param_info
      end

      parameters
    end

    def parse_single_parameter(param)
      # Match: name: Type or just name
      match = param.match(/^(\w+)(?::\s*(\w+))?$/)

      return nil unless match

      {
        name: match[1],
        type: match[2]
      }
    end
  end
end
