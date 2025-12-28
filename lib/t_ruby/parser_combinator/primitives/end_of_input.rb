# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Parse end of input
    class EndOfInput < Parser
      def parse(input, position = 0)
        if position >= input.length
          ParseResult.success(nil, input, position)
        else
          ParseResult.failure("Expected end of input", input, position)
        end
      end
    end
  end
end
