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
      interfaces = []
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

        # Match interface definitions
        if line.match?(/^\s*interface\s+\w+/)
          interface_info, next_i = parse_interface(i)
          if interface_info
            interfaces << interface_info
            i = next_i
            next
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
        type_aliases: type_aliases,
        interfaces: interfaces
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
      # Updated to support union types with pipes in return type
      match = line.match(/^\s*def\s+(\w+)\s*\((.*?)\)\s*(?::\s*(.+?))?\s*$/)

      return nil unless match

      function_name = match[1]
      params_str = match[2]
      return_type = match[3]&.strip

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
      # Match: name: Type or name: Union | Type or just name
      # Updated to handle union types with pipes
      match = param.match(/^(\w+)(?::\s*(.+?))?$/)

      return nil unless match

      {
        name: match[1],
        type: match[2]&.strip
      }
    end

    def parse_interface(start_index)
      line = @lines[start_index]
      match = line.match(/^\s*interface\s+(\w+)/)

      return [nil, start_index] unless match

      interface_name = match[1]
      members = []
      i = start_index + 1

      # Parse members until we find 'end'
      while i < @lines.length
        current_line = @lines[i]

        # Check for end of interface
        break if current_line.match?(/^\s*end\s*$/)

        # Parse member if it has a type annotation
        if current_line.match?(/^\s*\w+\s*:\s*/)
          member_match = current_line.match(/^\s*(\w+)\s*:\s*(.+?)\s*$/)
          if member_match
            members << {
              name: member_match[1],
              type: member_match[2].strip
            }
          end
        end

        i += 1
      end

      [
        {
          name: interface_name,
          members: members
        },
        i  # Return index of 'end' line
      ]
    end
  end
end
