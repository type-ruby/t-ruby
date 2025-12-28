# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Token DSL Module - Convenience methods for token parsing
    module TokenDSL
      def token(type)
        TokenMatcher.new(type)
      end

      def keyword(kw)
        TokenMatcher.new(kw)
      end
    end
  end
end
