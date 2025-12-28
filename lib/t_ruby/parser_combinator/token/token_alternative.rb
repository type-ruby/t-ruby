# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Alternative: try first, if fails try second
    class TokenAlternative < TokenParser
      def initialize(left, right)
        @left = left
        @right = right
      end

      def parse(tokens, position = 0)
        result = @left.parse(tokens, position)
        return result if result.success?

        @right.parse(tokens, position)
      end
    end
  end
end
