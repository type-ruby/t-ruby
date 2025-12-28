# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # FlatMap (bind)
    class FlatMap < Parser
      def initialize(parser, func)
        @parser = parser
        @func = func
      end

      def parse(input, position = 0)
        result = @parser.parse(input, position)
        return result if result.failure?

        next_parser = @func.call(result.value)
        next_parser.parse(input, result.position)
      end
    end
  end
end
