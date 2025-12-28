# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Always fail
    class Fail < Parser
      def initialize(message)
        @message = message
      end

      def parse(input, position = 0)
        ParseResult.failure(@message, input, position)
      end
    end
  end
end
