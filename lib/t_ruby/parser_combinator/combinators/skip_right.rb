# frozen_string_literal: true

module TRuby
  module ParserCombinator
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
  end
end
