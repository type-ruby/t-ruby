# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Match a specific token type
    class TokenMatcher < TokenParser
      def initialize(token_type)
        @token_type = token_type
      end

      def parse(tokens, position = 0)
        return TokenParseResult.failure("End of input", tokens, position) if position >= tokens.length

        token = tokens[position]
        return TokenParseResult.failure("End of input", tokens, position) if token.type == :eof

        if token.type == @token_type
          TokenParseResult.success(token, tokens, position + 1)
        else
          TokenParseResult.failure(
            "Expected :#{@token_type}, got :#{token.type} (#{token.value.inspect})",
            tokens,
            position
          )
        end
      end
    end
  end
end
