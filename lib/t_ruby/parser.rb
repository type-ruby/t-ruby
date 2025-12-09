# frozen_string_literal: true

module TRuby
  # Enhanced Parser using Parser Combinator for complex type expressions
  # Maintains backward compatibility with original Parser interface
  class Parser
    # Type names that are recognized as valid
    VALID_TYPES = %w[String Integer Boolean Array Hash Symbol void nil].freeze

    attr_reader :source, :ir_program, :use_combinator

    def initialize(source, use_combinator: true)
      @source = source
      @lines = source.split("\n")
      @use_combinator = use_combinator
      @type_parser = ParserCombinator::TypeParser.new if use_combinator
      @ir_program = nil
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
          type_aliases << alias_info if alias_info
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
          functions << func_info if func_info
        end

        i += 1
      end

      result = {
        type: :success,
        functions: functions,
        type_aliases: type_aliases,
        interfaces: interfaces
      }

      # Build IR if combinator is enabled
      if @use_combinator
        builder = IR::Builder.new
        @ir_program = builder.build(result, source: @source)
      end

      result
    end

    # Parse to IR directly (new API)
    def parse_to_ir
      parse unless @ir_program
      @ir_program
    end

    # Parse a type expression using combinator (new API)
    def parse_type(type_string)
      return nil unless @use_combinator

      result = @type_parser.parse(type_string)
      result[:success] ? result[:type] : nil
    end

    private

    def parse_type_alias(line)
      match = line.match(/^\s*type\s+(\w+)\s*=\s*(.+?)\s*$/)
      return nil unless match

      alias_name = match[1]
      definition = match[2].strip

      # Use combinator for complex type parsing if available
      if @use_combinator
        type_result = @type_parser.parse(definition)
        if type_result[:success]
          return {
            name: alias_name,
            definition: definition,
            ir_type: type_result[:type]
          }
        end
      end

      {
        name: alias_name,
        definition: definition
      }
    end

    def parse_function_definition(line)
      match = line.match(/^\s*def\s+(\w+)\s*\((.*?)\)\s*(?::\s*(.+?))?\s*$/)
      return nil unless match

      function_name = match[1]
      params_str = match[2]
      return_type_str = match[3]&.strip

      params = parse_parameters(params_str)

      result = {
        name: function_name,
        params: params,
        return_type: return_type_str
      }

      # Parse return type with combinator if available
      if @use_combinator && return_type_str
        type_result = @type_parser.parse(return_type_str)
        result[:ir_return_type] = type_result[:type] if type_result[:success]
      end

      result
    end

    def parse_parameters(params_str)
      return [] if params_str.empty?

      parameters = []
      param_list = split_params(params_str)

      param_list.each do |param|
        param_info = parse_single_parameter(param)
        parameters << param_info if param_info
      end

      parameters
    end

    def split_params(params_str)
      # Handle nested generics like Array<Map<String, Int>>
      result = []
      current = ""
      depth = 0

      params_str.each_char do |char|
        case char
        when "<", "[", "("
          depth += 1
          current += char
        when ">", "]", ")"
          depth -= 1
          current += char
        when ","
          if depth == 0
            result << current.strip
            current = ""
          else
            current += char
          end
        else
          current += char
        end
      end

      result << current.strip unless current.empty?
      result
    end

    def parse_single_parameter(param)
      match = param.match(/^(\w+)(?::\s*(.+?))?$/)
      return nil unless match

      param_name = match[1]
      type_str = match[2]&.strip

      result = {
        name: param_name,
        type: type_str
      }

      # Parse type with combinator if available
      if @use_combinator && type_str
        type_result = @type_parser.parse(type_str)
        result[:ir_type] = type_result[:type] if type_result[:success]
      end

      result
    end

    def parse_interface(start_index)
      line = @lines[start_index]
      match = line.match(/^\s*interface\s+(\w+)/)
      return [nil, start_index] unless match

      interface_name = match[1]
      members = []
      i = start_index + 1

      while i < @lines.length
        current_line = @lines[i]
        break if current_line.match?(/^\s*end\s*$/)

        if current_line.match?(/^\s*\w+\s*:\s*/)
          member_match = current_line.match(/^\s*(\w+)\s*:\s*(.+?)\s*$/)
          if member_match
            member = {
              name: member_match[1],
              type: member_match[2].strip
            }

            # Parse member type with combinator
            if @use_combinator
              type_result = @type_parser.parse(member[:type])
              member[:ir_type] = type_result[:type] if type_result[:success]
            end

            members << member
          end
        end

        i += 1
      end

      [{ name: interface_name, members: members }, i]
    end
  end

  # Legacy Parser for backward compatibility (regex-only)
  class LegacyParser < Parser
    def initialize(source)
      super(source, use_combinator: false)
    end
  end
end
