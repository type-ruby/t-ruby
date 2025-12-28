# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Lookahead: check without consuming
    class Lookahead < Parser
      def initialize(parser)
        @parser = parser
      end

      def parse(input, position = 0)
        result = @parser.parse(input, position)
        if result.success?
          ParseResult.success(result.value, input, position)
        else
          result
        end
      end
    end
  end
end
