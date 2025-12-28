# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Many: zero or more
    class TokenMany < TokenParser
      def initialize(parser)
        @parser = parser
      end

      def parse(tokens, position = 0)
        results = []
        current_pos = position

        loop do
          result = @parser.parse(tokens, current_pos)
          break if result.failure?

          results << result.value
          break if result.position == current_pos # Prevent infinite loop

          current_pos = result.position
        end

        TokenParseResult.success(results, tokens, current_pos)
      end
    end
  end
end
