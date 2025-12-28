# frozen_string_literal: true

module TRuby
  module ParserCombinator
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
  end
end
