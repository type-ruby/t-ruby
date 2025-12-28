# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Chainl: left-associative chain
    class ChainLeft < Parser
      def initialize(term, op)
        @term = term
        @op = op
      end

      def parse(input, position = 0)
        first = @term.parse(input, position)
        return first if first.failure?

        result = first.value
        current_pos = first.position

        loop do
          op_result = @op.parse(input, current_pos)
          break if op_result.failure?

          term_result = @term.parse(input, op_result.position)
          break if term_result.failure?

          result = op_result.value.call(result, term_result.value)
          current_pos = term_result.position
        end

        ParseResult.success(result, input, current_pos)
      end
    end
  end
end
