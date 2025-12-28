# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Parse using regex
    class Regex < Parser
      def initialize(pattern, description = nil)
        @pattern = pattern.is_a?(Regexp) ? pattern : Regexp.new("^#{pattern}")
        @description = description || @pattern.inspect
      end

      def parse(input, position = 0)
        remaining = input[position..]
        match = @pattern.match(remaining)

        if match&.begin(0)&.zero?
          matched = match[0]
          ParseResult.success(matched, input, position + matched.length)
        else
          ParseResult.failure("Expected #{@description}", input, position)
        end
      end
    end
  end
end
