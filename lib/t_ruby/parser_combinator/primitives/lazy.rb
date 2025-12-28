# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Lazy parser (for recursive grammars)
    class Lazy < Parser
      def initialize(&block)
        @block = block
        @parser = nil
      end

      def parse(input, position = 0)
        @parser ||= @block.call
        @parser.parse(input, position)
      end
    end
  end
end
