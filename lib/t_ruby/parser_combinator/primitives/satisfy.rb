# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Parse a single character matching predicate
    class Satisfy < Parser
      def initialize(predicate, description = "character")
        @predicate = predicate
        @description = description
      end

      def parse(input, position = 0)
        if position < input.length && @predicate.call(input[position])
          ParseResult.success(input[position], input, position + 1)
        else
          ParseResult.failure("Expected #{@description}", input, position)
        end
      end
    end
  end
end
