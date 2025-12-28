# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Token-based parse result
    class TokenParseResult
      attr_reader :value, :tokens, :position, :error

      def initialize(success:, value: nil, tokens: [], position: 0, error: nil)
        @success = success
        @value = value
        @tokens = tokens
        @position = position
        @error = error
      end

      def success?
        @success
      end

      def failure?
        !@success
      end

      def self.success(value, tokens, position)
        new(success: true, value: value, tokens: tokens, position: position)
      end

      def self.failure(error, tokens, position)
        new(success: false, error: error, tokens: tokens, position: position)
      end

      def map
        return self if failure?

        TokenParseResult.success(yield(value), tokens, position)
      end
    end
  end
end
