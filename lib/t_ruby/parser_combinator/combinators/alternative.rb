# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Alternative: try first, if fails try second
    class Alternative < Parser
      def initialize(left, right)
        @left = left
        @right = right
      end

      def parse(input, position = 0)
        result = @left.parse(input, position)
        return result if result.success?

        @right.parse(input, position)
      end
    end
  end
end
