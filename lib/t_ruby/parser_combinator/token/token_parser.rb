# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Base class for token parsers
    class TokenParser
      def parse(tokens, position = 0)
        raise NotImplementedError
      end

      # Sequence: run this parser, then the other
      def >>(other)
        TokenSequence.new(self, other)
      end

      # Alternative: try this parser, if it fails try the other
      def |(other)
        TokenAlternative.new(self, other)
      end

      # Map: transform the result
      def map(&block)
        TokenMap.new(self, block)
      end

      # Many: zero or more repetitions
      def many
        TokenMany.new(self)
      end

      # Many1: one or more repetitions
      def many1
        TokenMany1.new(self)
      end

      # Optional: zero or one
      def optional
        TokenOptional.new(self)
      end

      # Separated by: parse items separated by delimiter
      def sep_by(delimiter)
        TokenSepBy.new(self, delimiter)
      end

      # Separated by 1: at least one item
      def sep_by1(delimiter)
        TokenSepBy1.new(self, delimiter)
      end

      # Skip right: parse both, keep left result
      def <<(other)
        TokenSkipRight.new(self, other)
      end

      # Label: add a descriptive label for error messages
      def label(name)
        TokenLabel.new(self, name)
      end
    end
  end
end
