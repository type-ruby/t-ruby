# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Choice: try multiple parsers in order
    class Choice < Parser
      def initialize(*parsers)
        @parsers = parsers
      end

      def parse(input, position = 0)
        best_error = nil
        best_position = position

        @parsers.each do |parser|
          result = parser.parse(input, position)
          return result if result.success?

          if result.position >= best_position
            best_error = result.error
            best_position = result.position
          end
        end

        ParseResult.failure(best_error || "No alternative matched", input, best_position)
      end
    end
  end
end
