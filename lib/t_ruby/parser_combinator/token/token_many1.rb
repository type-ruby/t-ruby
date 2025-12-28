# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Many1: one or more
    class TokenMany1 < TokenParser
      def initialize(parser)
        @parser = parser
      end

      def parse(tokens, position = 0)
        first = @parser.parse(tokens, position)
        return first if first.failure?

        results = [first.value]
        current_pos = first.position

        loop do
          result = @parser.parse(tokens, current_pos)
          break if result.failure?

          results << result.value
          break if result.position == current_pos

          current_pos = result.position
        end

        TokenParseResult.success(results, tokens, current_pos)
      end
    end
  end
end
