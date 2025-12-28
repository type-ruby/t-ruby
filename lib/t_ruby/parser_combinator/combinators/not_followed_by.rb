# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Not followed by
    class NotFollowedBy < Parser
      def initialize(parser)
        @parser = parser
      end

      def parse(input, position = 0)
        result = @parser.parse(input, position)
        if result.failure?
          ParseResult.success(nil, input, position)
        else
          ParseResult.failure("Unexpected match", input, position)
        end
      end
    end
  end
end
