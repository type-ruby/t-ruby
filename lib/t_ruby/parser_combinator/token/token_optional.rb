# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Optional: zero or one
    class TokenOptional < TokenParser
      def initialize(parser)
        @parser = parser
      end

      def parse(tokens, position = 0)
        result = @parser.parse(tokens, position)
        if result.success?
          result
        else
          TokenParseResult.success(nil, tokens, position)
        end
      end
    end
  end
end
