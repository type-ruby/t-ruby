# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Statement Parser - Parse statements into IR nodes
    class StatementParser
      include TokenDSL

      def initialize
        @expression_parser = ExpressionParser.new
      end

      def parse_statement(tokens, position = 0)
        return TokenParseResult.failure("End of input", tokens, position) if position >= tokens.length

        # Skip newlines
        position = skip_newlines(tokens, position)
        return TokenParseResult.failure("End of input", tokens, position) if position >= tokens.length

        token = tokens[position]

        case token.type
        when :return
          parse_return(tokens, position)
        when :if
          parse_if(tokens, position)
        when :unless
          parse_unless(tokens, position)
        when :while
          parse_while(tokens, position)
        when :until
          parse_until(tokens, position)
        when :case
          parse_case(tokens, position)
        when :begin
          parse_begin(tokens, position)
        else
          # Could be assignment or expression
          parse_assignment_or_expression(tokens, position)
        end
      end

      def parse_block(tokens, position = 0)
        statements = []

        loop do
          position = skip_newlines(tokens, position)
          break if position >= tokens.length

          token = tokens[position]
          break if token.type == :eof
          break if [:end, :else, :elsif, :when, :rescue, :ensure].include?(token.type)

          result = parse_statement(tokens, position)
          break if result.failure?

          statements << result.value
          position = result.position
        end

        node = IR::Block.new(statements: statements)
        TokenParseResult.success(node, tokens, position)
      end

      private

      def skip_newlines(tokens, position)
        while position < tokens.length && [:newline, :comment].include?(tokens[position].type)
          position += 1
        end
        position
      end

      def parse_return(tokens, position)
        position += 1 # consume 'return'

        # Check if there's a return value
        position = skip_newlines_if_not_modifier(tokens, position)

        if position >= tokens.length ||
           tokens[position].type == :eof ||
           tokens[position].type == :newline ||
           end_of_statement?(tokens, position)
          node = IR::Return.new(value: nil)
          return TokenParseResult.success(node, tokens, position)
        end

        # Parse return value expression
        expr_result = @expression_parser.parse_expression(tokens, position)
        return expr_result if expr_result.failure?

        # Check for modifier
        modifier_result = parse_modifier(tokens, expr_result.position, IR::Return.new(value: expr_result.value))
        return modifier_result if modifier_result.success? && modifier_result.value.is_a?(IR::Conditional)

        node = IR::Return.new(value: expr_result.value)
        TokenParseResult.success(node, tokens, expr_result.position)
      end

      def parse_if(tokens, position)
        position += 1 # consume 'if'

        # Parse condition
        cond_result = @expression_parser.parse_expression(tokens, position)
        return cond_result if cond_result.failure?
        position = cond_result.position

        # Skip newline after condition
        position = skip_newlines(tokens, position)

        # Parse then branch
        then_result = parse_block(tokens, position)
        position = then_result.position
        position = skip_newlines(tokens, position)

        # Check for elsif or else
        else_branch = nil
        if position < tokens.length && tokens[position].type == :elsif
          elsif_result = parse_if(tokens, position) # Reuse if parsing for elsif
          return elsif_result if elsif_result.failure?
          else_branch = elsif_result.value
          position = elsif_result.position
        elsif position < tokens.length && tokens[position].type == :else
          position += 1 # consume 'else'
          position = skip_newlines(tokens, position)
          else_result = parse_block(tokens, position)
          else_branch = else_result.value
          position = else_result.position
          position = skip_newlines(tokens, position)
        end

        # Expect 'end' (unless it was an elsif chain)
        if position < tokens.length && tokens[position].type == :end
          position += 1
        end

        node = IR::Conditional.new(
          kind: :if,
          condition: cond_result.value,
          then_branch: then_result.value,
          else_branch: else_branch
        )
        TokenParseResult.success(node, tokens, position)
      end

      def parse_unless(tokens, position)
        position += 1 # consume 'unless'

        # Parse condition
        cond_result = @expression_parser.parse_expression(tokens, position)
        return cond_result if cond_result.failure?
        position = cond_result.position

        # Skip newline
        position = skip_newlines(tokens, position)

        # Parse then branch
        then_result = parse_block(tokens, position)
        position = then_result.position
        position = skip_newlines(tokens, position)

        # Check for else
        else_branch = nil
        if position < tokens.length && tokens[position].type == :else
          position += 1
          position = skip_newlines(tokens, position)
          else_result = parse_block(tokens, position)
          else_branch = else_result.value
          position = else_result.position
          position = skip_newlines(tokens, position)
        end

        # Expect 'end'
        if position < tokens.length && tokens[position].type == :end
          position += 1
        end

        node = IR::Conditional.new(
          kind: :unless,
          condition: cond_result.value,
          then_branch: then_result.value,
          else_branch: else_branch
        )
        TokenParseResult.success(node, tokens, position)
      end

      def parse_while(tokens, position)
        position += 1 # consume 'while'

        # Parse condition
        cond_result = @expression_parser.parse_expression(tokens, position)
        return cond_result if cond_result.failure?
        position = cond_result.position

        # Skip newline
        position = skip_newlines(tokens, position)

        # Parse body
        body_result = parse_block(tokens, position)
        position = body_result.position
        position = skip_newlines(tokens, position)

        # Expect 'end'
        if position < tokens.length && tokens[position].type == :end
          position += 1
        end

        node = IR::Loop.new(
          kind: :while,
          condition: cond_result.value,
          body: body_result.value
        )
        TokenParseResult.success(node, tokens, position)
      end

      def parse_until(tokens, position)
        position += 1 # consume 'until'

        # Parse condition
        cond_result = @expression_parser.parse_expression(tokens, position)
        return cond_result if cond_result.failure?
        position = cond_result.position

        # Skip newline
        position = skip_newlines(tokens, position)

        # Parse body
        body_result = parse_block(tokens, position)
        position = body_result.position
        position = skip_newlines(tokens, position)

        # Expect 'end'
        if position < tokens.length && tokens[position].type == :end
          position += 1
        end

        node = IR::Loop.new(
          kind: :until,
          condition: cond_result.value,
          body: body_result.value
        )
        TokenParseResult.success(node, tokens, position)
      end

      def parse_case(tokens, position)
        position += 1 # consume 'case'

        # Parse subject (optional)
        subject = nil
        position = skip_newlines(tokens, position)

        if position < tokens.length && tokens[position].type != :when
          subj_result = @expression_parser.parse_expression(tokens, position)
          if subj_result.success?
            subject = subj_result.value
            position = subj_result.position
          end
        end

        position = skip_newlines(tokens, position)

        # Parse when clauses
        when_clauses = []
        while position < tokens.length && tokens[position].type == :when
          when_result = parse_when_clause(tokens, position)
          return when_result if when_result.failure?
          when_clauses << when_result.value
          position = when_result.position
          position = skip_newlines(tokens, position)
        end

        # Parse else clause
        else_clause = nil
        if position < tokens.length && tokens[position].type == :else
          position += 1
          position = skip_newlines(tokens, position)
          else_result = parse_block(tokens, position)
          else_clause = else_result.value
          position = else_result.position
          position = skip_newlines(tokens, position)
        end

        # Expect 'end'
        if position < tokens.length && tokens[position].type == :end
          position += 1
        end

        node = IR::CaseExpr.new(
          subject: subject,
          when_clauses: when_clauses,
          else_clause: else_clause
        )
        TokenParseResult.success(node, tokens, position)
      end

      def parse_when_clause(tokens, position)
        position += 1 # consume 'when'

        # Parse patterns (comma-separated)
        patterns = []
        loop do
          pattern_result = @expression_parser.parse_expression(tokens, position)
          return pattern_result if pattern_result.failure?
          patterns << pattern_result.value
          position = pattern_result.position

          break unless tokens[position]&.type == :comma
          position += 1
        end

        position = skip_newlines(tokens, position)

        # Parse body
        body_result = parse_block(tokens, position)
        position = body_result.position

        node = IR::WhenClause.new(patterns: patterns, body: body_result.value)
        TokenParseResult.success(node, tokens, position)
      end

      def parse_begin(tokens, position)
        position += 1 # consume 'begin'
        position = skip_newlines(tokens, position)

        # Parse body
        body_result = parse_block(tokens, position)
        position = body_result.position
        position = skip_newlines(tokens, position)

        # Parse rescue clauses
        rescue_clauses = []
        while position < tokens.length && tokens[position].type == :rescue
          rescue_result = parse_rescue_clause(tokens, position)
          return rescue_result if rescue_result.failure?
          rescue_clauses << rescue_result.value
          position = rescue_result.position
          position = skip_newlines(tokens, position)
        end

        # Parse else clause (runs if no exception)
        else_clause = nil
        if position < tokens.length && tokens[position].type == :else
          position += 1
          position = skip_newlines(tokens, position)
          else_result = parse_block(tokens, position)
          else_clause = else_result.value
          position = else_result.position
          position = skip_newlines(tokens, position)
        end

        # Parse ensure clause
        ensure_clause = nil
        if position < tokens.length && tokens[position].type == :ensure
          position += 1
          position = skip_newlines(tokens, position)
          ensure_result = parse_block(tokens, position)
          ensure_clause = ensure_result.value
          position = ensure_result.position
          position = skip_newlines(tokens, position)
        end

        # Expect 'end'
        if position < tokens.length && tokens[position].type == :end
          position += 1
        end

        node = IR::BeginBlock.new(
          body: body_result.value,
          rescue_clauses: rescue_clauses,
          else_clause: else_clause,
          ensure_clause: ensure_clause
        )
        TokenParseResult.success(node, tokens, position)
      end

      def parse_rescue_clause(tokens, position)
        position += 1 # consume 'rescue'

        exception_types = []
        variable = nil

        # Check for exception types and variable binding
        # Format: rescue ExType, ExType2 => var or rescue => var
        if position < tokens.length && ![:newline, :hash_rocket].include?(tokens[position].type)
          # Parse exception types
          if tokens[position].type == :constant
            loop do
              if tokens[position].type == :constant
                exception_types << tokens[position].value
                position += 1
              end
              break unless tokens[position]&.type == :comma
              position += 1
            end
          end
        end

        # Check for => var binding
        if position < tokens.length && tokens[position].type == :hash_rocket
          position += 1
          if tokens[position]&.type == :identifier
            variable = tokens[position].value
            position += 1
          end
        end

        position = skip_newlines(tokens, position)

        # Parse body
        body_result = parse_block(tokens, position)
        position = body_result.position

        node = IR::RescueClause.new(
          exception_types: exception_types,
          variable: variable,
          body: body_result.value
        )
        TokenParseResult.success(node, tokens, position)
      end

      def parse_assignment_or_expression(tokens, position)
        # Check for typed assignment: name: Type = value
        if tokens[position].type == :identifier &&
           tokens[position + 1]&.type == :colon &&
           tokens[position + 2]&.type == :constant
          return parse_typed_assignment(tokens, position)
        end

        # Check for simple assignment patterns
        if assignable_token?(tokens[position])
          next_pos = position + 1

          # Simple assignment: x = value
          if tokens[next_pos]&.type == :eq
            return parse_simple_assignment(tokens, position)
          end

          # Compound assignment: x += value, x -= value, etc.
          if compound_assignment_token?(tokens[next_pos])
            return parse_compound_assignment(tokens, position)
          end
        end

        # Parse as expression
        expr_result = @expression_parser.parse_expression(tokens, position)
        return expr_result if expr_result.failure?

        # Check for statement modifiers
        parse_modifier(tokens, expr_result.position, expr_result.value)
      end

      def parse_typed_assignment(tokens, position)
        target = tokens[position].value
        position += 2 # skip identifier and colon

        # Parse type annotation (simple constant for now)
        type_annotation = IR::SimpleType.new(name: tokens[position].value)
        position += 1

        # Expect '='
        return TokenParseResult.failure("Expected '='", tokens, position) unless tokens[position]&.type == :eq
        position += 1

        # Parse value
        value_result = @expression_parser.parse_expression(tokens, position)
        return value_result if value_result.failure?

        node = IR::Assignment.new(
          target: target,
          value: value_result.value,
          type_annotation: type_annotation
        )
        TokenParseResult.success(node, tokens, value_result.position)
      end

      def parse_simple_assignment(tokens, position)
        target = tokens[position].value
        position += 2 # skip variable and '='

        # Parse value
        value_result = @expression_parser.parse_expression(tokens, position)
        return value_result if value_result.failure?

        node = IR::Assignment.new(target: target, value: value_result.value)
        TokenParseResult.success(node, tokens, value_result.position)
      end

      def parse_compound_assignment(tokens, position)
        target = tokens[position].value
        op_token = tokens[position + 1]
        position += 2 # skip variable and operator

        # Map compound operator to binary operator
        op_map = {
          plus_eq: :+,
          minus_eq: :-,
          star_eq: :*,
          slash_eq: :/,
          percent_eq: :%,
        }
        binary_op = op_map[op_token.type]

        # Parse right-hand side
        rhs_result = @expression_parser.parse_expression(tokens, position)
        return rhs_result if rhs_result.failure?

        # Create expanded form: x = x + value
        target_ref = IR::VariableRef.new(name: target, scope: infer_scope(target))
        binary_expr = IR::BinaryOp.new(
          operator: binary_op,
          left: target_ref,
          right: rhs_result.value
        )

        node = IR::Assignment.new(target: target, value: binary_expr)

        # Check for statement modifiers
        parse_modifier(tokens, rhs_result.position, node)
      end

      def parse_modifier(tokens, position, statement)
        return TokenParseResult.success(statement, tokens, position) if position >= tokens.length

        token = tokens[position]
        case token.type
        when :if
          position += 1
          cond_result = @expression_parser.parse_expression(tokens, position)
          return cond_result if cond_result.failure?

          then_branch = statement.is_a?(IR::Block) ? statement : IR::Block.new(statements: [statement])
          node = IR::Conditional.new(
            kind: :if,
            condition: cond_result.value,
            then_branch: then_branch
          )
          TokenParseResult.success(node, tokens, cond_result.position)

        when :unless
          position += 1
          cond_result = @expression_parser.parse_expression(tokens, position)
          return cond_result if cond_result.failure?

          then_branch = statement.is_a?(IR::Block) ? statement : IR::Block.new(statements: [statement])
          node = IR::Conditional.new(
            kind: :unless,
            condition: cond_result.value,
            then_branch: then_branch
          )
          TokenParseResult.success(node, tokens, cond_result.position)

        when :while
          position += 1
          cond_result = @expression_parser.parse_expression(tokens, position)
          return cond_result if cond_result.failure?

          body = statement.is_a?(IR::Block) ? statement : IR::Block.new(statements: [statement])
          node = IR::Loop.new(
            kind: :while,
            condition: cond_result.value,
            body: body
          )
          TokenParseResult.success(node, tokens, cond_result.position)

        when :until
          position += 1
          cond_result = @expression_parser.parse_expression(tokens, position)
          return cond_result if cond_result.failure?

          body = statement.is_a?(IR::Block) ? statement : IR::Block.new(statements: [statement])
          node = IR::Loop.new(
            kind: :until,
            condition: cond_result.value,
            body: body
          )
          TokenParseResult.success(node, tokens, cond_result.position)

        else
          TokenParseResult.success(statement, tokens, position)
        end
      end

      def assignable_token?(token)
        return false unless token
        [:identifier, :ivar, :cvar, :gvar].include?(token.type)
      end

      def compound_assignment_token?(token)
        return false unless token
        [:plus_eq, :minus_eq, :star_eq, :slash_eq, :percent_eq].include?(token.type)
      end

      def end_of_statement?(tokens, position)
        return true if position >= tokens.length
        [:newline, :eof, :end, :else, :elsif, :when, :rescue, :ensure].include?(tokens[position].type)
      end

      def skip_newlines_if_not_modifier(tokens, position)
        # Don't skip newlines if next token after newline is a modifier
        if tokens[position]&.type == :newline
          next_pos = position + 1
          while next_pos < tokens.length && tokens[next_pos].type == :newline
            next_pos += 1
          end
          # If next meaningful token is a modifier, return original position
          if next_pos < tokens.length && [:if, :unless, :while, :until].include?(tokens[next_pos].type)
            return position
          end
        end
        skip_newlines(tokens, position)
      end

      def infer_scope(name)
        case name[0]
        when "@"
          name[1] == "@" ? :class : :instance
        when "$"
          :global
        else
          :local
        end
      end
    end
  end
end
