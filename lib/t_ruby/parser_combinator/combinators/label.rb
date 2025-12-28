# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Label for error messages
    class Label < Parser
      def initialize(parser, name)
        @parser = parser
        @name = name
      end

      def parse(input, position = 0)
        result = @parser.parse(input, position)
        if result.failure?
          ParseResult.failure("Expected #{@name}", input, position)
        else
          result
        end
      end
    end
  end
end
