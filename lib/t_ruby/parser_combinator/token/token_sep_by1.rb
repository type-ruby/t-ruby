# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Separated by 1 (at least one)
    class TokenSepBy1 < TokenParser
      def initialize(parser, delimiter)
        @parser = parser
        @delimiter = delimiter
      end

      def parse(tokens, position = 0)
        first = @parser.parse(tokens, position)
        return first if first.failure?

        results = [first.value]
        current_pos = first.position

        loop do
          delim_result = @delimiter.parse(tokens, current_pos)
          break if delim_result.failure?

          item_result = @parser.parse(tokens, delim_result.position)
          break if item_result.failure?

          results << item_result.value
          current_pos = item_result.position
        end

        TokenParseResult.success(results, tokens, current_pos)
      end
    end
  end
end
