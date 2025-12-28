# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Expression Parser - Parse expressions into IR nodes
    # Uses Pratt parser (operator precedence parsing) for correct precedence
    class ExpressionParser
      include TokenDSL

      # Operator precedence levels (higher = binds tighter)
      PRECEDENCE = {
        or_or: 1,      # ||
        and_and: 2,    # &&
        eq_eq: 3,      # ==
        bang_eq: 3,    # !=
        lt: 4,         # <
        gt: 4,         # >
        lt_eq: 4,      # <=
        gt_eq: 4,      # >=
        spaceship: 4,  # <=>
        pipe: 5,       # | (bitwise or)
        amp: 6,        # & (bitwise and)
        plus: 7,       # +
        minus: 7,      # -
        star: 8,       # *
        slash: 8,      # /
        percent: 8,    # %
        star_star: 9,  # ** (right-associative)
      }.freeze

      # Right-associative operators
      RIGHT_ASSOC = Set.new([:star_star]).freeze

      # Token type to operator symbol mapping
      OPERATOR_SYMBOLS = {
        or_or: :"||",
        and_and: :"&&",
        eq_eq: :==,
        bang_eq: :!=,
        lt: :<,
        gt: :>,
        lt_eq: :<=,
        gt_eq: :>=,
        spaceship: :<=>,
        plus: :+,
        minus: :-,
        star: :*,
        slash: :/,
        percent: :%,
        star_star: :**,
        pipe: :|,
        amp: :&,
      }.freeze

      def parse_expression(tokens, position = 0)
        parse_precedence(tokens, position, 0)
      end

      private

      def parse_precedence(tokens, position, min_precedence)
        result = parse_unary(tokens, position)
        return result if result.failure?

        left = result.value
        pos = result.position

        loop do
          break if pos >= tokens.length || tokens[pos].type == :eof

          operator_type = tokens[pos].type
          precedence = PRECEDENCE[operator_type]
          break unless precedence && precedence >= min_precedence

          pos += 1 # consume operator

          # Handle right associativity
          next_min = RIGHT_ASSOC.include?(operator_type) ? precedence : precedence + 1
          right_result = parse_precedence(tokens, pos, next_min)
          return right_result if right_result.failure?

          right = right_result.value
          pos = right_result.position

          left = IR::BinaryOp.new(
            operator: OPERATOR_SYMBOLS[operator_type],
            left: left,
            right: right
          )
        end

        TokenParseResult.success(left, tokens, pos)
      end

      def parse_unary(tokens, position)
        return TokenParseResult.failure("End of input", tokens, position) if position >= tokens.length

        token = tokens[position]

        case token.type
        when :bang
          result = parse_unary(tokens, position + 1)
          return result if result.failure?
          node = IR::UnaryOp.new(operator: :!, operand: result.value)
          TokenParseResult.success(node, tokens, result.position)
        when :minus
          result = parse_unary(tokens, position + 1)
          return result if result.failure?
          # For negative number literals, we could fold them
          if result.value.is_a?(IR::Literal) && result.value.literal_type == :integer
            node = IR::Literal.new(value: -result.value.value, literal_type: :integer)
          elsif result.value.is_a?(IR::Literal) && result.value.literal_type == :float
            node = IR::Literal.new(value: -result.value.value, literal_type: :float)
          else
            node = IR::UnaryOp.new(operator: :-, operand: result.value)
          end
          TokenParseResult.success(node, tokens, result.position)
        else
          parse_postfix(tokens, position)
        end
      end

      def parse_postfix(tokens, position)
        result = parse_primary(tokens, position)
        return result if result.failure?

        left = result.value
        pos = result.position

        loop do
          break if pos >= tokens.length || tokens[pos].type == :eof

          case tokens[pos].type
          when :dot
            # Method call with receiver: obj.method or obj.method(args)
            pos += 1
            return TokenParseResult.failure("Expected method name after '.'", tokens, pos) if pos >= tokens.length

            method_token = tokens[pos]
            unless method_token.type == :identifier || keywords.key?(method_token.value)
              return TokenParseResult.failure("Expected method name", tokens, pos)
            end

            method_name = method_token.value
            pos += 1

            # Check for arguments
            args = []
            if pos < tokens.length && tokens[pos].type == :lparen
              args_result = parse_arguments(tokens, pos)
              return args_result if args_result.failure?
              args = args_result.value
              pos = args_result.position
            end

            left = IR::MethodCall.new(
              receiver: left,
              method_name: method_name,
              arguments: args
            )
          when :lbracket
            # Array access: arr[index]
            pos += 1
            index_result = parse_expression(tokens, pos)
            return index_result if index_result.failure?

            pos = index_result.position
            return TokenParseResult.failure("Expected ']'", tokens, pos) unless tokens[pos]&.type == :rbracket
            pos += 1

            left = IR::MethodCall.new(
              receiver: left,
              method_name: "[]",
              arguments: [index_result.value]
            )
          when :lparen
            # Function call without explicit receiver (left is identifier -> method call)
            if left.is_a?(IR::VariableRef) && left.scope == :local
              args_result = parse_arguments(tokens, pos)
              return args_result if args_result.failure?

              left = IR::MethodCall.new(
                method_name: left.name,
                arguments: args_result.value
              )
              pos = args_result.position
            else
              break
            end
          else
            break
          end
        end

        TokenParseResult.success(left, tokens, pos)
      end

      def parse_primary(tokens, position)
        return TokenParseResult.failure("End of input", tokens, position) if position >= tokens.length

        token = tokens[position]

        case token.type
        when :integer
          node = IR::Literal.new(value: token.value.to_i, literal_type: :integer)
          TokenParseResult.success(node, tokens, position + 1)

        when :float
          node = IR::Literal.new(value: token.value.to_f, literal_type: :float)
          TokenParseResult.success(node, tokens, position + 1)

        when :string
          # Remove quotes from string value
          value = token.value[1..-2]
          node = IR::Literal.new(value: value, literal_type: :string)
          TokenParseResult.success(node, tokens, position + 1)

        when :string_start
          # Interpolated string: string_start, string_content*, string_end
          parse_interpolated_string(tokens, position)

        when :symbol
          # Remove : from symbol value
          value = token.value[1..].to_sym
          node = IR::Literal.new(value: value, literal_type: :symbol)
          TokenParseResult.success(node, tokens, position + 1)

        when :true
          node = IR::Literal.new(value: true, literal_type: :boolean)
          TokenParseResult.success(node, tokens, position + 1)

        when :false
          node = IR::Literal.new(value: false, literal_type: :boolean)
          TokenParseResult.success(node, tokens, position + 1)

        when :nil
          node = IR::Literal.new(value: nil, literal_type: :nil)
          TokenParseResult.success(node, tokens, position + 1)

        when :identifier
          node = IR::VariableRef.new(name: token.value, scope: :local)
          TokenParseResult.success(node, tokens, position + 1)

        when :constant
          node = IR::VariableRef.new(name: token.value, scope: :constant)
          TokenParseResult.success(node, tokens, position + 1)

        when :ivar
          node = IR::VariableRef.new(name: token.value, scope: :instance)
          TokenParseResult.success(node, tokens, position + 1)

        when :cvar
          node = IR::VariableRef.new(name: token.value, scope: :class)
          TokenParseResult.success(node, tokens, position + 1)

        when :gvar
          node = IR::VariableRef.new(name: token.value, scope: :global)
          TokenParseResult.success(node, tokens, position + 1)

        when :lparen
          # Parenthesized expression
          result = parse_expression(tokens, position + 1)
          return result if result.failure?

          pos = result.position
          return TokenParseResult.failure("Expected ')'", tokens, pos) unless tokens[pos]&.type == :rparen
          TokenParseResult.success(result.value, tokens, pos + 1)

        when :lbracket
          # Array literal
          parse_array_literal(tokens, position)

        when :lbrace
          # Hash literal
          parse_hash_literal(tokens, position)

        else
          TokenParseResult.failure("Unexpected token: #{token.type}", tokens, position)
        end
      end

      def parse_arguments(tokens, position)
        return TokenParseResult.failure("Expected '('", tokens, position) unless tokens[position]&.type == :lparen
        position += 1

        args = []

        # Empty arguments
        if tokens[position]&.type == :rparen
          return TokenParseResult.success(args, tokens, position + 1)
        end

        # Parse first argument
        result = parse_expression(tokens, position)
        return result if result.failure?
        args << result.value
        position = result.position

        # Parse remaining arguments
        while tokens[position]&.type == :comma
          position += 1
          result = parse_expression(tokens, position)
          return result if result.failure?
          args << result.value
          position = result.position
        end

        return TokenParseResult.failure("Expected ')'", tokens, position) unless tokens[position]&.type == :rparen
        TokenParseResult.success(args, tokens, position + 1)
      end

      def parse_array_literal(tokens, position)
        return TokenParseResult.failure("Expected '['", tokens, position) unless tokens[position]&.type == :lbracket
        position += 1

        elements = []

        # Empty array
        if tokens[position]&.type == :rbracket
          node = IR::ArrayLiteral.new(elements: elements)
          return TokenParseResult.success(node, tokens, position + 1)
        end

        # Parse first element
        result = parse_expression(tokens, position)
        return result if result.failure?
        elements << result.value
        position = result.position

        # Parse remaining elements
        while tokens[position]&.type == :comma
          position += 1
          result = parse_expression(tokens, position)
          return result if result.failure?
          elements << result.value
          position = result.position
        end

        return TokenParseResult.failure("Expected ']'", tokens, position) unless tokens[position]&.type == :rbracket
        node = IR::ArrayLiteral.new(elements: elements)
        TokenParseResult.success(node, tokens, position + 1)
      end

      def parse_hash_literal(tokens, position)
        return TokenParseResult.failure("Expected '{'", tokens, position) unless tokens[position]&.type == :lbrace
        position += 1

        pairs = []

        # Empty hash
        if tokens[position]&.type == :rbrace
          node = IR::HashLiteral.new(pairs: pairs)
          return TokenParseResult.success(node, tokens, position + 1)
        end

        # Parse first pair
        pair_result = parse_hash_pair(tokens, position)
        return pair_result if pair_result.failure?
        pairs << pair_result.value
        position = pair_result.position

        # Parse remaining pairs
        while tokens[position]&.type == :comma
          position += 1
          pair_result = parse_hash_pair(tokens, position)
          return pair_result if pair_result.failure?
          pairs << pair_result.value
          position = pair_result.position
        end

        return TokenParseResult.failure("Expected '}'", tokens, position) unless tokens[position]&.type == :rbrace
        node = IR::HashLiteral.new(pairs: pairs)
        TokenParseResult.success(node, tokens, position + 1)
      end

      def parse_hash_pair(tokens, position)
        # Handle symbol key shorthand: key: value
        if tokens[position]&.type == :identifier && tokens[position + 1]&.type == :colon
          key = IR::Literal.new(value: tokens[position].value.to_sym, literal_type: :symbol)
          position += 2 # skip identifier and colon
        else
          # Parse key expression
          key_result = parse_expression(tokens, position)
          return key_result if key_result.failure?
          key = key_result.value
          position = key_result.position

          # Expect => or :
          if tokens[position]&.type == :colon
            position += 1
          else
            return TokenParseResult.failure("Expected ':' or '=>' in hash pair", tokens, position)
          end
        end

        # Parse value expression
        value_result = parse_expression(tokens, position)
        return value_result if value_result.failure?

        pair = IR::HashPair.new(key: key, value: value_result.value)
        TokenParseResult.success(pair, tokens, value_result.position)
      end

      def parse_interpolated_string(tokens, position)
        # string_start token contains the opening quote
        position += 1

        parts = []

        while position < tokens.length
          token = tokens[position]

          case token.type
          when :string_content
            parts << IR::Literal.new(value: token.value, literal_type: :string)
            position += 1
          when :interpolation_start
            # Skip #{ and parse expression
            position += 1
            expr_result = parse_expression(tokens, position)
            return expr_result if expr_result.failure?
            parts << expr_result.value
            position = expr_result.position

            # Expect interpolation_end (})
            if tokens[position]&.type == :interpolation_end
              position += 1
            else
              return TokenParseResult.failure("Expected '}'", tokens, position)
            end
          when :string_end
            position += 1
            break
          else
            return TokenParseResult.failure("Unexpected token in string: #{token.type}", tokens, position)
          end
        end

        # Create interpolated string node
        node = IR::InterpolatedString.new(parts: parts)
        TokenParseResult.success(node, tokens, position)
      end

      def keywords
        @keywords ||= TRuby::Scanner::KEYWORDS
      end
    end
  end
end
