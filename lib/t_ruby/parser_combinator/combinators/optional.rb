# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Optional: zero or one
    class Optional < Parser
      def initialize(parser)
        @parser = parser
      end

      def parse(input, position = 0)
        result = @parser.parse(input, position)
        if result.success?
          result
        else
          ParseResult.success(nil, input, position)
        end
      end
    end
  end
end
