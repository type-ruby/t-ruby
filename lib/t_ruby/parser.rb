# frozen_string_literal: true

module TRuby
  # Enhanced Parser using Parser Combinator for complex type expressions
  # Maintains backward compatibility with original Parser interface
  #
  # This class serves as a facade that can delegate to either:
  # 1. Legacy regex-based parsing (default)
  # 2. New TokenDeclarationParser with TypeSlot support (opt-in)
  #
  # To use the new parser, set use_token_parser: true or
  # set TRUBY_NEW_PARSER=1 environment variable.
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

    # @deprecated The regex-based parsing will be replaced by TokenDeclarationParser.
    # See: lib/t_ruby/parser_combinator/token/token_declaration_parser.rb

    attr_reader :source, :ir_program

    def initialize(source, parse_body: true, use_token_parser: nil)
      @source = source
      @lines = source.split("\n")
      @parse_body = parse_body
      @use_token_parser = use_token_parser
      @type_parser = ParserCombinator::TypeParser.new
      @body_parser = ParserCombinator::TokenBodyParser.new if parse_body
      @ir_program = nil
    end

    def parse
      if use_token_parser?
        parse_with_token_parser
      else
        parse_with_legacy_parser
      end
    rescue Scanner::ScanError => e
      raise ParseError.new(e.message, line: e.line, column: e.column)
    end

    private

    # Check if token parser should be used
    def use_token_parser?
      return @use_token_parser unless @use_token_parser.nil?

      ENV["TRUBY_NEW_PARSER"] == "1"
    end

    # Parse using the new TokenDeclarationParser with TypeSlot support
    def parse_with_token_parser
      scanner = Scanner.new(@source)
      tokens = scanner.scan_all
      token_parser = ParserCombinator::TokenDeclarationParser.new

      program_result = token_parser.parse_program(tokens)

      if program_result.success?
        @ir_program = program_result.value
        convert_ir_to_legacy_format(@ir_program)
      else
        raise ParseError.new(
          program_result.error,
          line: token_parser.errors.first&.line,
          column: token_parser.errors.first&.column
        )
      end
    end

    # Convert IR::Program to legacy hash format for backward compatibility
    def convert_ir_to_legacy_format(program)
      functions = []
      type_aliases = []
      interfaces = []
      classes = []

      program.declarations.each do |decl|
        case decl
        when IR::MethodDef
          functions << convert_method_to_legacy(decl)
        when IR::TypeAlias
          type_aliases << convert_type_alias_to_legacy(decl)
        when IR::Interface
          interfaces << convert_interface_to_legacy(decl)
        when IR::ClassDecl
          classes << convert_class_to_legacy(decl)
        end
      end

      {
        type: :success,
        functions: functions,
        type_aliases: type_aliases,
        interfaces: interfaces,
        classes: classes,
      }
    end

    def convert_method_to_legacy(method_def)
      params = method_def.params.map do |param|
        {
          name: param.name,
          type: param.type_annotation&.to_s,
          ir_type: param.type_annotation,
          kind: param.kind || :required,
        }
      end

      {
        name: method_def.name,
        params: params,
        return_type: method_def.return_type&.to_s,
        ir_return_type: method_def.return_type,
        visibility: method_def.visibility || :public,
        body_ir: method_def.body,
      }
    end

    def convert_type_alias_to_legacy(type_alias)
      {
        name: type_alias.name,
        definition: type_alias.definition&.to_s,
        ir_type: type_alias.definition,
      }
    end

    def convert_interface_to_legacy(interface_def)
      members = interface_def.members.map do |member|
        {
          name: member[:name] || member.name,
          type: member[:type]&.to_s || member.type&.to_s,
          ir_type: member[:type] || member.type,
        }
      end

      { name: interface_def.name, members: members }
    end

    def convert_class_to_legacy(class_def)
      methods = (class_def.body || []).select { |d| d.is_a?(IR::MethodDef) }.map do |m|
        convert_method_to_legacy(m)
      end

      {
        name: class_def.name,
        superclass: class_def.superclass,
        methods: methods,
        instance_vars: [],
      }
    end

    # @deprecated Legacy regex-based parser. Will be removed in future version.
    # Use `use_token_parser: true` or set TRUBY_NEW_PARSER=1 to use the new parser.
    def parse_with_legacy_parser
      emit_deprecation_warning
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

      # Build IR
      builder = IR::Builder.new
      @ir_program = builder.build(result, source: @source)

      result
    end

    public

    # Parse to IR directly (new API)
    def parse_to_ir
      parse unless @ir_program
      @ir_program
    end

    # Parse a type expression using combinator
    def parse_type(type_string)
      result = @type_parser.parse(type_string)
      result[:success] ? result[:type] : nil
    end

    private

    # 최상위 함수를 본문까지 포함하여 파싱
    def parse_function_with_body(start_index)
      line = @lines[start_index]
      func_info = parse_function_definition(line, line_number: start_index + 1)
      return [nil, start_index] unless func_info

      # Add location info (1-based line number, column is 1 + indentation)
      def_indent = line.match(/^(\s*)/)[1].length
      func_info[:line] = start_index + 1
      func_info[:column] = def_indent + 1

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

      # Use combinator for complex type parsing
      type_result = @type_parser.parse(definition)
      if type_result[:success]
        return {
          name: alias_name,
          definition: definition,
          ir_type: type_result[:type],
        }
      end

      {
        name: alias_name,
        definition: definition,
      }
    end

    def parse_function_definition(line, line_number: 1) # rubocop:disable Lint/UnusedMethodArgument
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

      # Parse return type with combinator
      if return_type_str
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
        param = param.strip

        # 1. 더블 스플랫: **name: Type
        if param.start_with?("**")
          param_info = parse_double_splat_parameter(param)
          parameters << param_info if param_info
        # 2. 키워드 인자 그룹: { ... } 또는 { ... }: InterfaceName
        elsif param.start_with?("{")
          keyword_params = parse_keyword_args_group(param)
          parameters.concat(keyword_params) if keyword_params
        # 3. Hash 리터럴: name: { ... }
        elsif param.match?(/^\w+:\s*\{/)
          param_info = parse_hash_literal_parameter(param)
          parameters << param_info if param_info
        # 4. Block parameter: &block or &block: Type
        elsif param.start_with?("&")
          param_info = parse_block_parameter(param)
          parameters << param_info if param_info
        # 5. 일반 위치 인자: name: Type 또는 name: Type = default
        else
          param_info = parse_single_parameter(param)
          parameters << param_info if param_info
        end
      end

      parameters
    end

    def split_params(params_str)
      # Handle nested generics, braces, brackets
      result = []
      current = ""
      depth = 0
      brace_depth = 0

      params_str.each_char do |char|
        case char
        when "<", "[", "("
          depth += 1
          current += char
        when ">", "]", ")"
          depth -= 1
          current += char
        when "{"
          brace_depth += 1
          current += char
        when "}"
          brace_depth -= 1
          current += char
        when ","
          if depth.zero? && brace_depth.zero?
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

    # 더블 스플랫 파라미터 파싱: **opts: Type
    def parse_double_splat_parameter(param)
      # **name: Type
      match = param.match(/^\*\*(\w+)(?::\s*(.+?))?$/)
      return nil unless match

      param_name = match[1]
      type_str = match[2]&.strip

      result = {
        name: param_name,
        type: type_str,
        kind: :keyrest,
      }

      if type_str
        type_result = @type_parser.parse(type_str)
        result[:ir_type] = type_result[:type] if type_result[:success]
      end

      result
    end

    # Block parameter parsing: &block or &block: Proc(T) -> R
    def parse_block_parameter(param)
      # &name or &name? or &name: Type or &name?: Type
      match = param.match(/^&(\w+)(\?)?(?::\s*(.+?))?$/)
      return nil unless match

      param_name = match[1]
      optional = !match[2].nil?
      type_str = match[3]&.strip

      result = {
        name: param_name,
        type: type_str,
        kind: :block,
        optional: optional,
      }

      if type_str
        type_result = @type_parser.parse(type_str)
        result[:ir_type] = type_result[:type] if type_result[:success]
      end

      result
    end

    # 키워드 인자 그룹 파싱: { name: String, age: Integer = 0 } 또는 { name:, age: 0 }: InterfaceName
    def parse_keyword_args_group(param)
      # { ... }: InterfaceName 형태 확인
      # 또는 { ... } 만 있는 형태 (인라인 타입)
      interface_match = param.match(/^\{(.+)\}\s*:\s*(\w+)\s*$/)
      inline_match = param.match(/^\{(.+)\}\s*$/) unless interface_match

      if interface_match
        inner_content = interface_match[1]
        interface_name = interface_match[2]
        parse_keyword_args_with_interface(inner_content, interface_name)
      elsif inline_match
        inner_content = inline_match[1]
        parse_keyword_args_inline(inner_content)
      end
    end

    # interface 참조 키워드 인자 파싱: { name:, age: 0 }: UserParams
    def parse_keyword_args_with_interface(inner_content, interface_name)
      parameters = []
      parts = split_keyword_args(inner_content)

      parts.each do |part|
        part = part.strip
        next if part.empty?

        # name: default_value 또는 name: 형태
        next unless part.match?(/^(\w+):\s*(.*)$/)

        match = part.match(/^(\w+):\s*(.*)$/)
        param_name = match[1]
        default_value = match[2].strip
        default_value = nil if default_value.empty?

        parameters << {
          name: param_name,
          type: nil, # interface에서 타입을 가져옴
          default_value: default_value,
          kind: :keyword,
          interface_ref: interface_name,
        }
      end

      parameters
    end

    # 인라인 타입 키워드 인자 파싱: { name: String, age: Integer = 0 }
    def parse_keyword_args_inline(inner_content)
      parameters = []
      parts = split_keyword_args(inner_content)

      parts.each do |part|
        part = part.strip
        next if part.empty?

        # name: Type = default 또는 name: Type 형태
        next unless part.match?(/^(\w+):\s*(.+)$/)

        match = part.match(/^(\w+):\s*(.+)$/)
        param_name = match[1]
        type_and_default = match[2].strip

        # Type = default 분리
        type_str, default_value = split_type_and_default(type_and_default)

        result = {
          name: param_name,
          type: type_str,
          default_value: default_value,
          kind: :keyword,
        }

        if type_str
          type_result = @type_parser.parse(type_str)
          result[:ir_type] = type_result[:type] if type_result[:success]
        end

        parameters << result
      end

      parameters
    end

    # 키워드 인자 내부를 콤마로 분리 (중첩된 제네릭/배열/해시 고려)
    def split_keyword_args(content)
      StringUtils.split_by_comma(content)
    end

    # 타입과 기본값 분리: "String = 0" -> ["String", "0"]
    def split_type_and_default(type_and_default)
      StringUtils.split_type_and_default(type_and_default)
    end

    # Hash 리터럴 파라미터 파싱: config: { host: String, port: Integer }
    def parse_hash_literal_parameter(param)
      # name: { ... } 또는 name: { ... }: InterfaceName
      match = param.match(/^(\w+):\s*(\{.+\})(?::\s*(\w+))?$/)
      return nil unless match

      param_name = match[1]
      hash_type = match[2]
      interface_name = match[3]

      result = {
        name: param_name,
        type: interface_name || hash_type,
        kind: :required,
        hash_type_def: hash_type, # 원본 해시 타입 정의 저장
      }

      result[:interface_ref] = interface_name if interface_name

      result
    end

    def parse_single_parameter(param)
      # name: Type = default 또는 name: Type 또는 name
      # 기본값이 있는 경우 먼저 처리
      type_str = nil
      default_value = nil

      if param.include?(":")
        match = param.match(/^(\w+):\s*(.+)$/)
        return nil unless match

        param_name = match[1]
        type_and_default = match[2].strip
        type_str, default_value = split_type_and_default(type_and_default)
      else
        # 타입 없이 이름만 있는 경우
        param_name = param.strip
      end

      result = {
        name: param_name,
        type: type_str,
        default_value: default_value,
        kind: default_value ? :optional : :required,
      }

      # Parse type with combinator
      if type_str
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
      method_info = parse_function_definition(line, line_number: start_index + 1)
      return [nil, start_index] unless method_info

      # Add location info (1-based line number, column is 1 + indentation)
      def_indent = line.match(/^(\s*)/)[1].length
      method_info[:line] = start_index + 1
      method_info[:column] = def_indent + 1

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
            type_result = @type_parser.parse(member[:type])
            member[:ir_type] = type_result[:type] if type_result[:success]

            members << member
          end
        end

        i += 1
      end

      [{ name: interface_name, members: members }, i]
    end

    # Emit deprecation warning for legacy parser (once per process)
    def emit_deprecation_warning
      return if self.class.deprecation_warned?

      self.class.mark_deprecation_warned
      warn "[DEPRECATION] The regex-based parser is deprecated and will be removed in a future version. " \
           "Set TRUBY_NEW_PARSER=1 or use `use_token_parser: true` to opt into the new TokenDeclarationParser."
    end

    class << self
      def deprecation_warned?
        @deprecation_warned ||= false
      end

      def mark_deprecation_warned
        @deprecation_warned = true
      end
    end
  end
end
