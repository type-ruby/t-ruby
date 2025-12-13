# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Parse result - either success or failure
    class ParseResult
      attr_reader :value, :remaining, :position, :error

      def initialize(success:, value: nil, remaining: "", position: 0, error: nil)
        @success = success
        @value = value
        @remaining = remaining
        @position = position
        @error = error
      end

      def success?
        @success
      end

      def failure?
        !@success
      end

      def self.success(value, remaining, position)
        new(success: true, value: value, remaining: remaining, position: position)
      end

      def self.failure(error, remaining, position)
        new(success: false, error: error, remaining: remaining, position: position)
      end

      def map
        return self if failure?

        ParseResult.success(yield(value), remaining, position)
      end

      def flat_map
        return self if failure?

        yield(value, remaining, position)
      end
    end

    # Base parser class
    class Parser
      def parse(input, position = 0)
        raise NotImplementedError
      end

      # Combinators as methods

      # Sequence: run this parser, then the other
      def >>(other)
        Sequence.new(self, other)
      end

      # Alternative: try this parser, if it fails try the other
      def |(other)
        Alternative.new(self, other)
      end

      # Map: transform the result
      def map(&block)
        Map.new(self, block)
      end

      # FlatMap: transform with another parser
      def flat_map(&block)
        FlatMap.new(self, block)
      end

      # Many: zero or more repetitions
      def many
        Many.new(self)
      end

      # Many1: one or more repetitions
      def many1
        Many1.new(self)
      end

      # Optional: zero or one
      def optional
        Optional.new(self)
      end

      # Separated by: parse items separated by delimiter
      def sep_by(delimiter)
        SepBy.new(self, delimiter)
      end

      # Separated by 1: at least one item
      def sep_by1(delimiter)
        SepBy1.new(self, delimiter)
      end

      # Between: parse between left and right delimiters
      def between(left, right)
        (left >> self << right).map { |(_, val)| val }
      end

      # Skip right: parse both, keep left result
      def <<(other)
        SkipRight.new(self, other)
      end

      # Label: add a descriptive label for error messages
      def label(name)
        Label.new(self, name)
      end

      # Lookahead: check without consuming
      def lookahead
        Lookahead.new(self)
      end

      # Not: succeed only if parser fails
      def not_followed_by
        NotFollowedBy.new(self)
      end
    end

    #==========================================================================
    # Primitive Parsers
    #==========================================================================

    # Parse a literal string
    class Literal < Parser
      def initialize(string)
        @string = string
      end

      def parse(input, position = 0)
        remaining = input[position..]
        if remaining&.start_with?(@string)
          ParseResult.success(@string, input, position + @string.length)
        else
          ParseResult.failure("Expected '#{@string}'", input, position)
        end
      end
    end

    # Parse a single character matching predicate
    class Satisfy < Parser
      def initialize(predicate, description = "character")
        @predicate = predicate
        @description = description
      end

      def parse(input, position = 0)
        if position < input.length && @predicate.call(input[position])
          ParseResult.success(input[position], input, position + 1)
        else
          ParseResult.failure("Expected #{@description}", input, position)
        end
      end
    end

    # Parse using regex
    class Regex < Parser
      def initialize(pattern, description = nil)
        @pattern = pattern.is_a?(Regexp) ? pattern : Regexp.new("^#{pattern}")
        @description = description || @pattern.inspect
      end

      def parse(input, position = 0)
        remaining = input[position..]
        match = @pattern.match(remaining)

        if match&.begin(0)&.zero?
          matched = match[0]
          ParseResult.success(matched, input, position + matched.length)
        else
          ParseResult.failure("Expected #{@description}", input, position)
        end
      end
    end

    # Parse end of input
    class EndOfInput < Parser
      def parse(input, position = 0)
        if position >= input.length
          ParseResult.success(nil, input, position)
        else
          ParseResult.failure("Expected end of input", input, position)
        end
      end
    end

    # Always succeed with a value
    class Pure < Parser
      def initialize(value)
        @value = value
      end

      def parse(input, position = 0)
        ParseResult.success(@value, input, position)
      end
    end

    # Always fail
    class Fail < Parser
      def initialize(message)
        @message = message
      end

      def parse(input, position = 0)
        ParseResult.failure(@message, input, position)
      end
    end

    # Lazy parser (for recursive grammars)
    class Lazy < Parser
      def initialize(&block)
        @block = block
        @parser = nil
      end

      def parse(input, position = 0)
        @parser ||= @block.call
        @parser.parse(input, position)
      end
    end

    #==========================================================================
    # Combinator Parsers
    #==========================================================================

    # Sequence two parsers
    class Sequence < Parser
      def initialize(left, right)
        @left = left
        @right = right
      end

      def parse(input, position = 0)
        result1 = @left.parse(input, position)
        return result1 if result1.failure?

        result2 = @right.parse(input, result1.position)
        return result2 if result2.failure?

        ParseResult.success([result1.value, result2.value], input, result2.position)
      end
    end

    # Alternative: try first, if fails try second
    class Alternative < Parser
      def initialize(left, right)
        @left = left
        @right = right
      end

      def parse(input, position = 0)
        result = @left.parse(input, position)
        return result if result.success?

        @right.parse(input, position)
      end
    end

    # Map result
    class Map < Parser
      def initialize(parser, func)
        @parser = parser
        @func = func
      end

      def parse(input, position = 0)
        @parser.parse(input, position).map(&@func)
      end
    end

    # FlatMap (bind)
    class FlatMap < Parser
      def initialize(parser, func)
        @parser = parser
        @func = func
      end

      def parse(input, position = 0)
        result = @parser.parse(input, position)
        return result if result.failure?

        next_parser = @func.call(result.value)
        next_parser.parse(input, result.position)
      end
    end

    # Many: zero or more
    class Many < Parser
      def initialize(parser)
        @parser = parser
      end

      def parse(input, position = 0)
        results = []
        current_pos = position

        loop do
          result = @parser.parse(input, current_pos)
          break if result.failure?

          results << result.value
          break if result.position == current_pos # Prevent infinite loop

          current_pos = result.position
        end

        ParseResult.success(results, input, current_pos)
      end
    end

    # Many1: one or more
    class Many1 < Parser
      def initialize(parser)
        @parser = parser
      end

      def parse(input, position = 0)
        first = @parser.parse(input, position)
        return first if first.failure?

        results = [first.value]
        current_pos = first.position

        loop do
          result = @parser.parse(input, current_pos)
          break if result.failure?

          results << result.value
          break if result.position == current_pos

          current_pos = result.position
        end

        ParseResult.success(results, input, current_pos)
      end
    end

    # Optional: zero or one
    class Optional < Parser
      def initialize(parser)
        @parser = parser
      end

      def parse(input, position = 0)
        result = @parser.parse(input, position)
        if result.success?
          result
        else
          ParseResult.success(nil, input, position)
        end
      end
    end

    # Separated by delimiter
    class SepBy < Parser
      def initialize(parser, delimiter)
        @parser = parser
        @delimiter = delimiter
      end

      def parse(input, position = 0)
        first = @parser.parse(input, position)
        return ParseResult.success([], input, position) if first.failure?

        results = [first.value]
        current_pos = first.position

        loop do
          delim_result = @delimiter.parse(input, current_pos)
          break if delim_result.failure?

          item_result = @parser.parse(input, delim_result.position)
          break if item_result.failure?

          results << item_result.value
          current_pos = item_result.position
        end

        ParseResult.success(results, input, current_pos)
      end
    end

    # Separated by 1 (at least one)
    class SepBy1 < Parser
      def initialize(parser, delimiter)
        @parser = parser
        @delimiter = delimiter
      end

      def parse(input, position = 0)
        first = @parser.parse(input, position)
        return first if first.failure?

        results = [first.value]
        current_pos = first.position

        loop do
          delim_result = @delimiter.parse(input, current_pos)
          break if delim_result.failure?

          item_result = @parser.parse(input, delim_result.position)
          break if item_result.failure?

          results << item_result.value
          current_pos = item_result.position
        end

        ParseResult.success(results, input, current_pos)
      end
    end

    # Skip right: parse both, return left
    class SkipRight < Parser
      def initialize(left, right)
        @left = left
        @right = right
      end

      def parse(input, position = 0)
        result1 = @left.parse(input, position)
        return result1 if result1.failure?

        result2 = @right.parse(input, result1.position)
        return result2 if result2.failure?

        ParseResult.success(result1.value, input, result2.position)
      end
    end

    # Label for error messages
    class Label < Parser
      def initialize(parser, name)
        @parser = parser
        @name = name
      end

      def parse(input, position = 0)
        result = @parser.parse(input, position)
        if result.failure?
          ParseResult.failure("Expected #{@name}", input, position)
        else
          result
        end
      end
    end

    # Lookahead: check without consuming
    class Lookahead < Parser
      def initialize(parser)
        @parser = parser
      end

      def parse(input, position = 0)
        result = @parser.parse(input, position)
        if result.success?
          ParseResult.success(result.value, input, position)
        else
          result
        end
      end
    end

    # Not followed by
    class NotFollowedBy < Parser
      def initialize(parser)
        @parser = parser
      end

      def parse(input, position = 0)
        result = @parser.parse(input, position)
        if result.failure?
          ParseResult.success(nil, input, position)
        else
          ParseResult.failure("Unexpected match", input, position)
        end
      end
    end

    # Choice: try multiple parsers in order
    class Choice < Parser
      def initialize(*parsers)
        @parsers = parsers
      end

      def parse(input, position = 0)
        best_error = nil
        best_position = position

        @parsers.each do |parser|
          result = parser.parse(input, position)
          return result if result.success?

          if result.position >= best_position
            best_error = result.error
            best_position = result.position
          end
        end

        ParseResult.failure(best_error || "No alternative matched", input, best_position)
      end
    end

    # Chainl: left-associative chain
    class ChainLeft < Parser
      def initialize(term, op)
        @term = term
        @op = op
      end

      def parse(input, position = 0)
        first = @term.parse(input, position)
        return first if first.failure?

        result = first.value
        current_pos = first.position

        loop do
          op_result = @op.parse(input, current_pos)
          break if op_result.failure?

          term_result = @term.parse(input, op_result.position)
          break if term_result.failure?

          result = op_result.value.call(result, term_result.value)
          current_pos = term_result.position
        end

        ParseResult.success(result, input, current_pos)
      end
    end

    #==========================================================================
    # DSL Module - Convenience methods
    #==========================================================================

    module DSL
      def literal(str)
        Literal.new(str)
      end

      def regex(pattern, description = nil)
        Regex.new(pattern, description)
      end

      def satisfy(description = "character", &predicate)
        Satisfy.new(predicate, description)
      end

      def char(c)
        Literal.new(c)
      end

      def string(str)
        Literal.new(str)
      end

      def eof
        EndOfInput.new
      end

      def pure(value)
        Pure.new(value)
      end

      def fail(message)
        Fail.new(message)
      end

      def lazy(&)
        Lazy.new(&)
      end

      def choice(*parsers)
        Choice.new(*parsers)
      end

      def sequence(*parsers)
        parsers.reduce { |acc, p| acc >> p }
      end

      # Common character parsers
      def digit
        satisfy("digit") { |c| c =~ /[0-9]/ }
      end

      def letter
        satisfy("letter") { |c| c =~ /[a-zA-Z]/ }
      end

      def alphanumeric
        satisfy("alphanumeric") { |c| c =~ /[a-zA-Z0-9]/ }
      end

      def whitespace
        satisfy("whitespace") { |c| c =~ /\s/ }
      end

      def spaces
        whitespace.many.map(&:join)
      end

      def spaces1
        whitespace.many1.map(&:join)
      end

      def newline
        char("\n") | string("\r\n")
      end

      def identifier
        (letter >> (alphanumeric | char("_")).many).map do |(first, rest)|
          first + rest.join
        end
      end

      def integer
        (char("-").optional >> digit.many1).map do |(sign, digits)|
          num = digits.join.to_i
          sign ? -num : num
        end
      end

      def float
        regex(/-?\d+\.\d+/, "float").map(&:to_f)
      end

      def quoted_string(quote = '"')
        content = satisfy("string character") { |c| c != quote && c != "\\" }
        escape = (char("\\") >> satisfy("escape char")).map { |(_bs, c)| c }

        (char(quote) >> (content | escape).many.map(&:join) << char(quote)).map { |(_, str)| str }
      end

      # Skip whitespace around parser
      def lexeme(parser)
        (spaces >> parser << spaces).map { |(_, val)| val }
      end

      # Chain for left-associative operators
      def chainl(term, op)
        ChainLeft.new(term, op)
      end
    end

    #==========================================================================
    # Type Parser - Parse T-Ruby type expressions
    #==========================================================================

    class TypeParser
      include DSL

      def initialize
        build_parsers
      end

      def parse(input)
        result = @type_expr.parse(input.strip)
        if result.success?
          { success: true, type: result.value, remaining: input[result.position..] }
        else
          { success: false, error: result.error, position: result.position }
        end
      end

      private

      def build_parsers
        # Identifier (type name)
        type_name = identifier.label("type name")

        # Simple type
        type_name.map { |name| IR::SimpleType.new(name: name) }

        # Lazy reference for recursive types
        type_expr = lazy { @type_expr }

        # Generic type arguments: <Type, Type, ...>
        generic_args = (
          lexeme(char("<")) >>
          type_expr.sep_by1(lexeme(char(","))) <<
          lexeme(char(">"))
        ).map { |(_, types)| types }

        # Generic type: Base<Args>
        generic_type = (type_name >> generic_args.optional).map do |(name, args)|
          if args && !args.empty?
            IR::GenericType.new(base: name, type_args: args)
          else
            IR::SimpleType.new(name: name)
          end
        end

        # Nullable type: Type?
        nullable_suffix = char("?")

        # Parenthesized type
        paren_type = (lexeme(char("(")) >> type_expr << lexeme(char(")"))).map { |(_, t)| t }

        # Function type: (Params) -> ReturnType
        param_list = (
          lexeme(char("(")) >>
          type_expr.sep_by(lexeme(char(","))) <<
          lexeme(char(")"))
        ).map { |(_, params)| params }

        arrow = lexeme(string("->"))

        function_type = (param_list >> arrow >> type_expr).map do |((params, _arrow), ret)|
          IR::FunctionType.new(param_types: params, return_type: ret)
        end

        # Tuple type: [Type, Type, ...]
        tuple_type = (
          lexeme(char("[")) >>
          type_expr.sep_by1(lexeme(char(","))) <<
          lexeme(char("]"))
        ).map { |(_, types)| IR::TupleType.new(element_types: types) }

        # Primary type (before operators)
        primary_type = choice(
          function_type,
          tuple_type,
          paren_type,
          generic_type
        )

        # With optional nullable suffix
        base_type = (primary_type >> nullable_suffix.optional).map do |(type, nullable)|
          nullable ? IR::NullableType.new(inner_type: type) : type
        end

        # Union type: Type | Type | ...
        union_op = lexeme(char("|"))
        union_type = base_type.sep_by1(union_op).map do |types|
          types.length == 1 ? types.first : IR::UnionType.new(types: types)
        end

        # Intersection type: Type & Type & ...
        intersection_op = lexeme(char("&"))
        @type_expr = union_type.sep_by1(intersection_op).map do |types|
          types.length == 1 ? types.first : IR::IntersectionType.new(types: types)
        end
      end
    end

    #==========================================================================
    # Declaration Parser - Parse T-Ruby declarations
    #==========================================================================

    class DeclarationParser
      include DSL

      def initialize
        @type_parser = TypeParser.new
        build_parsers
      end

      def parse(input)
        result = @declaration.parse(input.strip)
        if result.success?
          { success: true, declarations: result.value }
        else
          { success: false, error: result.error, position: result.position }
        end
      end

      def parse_file(input)
        result = @program.parse(input)
        if result.success?
          { success: true, declarations: result.value.compact }
        else
          { success: false, error: result.error, position: result.position }
        end
      end

      private

      def build_parsers
        # Type expression (delegate to TypeParser)
        lazy { parse_type_inline }

        # Keywords
        kw_type = lexeme(string("type"))
        kw_interface = lexeme(string("interface"))
        kw_def = lexeme(string("def"))
        kw_end = lexeme(string("end"))
        lexeme(string("class"))
        lexeme(string("module"))

        # Type alias: type Name = Definition
        type_alias = (
          kw_type >>
          lexeme(identifier) <<
          lexeme(char("=")) >>
          regex(/[^\n]+/).map(&:strip)
        ).map do |((_, name), definition)|
          type_result = @type_parser.parse(definition)
          if type_result[:success]
            IR::TypeAlias.new(name: name, definition: type_result[:type])
          end
        end

        # Interface member: name: Type
        interface_member = (
          lexeme(identifier) <<
          lexeme(char(":")) >>
          regex(/[^\n]+/).map(&:strip)
        ).map do |(name, type_str)|
          type_result = @type_parser.parse(type_str)
          if type_result[:success]
            IR::InterfaceMember.new(name: name, type_signature: type_result[:type])
          end
        end

        # Interface: interface Name ... end
        interface_body = (interface_member << (newline | spaces)).many

        interface_decl = (
          kw_interface >>
          lexeme(identifier) <<
          (newline | spaces) >>
          interface_body <<
          kw_end
        ).map do |((_, name), members)|
          IR::Interface.new(name: name, members: members.compact)
        end

        # Parameter: name: Type or name
        param = (
          identifier >>
          (lexeme(char(":")) >> regex(/[^,)]+/).map(&:strip)).optional
        ).map do |(name, type_str)|
          type_node = if type_str
                        type_str_val = type_str.is_a?(Array) ? type_str.last : type_str
                        result = @type_parser.parse(type_str_val)
                        result[:success] ? result[:type] : nil
                      end
          IR::Parameter.new(name: name, type_annotation: type_node)
        end

        # Parameters list
        params_list = (
          lexeme(char("(")) >>
          param.sep_by(lexeme(char(","))) <<
          lexeme(char(")"))
        ).map { |(_, params)| params }

        # Return type annotation
        return_type = (
          lexeme(char(":")) >>
          regex(/[^\n]+/).map(&:strip)
        ).map { |(_, type_str)| type_str }.optional

        # Method definition: def name(params): ReturnType
        method_def = (
          kw_def >>
          identifier >>
          params_list.optional >>
          return_type
        ).map do |(((_, name), params), ret_str)|
          ret_type = if ret_str
                       result = @type_parser.parse(ret_str)
                       result[:success] ? result[:type] : nil
                     end
          IR::MethodDef.new(
            name: name,
            params: params || [],
            return_type: ret_type
          )
        end

        # Any declaration
        @declaration = choice(
          type_alias,
          interface_decl,
          method_def
        )

        # Line (declaration or empty)
        line = (@declaration << (newline | eof)) | (spaces >> newline).map { nil }

        # Program (multiple declarations)
        @program = line.many
      end

      def parse_type_inline
        Lazy.new { @type_parser.instance_variable_get(:@type_expr) }
      end
    end

    #==========================================================================
    # Error Reporting
    #==========================================================================

    class ParseError
      attr_reader :message, :position, :line, :column, :input

      def initialize(message:, position:, input:)
        @message = message
        @position = position
        @input = input
        @line, @column = calculate_line_column
      end

      def to_s
        "Parse error at line #{@line}, column #{@column}: #{@message}"
      end

      def context(lines_before: 2, lines_after: 1)
        input_lines = @input.split("\n")
        start_line = [@line - lines_before - 1, 0].max
        end_line = [@line + lines_after - 1, input_lines.length - 1].min

        result = []
        (start_line..end_line).each do |i|
          prefix = i == @line - 1 ? ">>> " : "    "
          result << "#{prefix}#{i + 1}: #{input_lines[i]}"

          if i == @line - 1
            result << "    #{" " * (@column + @line.to_s.length + 1)}^"
          end
        end

        result.join("\n")
      end

      private

      def calculate_line_column
        lines = @input[0...@position].split("\n", -1)
        line = lines.length
        column = lines.last&.length || 0
        [line, column + 1]
      end
    end
  end
end
