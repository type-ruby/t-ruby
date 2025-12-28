# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Error Reporting
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
