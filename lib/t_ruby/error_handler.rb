# frozen_string_literal: true

module TRuby
  class ErrorHandler
    VALID_TYPES = %w[String Integer Boolean Array Hash Symbol void nil].freeze

    def initialize(source)
      @source = source
      @lines = source.split("\n")
      @errors = []
      @functions = {}
      @type_parser = ParserCombinator::TypeParser.new
    end

    def check
      @errors = []
      @functions = {}
      @type_aliases = {}
      @interfaces = {}

      check_type_alias_errors
      check_interface_errors
      check_syntax_errors
      check_method_signature_errors
      check_type_validation
      check_duplicate_definitions

      @errors
    end

    private

    def check_interface_errors
      @lines.each_with_index do |line, idx|
        next unless line.match?(/^\s*interface\s+[\w:]+/)

        match = line.match(/^\s*interface\s+([\w:]+)/)
        next unless match

        interface_name = match[1]

        if @interfaces[interface_name]
          @errors << "Line #{idx + 1}: Interface '#{interface_name}' is already defined at line #{@interfaces[interface_name]}"
        else
          @interfaces[interface_name] = idx + 1
        end
      end
    end

    def check_type_alias_errors
      @lines.each_with_index do |line, idx|
        next unless line.match?(/^\s*type\s+\w+/)

        match = line.match(/^\s*type\s+(\w+)\s*=\s*(.+)$/)
        next unless match

        alias_name = match[1]

        if @type_aliases[alias_name]
          @errors << "Line #{idx + 1}: Type alias '#{alias_name}' is already defined at line #{@type_aliases[alias_name]}"
        else
          @type_aliases[alias_name] = idx + 1
        end
      end
    end

    def check_syntax_errors
      @lines.each_with_index do |line, idx|
        next unless line.match?(/^\s*def\s+/)

        # Check for unclosed parenthesis
        if line.match?(/def\s+\w+\([^)]*$/) && !@lines[idx + 1..].any? { |l| l.match?(/\)/) }
          @errors << "Line #{idx + 1}: Potential unclosed parenthesis in function definition"
        end

        # Check for invalid parameter syntax (e.g., "def test(: String)")
        if line.match?(/def\s+\w+\(\s*:\s*\w+/)
          @errors << "Line #{idx + 1}: Invalid parameter syntax - parameter name missing"
        end
      end
    end

    # New comprehensive method signature validation
    def check_method_signature_errors
      @lines.each_with_index do |line, idx|
        next unless line.match?(/^\s*def\s+/)
        check_single_method_signature(line, idx)
      end
    end

    def check_single_method_signature(line, idx)
      # Pattern 1: Check for colon without type (e.g., "def test():")
      if line.match?(/def\s+\w+[^:]*\)\s*:\s*$/)
        @errors << "Line #{idx + 1}: Expected type after colon, but found end of line"
        return
      end

      # Pattern 2: Check for text after closing paren without colon (e.g., "def test() something")
      if match = line.match(/def\s+\w+\s*\([^)]*\)\s*([^:\s].+?)\s*$/)
        trailing = match[1].strip
        # Allow if it's just end-of-line content or a valid Ruby block start
        unless trailing.empty? || trailing.start_with?("#") || trailing == "end"
          @errors << "Line #{idx + 1}: Unexpected token '#{trailing}' after method parameters - did you forget ':'?"
        end
        return
      end

      # Pattern 3: Check for parameter with colon but no type (e.g., "def test(x:)")
      if line.match?(/def\s+\w+\s*\([^)]*\w+:\s*[,)]/)
        @errors << "Line #{idx + 1}: Expected type after parameter colon"
        return
      end

      # Pattern 4: Extract and validate return type
      if match = line.match(/def\s+\w+\s*\([^)]*\)\s*:\s*(.+?)\s*$/)
        return_type_str = match[1].strip
        validate_type_expression(return_type_str, idx, "return type")
      end

      # Pattern 5: Extract and validate parameter types
      if match = line.match(/def\s+\w+\s*\(([^)]+)\)/)
        params_str = match[1]
        validate_parameter_types_expression(params_str, idx)
      end
    end

    def validate_type_expression(type_str, line_idx, context = "type")
      return if type_str.nil? || type_str.empty?

      # Check for whitespace in simple type names (e.g., "Str ing")
      if type_str.match?(/^[A-Z][a-z]*\s+[a-z]+/)
        @errors << "Line #{line_idx + 1}: Invalid #{context} '#{type_str}' - unexpected whitespace in type name"
        return
      end

      # Check for trailing operators (e.g., "String |" or "String &")
      if type_str.match?(/[|&]\s*$/)
        @errors << "Line #{line_idx + 1}: Invalid #{context} '#{type_str}' - trailing operator"
        return
      end

      # Check for leading operators
      if type_str.match?(/^\s*[|&]/)
        @errors << "Line #{line_idx + 1}: Invalid #{context} '#{type_str}' - leading operator"
        return
      end

      # Check for double operators (e.g., "String | | Integer")
      if type_str.match?(/[|&]\s*[|&]/)
        @errors << "Line #{line_idx + 1}: Invalid #{context} '#{type_str}' - consecutive operators"
        return
      end

      # Check for unclosed brackets
      if type_str.count("<") != type_str.count(">")
        @errors << "Line #{line_idx + 1}: Invalid #{context} '#{type_str}' - unbalanced angle brackets"
        return
      end

      if type_str.count("[") != type_str.count("]")
        @errors << "Line #{line_idx + 1}: Invalid #{context} '#{type_str}' - unbalanced square brackets"
        return
      end

      if type_str.count("(") != type_str.count(")")
        @errors << "Line #{line_idx + 1}: Invalid #{context} '#{type_str}' - unbalanced parentheses"
        return
      end

      # Check for empty generic arguments (e.g., "Array<>")
      if type_str.match?(/<\s*>/)
        @errors << "Line #{line_idx + 1}: Invalid #{context} '#{type_str}' - empty generic arguments"
        return
      end

      # Check for generic without base type (e.g., "<String>")
      if type_str.match?(/^\s*</)
        @errors << "Line #{line_idx + 1}: Invalid #{context} '#{type_str}' - missing base type for generic"
        return
      end

      # Check for missing arrow target in function type
      if type_str.match?(/->\s*$/)
        @errors << "Line #{line_idx + 1}: Invalid #{context} '#{type_str}' - missing return type after ->"
        return
      end

      # Check for extra tokens after valid type (e.g., "String something_else")
      # Use TypeParser to validate
      result = @type_parser.parse(type_str)
      if result[:success]
        remaining = type_str[result[:position] || 0..]&.strip
        if remaining && !remaining.empty? && result[:remaining] && !result[:remaining].strip.empty?
          @errors << "Line #{line_idx + 1}: Unexpected token after #{context} '#{type_str}'"
        end
      end
    end

    def validate_parameter_types_expression(params_str, line_idx)
      return if params_str.nil? || params_str.empty?

      # Split parameters handling nested generics
      params = split_parameters(params_str)

      params.each do |param|
        param = param.strip
        next if param.empty?

        # Check for param: Type pattern
        if match = param.match(/^(\w+)\s*:\s*(.+)$/)
          param_name = match[1]
          type_str = match[2].strip

          if type_str.empty?
            @errors << "Line #{line_idx + 1}: Expected type after colon for parameter '#{param_name}'"
            next
          end

          validate_type_expression(type_str, line_idx, "parameter type for '#{param_name}'")
        end
      end
    end

    def split_parameters(params_str)
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

    def check_type_validation
      @lines.each_with_index do |line, idx|
        next unless line.match?(/^\s*def\s+/)

        # Extract types from function definition - now handle complex types
        match = line.match(/def\s+\w+\s*\((.*?)\)\s*(?::\s*(.+?))?$/)
        next unless match

        params_str = match[1]
        return_type = match[2]&.strip

        # Check return type if it's a simple type name
        if return_type && return_type.match?(/^\w+$/)
          unless VALID_TYPES.include?(return_type) || @type_aliases.key?(return_type)
            @errors << "Line #{idx + 1}: Unknown return type '#{return_type}'"
          end
        end

        # Check parameter types
        check_parameter_types(params_str, idx)
      end
    end

    def check_parameter_types(params_str, line_idx)
      return if params_str.nil? || params_str.empty?

      params = split_parameters(params_str)
      params.each do |param|
        param = param.strip
        match = param.match(/^(\w+)(?::\s*(.+))?$/)
        next unless match

        param_type = match[2]&.strip
        next unless param_type

        # Only check simple type names against VALID_TYPES
        if param_type.match?(/^\w+$/)
          next if VALID_TYPES.include?(param_type) || @type_aliases.key?(param_type)
          @errors << "Line #{line_idx + 1}: Unknown parameter type '#{param_type}'"
        end
      end
    end

    def check_duplicate_definitions
      @lines.each_with_index do |line, idx|
        next unless line.match?(/^\s*def\s+(\w+)/)

        func_name = line.match(/def\s+(\w+)/)[1]

        if @functions[func_name]
          @errors << "Line #{idx + 1}: Function '#{func_name}' is already defined at line #{@functions[func_name]}"
        else
          @functions[func_name] = idx + 1
        end
      end
    end
  end
end
