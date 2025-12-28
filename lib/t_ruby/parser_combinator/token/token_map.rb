# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Map result
    class TokenMap < TokenParser
      def initialize(parser, func)
        @parser = parser
        @func = func
      end

      def parse(tokens, position = 0)
        @parser.parse(tokens, position).map(&@func)
      end
    end
  end
end
