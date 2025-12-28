# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Sequence two token parsers
    class TokenSequence < TokenParser
      def initialize(left, right)
        @left = left
        @right = right
      end

      def parse(tokens, position = 0)
        result1 = @left.parse(tokens, position)
        return result1 if result1.failure?

        result2 = @right.parse(tokens, result1.position)
        return result2 if result2.failure?

        TokenParseResult.success([result1.value, result2.value], tokens, result2.position)
      end
    end
  end
end
