# frozen_string_literal: true

module TRuby
  # Enhanced Parser using Parser Combinator for complex type expressions
  # Maintains backward compatibility with original Parser interface
  class Parser
    # Type names that are recognized as valid
    VALID_TYPES = %w[String Integer Boolean Array Hash Symbol void nil].freeze

    # Pattern for method/variable names that supports Unicode characters
    # \p{L} matches any Unicode letter, \p{N} matches any Unicode number
    IDENTIFIER_CHAR = '[\p{L}\p{N}_]'
    # Method names can end with ? or !
    METHOD_NAME_PATTERN = "#{IDENTIFIER_CHAR}+[?!]?".freeze
    # Visibility modifiers for method definitions
    VISIBILITY_PATTERN = '(?:(?:private|protected|public)\s+)?'

    attr_reader :source, :ir_program, :use_combinator

    def initialize(source, use_combinator: true, parse_body: true)
      @source = source
      @lines = source.split("\n")
      @use_combinator = use_combinator
      @parse_body = parse_body
      @type_parser = ParserCombinator::TypeParser.new if use_combinator
      @body_parser = BodyParser.new if parse_body
      @ir_program = nil
    end

    def parse
      functions = []
      type_aliases = []
      interfaces = []
      classes = []
      i = 0

      # Pre-detect heredoc regions to skip
      heredoc_ranges = HeredocDetector.detect(@lines)

      while i < @lines.length
        # Skip lines inside heredoc content
        if HeredocDetector.inside_heredoc?(i, heredoc_ranges)
          i += 1
          next
        end

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

        # Match class definitions
        if line.match?(/^\s*class\s+\w+/)
          class_info, next_i = parse_class(i)
          if class_info
            classes << class_info
            i = next_i
            next
          end
        end

        # Match function definitions (top-level only, not inside class)
        if line.match?(/^\s*#{VISIBILITY_PATTERN}def\s+#{IDENTIFIER_CHAR}+/)
          func_info, next_i = parse_function_with_body(i)
          if func_info
            functions << func_info
            i = next_i
            next
          end
        end

        i += 1
      end

      result = {
        type: :success,
        functions: functions,
        type_aliases: type_aliases,
        interfaces: interfaces,
        classes: classes,
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

    # 최상위 함수를 본문까지 포함하여 파싱
    def parse_function_with_body(start_index)
      line = @lines[start_index]
      func_info = parse_function_definition(line)
      return [nil, start_index] unless func_info

      def_indent = line.match(/^(\s*)/)[1].length
      i = start_index + 1
      body_start = i
      body_end = i

      # end 키워드 찾기
      while i < @lines.length
        current_line = @lines[i]

        if current_line.match?(/^\s*end\s*$/)
          end_indent = current_line.match(/^(\s*)/)[1].length
          if end_indent <= def_indent
            body_end = i
            break
          end
        end

        i += 1
      end

      # 본문 파싱 (parse_body 옵션이 활성화된 경우)
      if @parse_body && @body_parser && body_start < body_end
        func_info[:body_ir] = @body_parser.parse(@lines, body_start, body_end)
        func_info[:body_range] = { start: body_start, end: body_end }
      end

      [func_info, i]
    end

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
            ir_type: type_result[:type],
          }
        end
      end

      {
        name: alias_name,
        definition: definition,
      }
    end

    def parse_function_definition(line)
      # Match methods with or without parentheses
      # def foo(params): Type   - with params and return type
      # def foo(): Type         - no params but with return type
      # def foo(params)         - with params, no return type
      # def foo                  - no params, no return type
      # Also supports visibility modifiers: private def, protected def, public def
      match = line.match(/^\s*(?:(private|protected|public)\s+)?def\s+(#{METHOD_NAME_PATTERN})\s*(?:\((.*?)\))?\s*(?::\s*(.+?))?\s*$/)
      return nil unless match

      visibility = match[1] ? match[1].to_sym : :public
      function_name = match[2]
      params_str = match[3] || ""
      return_type_str = match[4]&.strip

      # Validate return type if present
      if return_type_str
        return_type_str = validate_and_extract_type(return_type_str)
      end

      params = parse_parameters(params_str)

      result = {
        name: function_name,
        params: params,
        return_type: return_type_str,
        visibility: visibility,
      }

      # Parse return type with combinator if available
      if @use_combinator && return_type_str
        type_result = @type_parser.parse(return_type_str)
        result[:ir_return_type] = type_result[:type] if type_result[:success]
      end

      result
    end

    # Validate type string and return nil if invalid
    def validate_and_extract_type(type_str)
      return nil if type_str.nil? || type_str.empty?

      # Check for whitespace in simple type names that would be invalid
      # Pattern: Capital letter followed by lowercase, then space, then more lowercase
      # e.g., "Str ing", "Int eger", "Bool ean"
      if type_str.match?(/^[A-Z][a-z]*\s+[a-z]+/)
        return nil
      end

      # Check for trailing operators
      return nil if type_str.match?(/[|&]\s*$/)

      # Check for leading operators
      return nil if type_str.match?(/^\s*[|&]/)

      # Check for unbalanced brackets
      return nil if type_str.count("<") != type_str.count(">")
      return nil if type_str.count("[") != type_str.count("]")
      return nil if type_str.count("(") != type_str.count(")")

      # Check for empty generic arguments
      return nil if type_str.match?(/<\s*>/)

      type_str
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
          if depth.zero?
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
        type: type_str,
      }

      # Parse type with combinator if available
      if @use_combinator && type_str
        type_result = @type_parser.parse(type_str)
        result[:ir_type] = type_result[:type] if type_result[:success]
      end

      result
    end

    def parse_class(start_index)
      line = @lines[start_index]
      match = line.match(/^\s*class\s+(\w+)(?:\s*<\s*(\w+))?/)
      return [nil, start_index] unless match

      class_name = match[1]
      superclass = match[2]
      methods = []
      instance_vars = []
      i = start_index + 1
      class_indent = line.match(/^(\s*)/)[1].length
      class_end = i

      # 먼저 클래스의 끝을 찾음
      temp_i = i
      while temp_i < @lines.length
        current_line = @lines[temp_i]
        if current_line.match?(/^\s*end\s*$/)
          end_indent = current_line.match(/^(\s*)/)[1].length
          if end_indent <= class_indent
            class_end = temp_i
            break
          end
        end
        temp_i += 1
      end

      while i < class_end
        current_line = @lines[i]

        # Match method definitions inside class
        if current_line.match?(/^\s*#{VISIBILITY_PATTERN}def\s+#{IDENTIFIER_CHAR}+/)
          method_info, next_i = parse_method_in_class(i, class_end)
          if method_info
            methods << method_info
            i = next_i
            next
          end
        end

        i += 1
      end

      # 메서드 본문에서 인스턴스 변수 추출
      methods.each do |method_info|
        extract_instance_vars_from_body(method_info[:body_ir], instance_vars)
      end

      # Try to infer instance variable types from initialize parameters
      init_method = methods.find { |m| m[:name] == "initialize" }
      if init_method
        instance_vars.each do |ivar|
          # Find matching parameter (e.g., @name = name)
          matching_param = init_method[:params]&.find { |p| p[:name] == ivar[:name] }
          ivar[:type] = matching_param[:type] if matching_param && matching_param[:type]
          ivar[:ir_type] = matching_param[:ir_type] if matching_param && matching_param[:ir_type]
        end
      end

      [{
        name: class_name,
        superclass: superclass,
        methods: methods,
        instance_vars: instance_vars,
      }, class_end,]
    end

    # 클래스 내부의 메서드를 본문까지 포함하여 파싱
    def parse_method_in_class(start_index, class_end)
      line = @lines[start_index]
      method_info = parse_function_definition(line)
      return [nil, start_index] unless method_info

      def_indent = line.match(/^(\s*)/)[1].length
      i = start_index + 1
      body_start = i
      body_end = i

      # 메서드의 end 키워드 찾기
      while i < class_end
        current_line = @lines[i]

        if current_line.match?(/^\s*end\s*$/)
          end_indent = current_line.match(/^(\s*)/)[1].length
          if end_indent <= def_indent
            body_end = i
            break
          end
        end

        i += 1
      end

      # 본문 파싱 (parse_body 옵션이 활성화된 경우)
      if @parse_body && @body_parser && body_start < body_end
        method_info[:body_ir] = @body_parser.parse(@lines, body_start, body_end)
        method_info[:body_range] = { start: body_start, end: body_end }
      end

      [method_info, i]
    end

    # 본문 IR에서 인스턴스 변수 추출
    def extract_instance_vars_from_body(body_ir, instance_vars)
      return unless body_ir.is_a?(IR::Block)

      body_ir.statements.each do |stmt|
        case stmt
        when IR::Assignment
          if stmt.target.start_with?("@") && !stmt.target.start_with?("@@")
            ivar_name = stmt.target[1..] # @ 제거
            unless instance_vars.any? { |iv| iv[:name] == ivar_name }
              instance_vars << { name: ivar_name }
            end
          end
        when IR::Block
          extract_instance_vars_from_body(stmt, instance_vars)
        end
      end
    end

    def parse_interface(start_index)
      line = @lines[start_index]
      match = line.match(/^\s*interface\s+([\w:]+)/)
      return [nil, start_index] unless match

      interface_name = match[1]
      members = []
      i = start_index + 1

      while i < @lines.length
        current_line = @lines[i]
        break if current_line.match?(/^\s*end\s*$/)

        if current_line.match?(/^\s*[\w!?]+\s*:\s*/)
          member_match = current_line.match(/^\s*([\w!?]+)\s*:\s*(.+?)\s*$/)
          if member_match
            member = {
              name: member_match[1],
              type: member_match[2].strip,
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
