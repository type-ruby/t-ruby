# frozen_string_literal: true

module TRuby
  class ErrorHandler
    VALID_TYPES = %w[String Integer Float Boolean Array Hash Symbol void nil].freeze
    # Unicode-aware identifier pattern for method/variable names (supports Korean, etc.)
    IDENTIFIER_PATTERN = /[\w\p{L}\p{N}]+[!?]?/

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
        if line.match?(/def\s+\w+\([^)]*$/) && @lines[(idx + 1)..].none? { |l| l.match?(/\)/) }
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
      # Use balanced paren matching to find the correct closing paren
      params_end = find_params_closing_paren(line)
      if params_end
        after_params = line[params_end..].strip
        # Check if there's trailing content that's not a return type annotation
        if (match = after_params.match(/^\)\s*([^:\s].+?)\s*$/))
          trailing = match[1].strip
          # Allow if it's just end-of-line content or a valid Ruby block start
          unless trailing.empty? || trailing.start_with?("#") || trailing == "end"
            @errors << "Line #{idx + 1}: Unexpected token '#{trailing}' after method parameters - did you forget ':'?"
          end
          return
        end
      end

      # Pattern 3: Check for parameter with colon but no type (e.g., "def test(x:)")
      # Skip this check for keyword args group { name:, age: } - they're valid
      params_str = extract_params_string(line)
      # Check each parameter for colon without type
      # Match: "x:" at end, "x:," in middle, or "x: )" with space before closing
      if params_str && !params_str.include?("{") &&
         (params_str.match?(/\w+:\s*$/) || params_str.match?(/\w+:\s*,/))
        @errors << "Line #{idx + 1}: Expected type after parameter colon"
        return
      end

      # Pattern 4: Extract and validate return type
      if params_end
        after_params = line[params_end..]
        if (match = after_params.match(/\)\s*:\s*(.+?)\s*$/))
          return_type_str = match[1].strip
          validate_type_expression(return_type_str, idx, "return type")
        end
      end

      # Pattern 5: Extract and validate parameter types
      if params_str
        validate_parameter_types_expression(params_str, idx)
      end
    end

    # Find the position of the closing paren for method parameters (balanced matching)
    def find_params_closing_paren(line)
      start_pos = line.index("(")
      return nil unless start_pos

      depth = 0
      line[start_pos..].each_char.with_index do |char, i|
        case char
        when "("
          depth += 1
        when ")"
          depth -= 1
          return start_pos + i if depth.zero?
        end
      end
      nil
    end

    # Extract the parameters string from a method definition line
    def extract_params_string(line)
      start_pos = line.index("(")
      return nil unless start_pos

      end_pos = find_params_closing_paren(line)
      return nil unless end_pos

      line[(start_pos + 1)...end_pos]
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
      # Note: we need to exclude -> arrow operators when counting < and >
      angle_balance = count_angle_brackets(type_str)
      if angle_balance != 0
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
      return unless result[:success]

      remaining = result[:remaining]&.strip
      return if remaining.nil? || remaining.empty?

      # Allow RBS-style square bracket generics (e.g., Hash[Symbol, String])
      # Allow nullable suffix (e.g., String?)
      # Allow array suffix (e.g., [])
      return if remaining.start_with?("[") || remaining.start_with?("?") || remaining == "[]"

      @errors << "Line #{line_idx + 1}: Unexpected token after #{context} '#{type_str}'"
    end

    def validate_parameter_types_expression(params_str, line_idx)
      return if params_str.nil? || params_str.empty?

      # Split parameters handling nested generics
      params = split_parameters(params_str)

      params.each do |param|
        param = param.strip
        next if param.empty?

        # Skip keyword args group: { name: Type, age: Type }
        next if param.start_with?("{")

        # Skip block parameter: &block or &block: Type
        next if param.start_with?("&")

        # Skip rest parameter: *args or *args: Type
        next if param.start_with?("*")

        # Check for param: Type pattern (with optional default value)
        # Match: name: Type or name: Type = default
        next unless (match = param.match(/^(\w+)\s*:\s*(.+)$/))

        param_name = match[1]
        type_and_default = match[2].strip

        if type_and_default.empty?
          @errors << "Line #{line_idx + 1}: Expected type after colon for parameter '#{param_name}'"
          next
        end

        # Extract just the type part (before any '=' for default value)
        type_str = extract_type_from_param(type_and_default)
        next if type_str.nil? || type_str.empty?

        validate_type_expression(type_str, line_idx, "parameter type for '#{param_name}'")
      end
    end

    # Extract type from "Type = default_value" or just "Type"
    def extract_type_from_param(type_and_default)
      # Find the position of '=' that's not inside parentheses/brackets
      depth = 0
      type_and_default.each_char.with_index do |char, i|
        case char
        when "(", "<", "["
          depth += 1
        when ")", ">", "]"
          depth -= 1
        when "="
          # Make sure it's not part of -> operator
          prev_char = i.positive? ? type_and_default[i - 1] : nil
          next if %w[- ! = < >].include?(prev_char)

          return type_and_default[0...i].strip if depth.zero?
        end
      end
      type_and_default
    end

    def split_parameters(params_str)
      result = []
      current = ""
      paren_depth = 0
      bracket_depth = 0
      angle_depth = 0
      brace_depth = 0

      i = 0
      while i < params_str.length
        char = params_str[i]
        next_char = params_str[i + 1]
        prev_char = i.positive? ? params_str[i - 1] : nil

        case char
        when "("
          paren_depth += 1
          current += char
        when ")"
          paren_depth -= 1
          current += char
        when "["
          bracket_depth += 1
          current += char
        when "]"
          bracket_depth -= 1
          current += char
        when "<"
          # Only count as generic if it's not part of operator like <=, <=>
          if next_char != "=" && next_char != ">"
            angle_depth += 1
          end
          current += char
        when ">"
          # Only count as closing generic if we're inside a generic (angle_depth > 0)
          # and it's not part of -> operator
          if angle_depth.positive? && prev_char != "-"
            angle_depth -= 1
          end
          current += char
        when "{"
          brace_depth += 1
          current += char
        when "}"
          brace_depth -= 1
          current += char
        when ","
          if paren_depth.zero? && bracket_depth.zero? && angle_depth.zero? && brace_depth.zero?
            result << current.strip
            current = ""
          else
            current += char
          end
        else
          current += char
        end
        i += 1
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
        if return_type&.match?(/^\w+$/) && !(VALID_TYPES.include?(return_type) || @type_aliases.key?(return_type) || @interfaces.key?(return_type))
          @errors << "Line #{idx + 1}: Unknown return type '#{return_type}'"
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
        next unless param_type.match?(/^\w+$/)
        next if VALID_TYPES.include?(param_type) || @type_aliases.key?(param_type) || @interfaces.key?(param_type)

        @errors << "Line #{line_idx + 1}: Unknown parameter type '#{param_type}'"
      end
    end

    def check_duplicate_definitions
      current_class = nil
      class_methods = {} # { class_name => { method_name => line_number } }

      @lines.each_with_index do |line, idx|
        # Track class context
        if line.match?(/^\s*class\s+(\w+)/)
          current_class = line.match(/class\s+(\w+)/)[1]
          class_methods[current_class] ||= {}
        elsif line.match?(/^\s*end\s*$/) && current_class
          # Simple heuristic: top-level 'end' closes current class
          # This is imperfect but handles most cases
          current_class = nil if line.match?(/^end\s*$/)
        end

        # Use unicode-aware pattern for function names (supports Korean, etc.)
        next unless line.match?(/^\s*def\s+#{IDENTIFIER_PATTERN}/)

        func_name = line.match(/def\s+(#{IDENTIFIER_PATTERN})/)[1]

        if current_class
          # Method inside a class - check within class scope
          methods = class_methods[current_class]
          if methods[func_name]
            @errors << "Line #{idx + 1}: Function '#{func_name}' is already defined at line #{methods[func_name]}"
          else
            methods[func_name] = idx + 1
          end
        elsif @functions[func_name]
          # Top-level function - check global scope
          @errors << "Line #{idx + 1}: Function '#{func_name}' is already defined at line #{@functions[func_name]}"
        else
          @functions[func_name] = idx + 1
        end
      end
    end

    # Count angle brackets excluding those in -> arrow operators
    # Returns the balance (positive if more <, negative if more >)
    def count_angle_brackets(type_str)
      balance = 0
      i = 0
      while i < type_str.length
        char = type_str[i]
        prev_char = i.positive? ? type_str[i - 1] : nil
        next_char = type_str[i + 1]

        case char
        when "<"
          # Skip if it's part of <= or <>
          balance += 1 unless %w[= >].include?(next_char)
        when ">"
          # Skip if it's part of -> arrow operator
          balance -= 1 unless prev_char == "-"
        end
        i += 1
      end
      balance
    end
  end
end
