# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Separated by delimiter
    class SepBy < Parser
      def initialize(parser, delimiter)
        @parser = parser
        @delimiter = delimiter
      end

      def parse(input, position = 0)
        first = @parser.parse(input, position)
        return ParseResult.success([], input, position) if first.failure?

        results = [first.value]
        current_pos = first.position

        loop do
          delim_result = @delimiter.parse(input, current_pos)
          break if delim_result.failure?

          item_result = @parser.parse(input, delim_result.position)
          break if item_result.failure?

          results << item_result.value
          current_pos = item_result.position
        end

        ParseResult.success(results, input, current_pos)
      end
    end
  end
end
