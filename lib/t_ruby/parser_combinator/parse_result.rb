# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Parse result - either success or failure
    class ParseResult
      attr_reader :value, :remaining, :position, :error

      def initialize(success:, value: nil, remaining: "", position: 0, error: nil)
        @success = success
        @value = value
        @remaining = remaining
        @position = position
        @error = error
      end

      def success?
        @success
      end

      def failure?
        !@success
      end

      def self.success(value, remaining, position)
        new(success: true, value: value, remaining: remaining, position: position)
      end

      def self.failure(error, remaining, position)
        new(success: false, error: error, remaining: remaining, position: position)
      end

      def map
        return self if failure?

        ParseResult.success(yield(value), remaining, position)
      end

      def flat_map
        return self if failure?

        yield(value, remaining, position)
      end
    end
  end
end
