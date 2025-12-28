# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Map result
    class Map < Parser
      def initialize(parser, func)
        @parser = parser
        @func = func
      end

      def parse(input, position = 0)
        @parser.parse(input, position).map(&@func)
      end
    end
  end
end
