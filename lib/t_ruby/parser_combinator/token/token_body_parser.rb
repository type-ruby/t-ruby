# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Token-based body parser - replaces regex-based BodyParser
    # Provides the same interface as BodyParser.parse(lines, start_line, end_line)
    class TokenBodyParser
      def initialize
        @statement_parser = StatementParser.new
      end

      # Parse method body from lines array
      # @param lines [Array<String>] source code lines
      # @param start_line [Integer] starting line index (0-based)
      # @param end_line [Integer] ending line index (exclusive)
      # @return [IR::Block] parsed block of statements
      def parse(lines, start_line, end_line)
        # Extract the body source
        body_lines = lines[start_line...end_line]
        source = body_lines.join("\n")

        return IR::Block.new(statements: []) if source.strip.empty?

        # Scan and parse
        scanner = TRuby::Scanner.new(source)
        tokens = scanner.scan_all

        result = @statement_parser.parse_block(tokens, 0)

        if result.success?
          result.value
        else
          # Fallback to empty block on parse failure
          IR::Block.new(statements: [])
        end
      end

      # Parse a single expression string
      # @param expr [String] expression to parse
      # @return [IR::Node] parsed expression node
      def parse_expression(expr)
        return nil if expr.nil? || expr.strip.empty?

        scanner = TRuby::Scanner.new(expr)
        tokens = scanner.scan_all

        expression_parser = ExpressionParser.new
        result = expression_parser.parse_expression(tokens, 0)

        result.success? ? result.value : IR::RawCode.new(code: expr)
      end
    end
  end
end
