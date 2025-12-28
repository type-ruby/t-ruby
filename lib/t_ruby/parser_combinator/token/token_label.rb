# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Label for error messages
    class TokenLabel < TokenParser
      def initialize(parser, name)
        @parser = parser
        @name = name
      end

      def parse(tokens, position = 0)
        result = @parser.parse(tokens, position)
        if result.failure?
          TokenParseResult.failure("Expected #{@name}", tokens, position)
        else
          result
        end
      end
    end
  end
end
