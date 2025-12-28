# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Base parser class for string-based parsing
    class Parser
      def parse(input, position = 0)
        raise NotImplementedError
      end

      # Combinators as methods

      # Sequence: run this parser, then the other
      def >>(other)
        Sequence.new(self, other)
      end

      # Alternative: try this parser, if it fails try the other
      def |(other)
        Alternative.new(self, other)
      end

      # Map: transform the result
      def map(&block)
        Map.new(self, block)
      end

      # FlatMap: transform with another parser
      def flat_map(&block)
        FlatMap.new(self, block)
      end

      # Many: zero or more repetitions
      def many
        Many.new(self)
      end

      # Many1: one or more repetitions
      def many1
        Many1.new(self)
      end

      # Optional: zero or one
      def optional
        Optional.new(self)
      end

      # Separated by: parse items separated by delimiter
      def sep_by(delimiter)
        SepBy.new(self, delimiter)
      end

      # Separated by 1: at least one item
      def sep_by1(delimiter)
        SepBy1.new(self, delimiter)
      end

      # Between: parse between left and right delimiters
      def between(left, right)
        (left >> self << right).map { |(_, val)| val }
      end

      # Skip right: parse both, keep left result
      def <<(other)
        SkipRight.new(self, other)
      end

      # Label: add a descriptive label for error messages
      def label(name)
        Label.new(self, name)
      end

      # Lookahead: check without consuming
      def lookahead
        Lookahead.new(self)
      end

      # Not: succeed only if parser fails
      def not_followed_by
        NotFollowedBy.new(self)
      end
    end
  end
end
