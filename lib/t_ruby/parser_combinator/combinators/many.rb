# frozen_string_literal: true

module TRuby
  module ParserCombinator
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
  end
end
