# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Many1: one or more
    class Many1 < Parser
      def initialize(parser)
        @parser = parser
      end

      def parse(input, position = 0)
        first = @parser.parse(input, position)
        return first if first.failure?

        results = [first.value]
        current_pos = first.position

        loop do
          result = @parser.parse(input, current_pos)
          break if result.failure?

          results << result.value
          break if result.position == current_pos

          current_pos = result.position
        end

        ParseResult.success(results, input, current_pos)
      end
    end
  end
end
