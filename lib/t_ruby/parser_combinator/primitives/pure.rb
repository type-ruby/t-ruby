# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Always succeed with a value
    class Pure < Parser
      def initialize(value)
        @value = value
      end

      def parse(input, position = 0)
        ParseResult.success(@value, input, position)
      end
    end
  end
end
