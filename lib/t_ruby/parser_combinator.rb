# frozen_string_literal: true

# Parser Combinator module for T-Ruby
# Provides both string-based and token-based parsing capabilities

module TRuby
  module ParserCombinator
    # Base classes
    require_relative "parser_combinator/parse_result"
    require_relative "parser_combinator/parser"

    # Primitive parsers
    require_relative "parser_combinator/primitives/literal"
    require_relative "parser_combinator/primitives/satisfy"
    require_relative "parser_combinator/primitives/regex"
    require_relative "parser_combinator/primitives/end_of_input"
    require_relative "parser_combinator/primitives/pure"
    require_relative "parser_combinator/primitives/fail"
    require_relative "parser_combinator/primitives/lazy"

    # Combinator parsers
    require_relative "parser_combinator/combinators/sequence"
    require_relative "parser_combinator/combinators/alternative"
    require_relative "parser_combinator/combinators/map"
    require_relative "parser_combinator/combinators/flat_map"
    require_relative "parser_combinator/combinators/many"
    require_relative "parser_combinator/combinators/many1"
    require_relative "parser_combinator/combinators/optional"
    require_relative "parser_combinator/combinators/sep_by"
    require_relative "parser_combinator/combinators/sep_by1"
    require_relative "parser_combinator/combinators/skip_right"
    require_relative "parser_combinator/combinators/label"
    require_relative "parser_combinator/combinators/lookahead"
    require_relative "parser_combinator/combinators/not_followed_by"
    require_relative "parser_combinator/combinators/choice"
    require_relative "parser_combinator/combinators/chain_left"

    # DSL module
    require_relative "parser_combinator/dsl"

    # Token-based parsers
    require_relative "parser_combinator/token/token_parse_result"
    require_relative "parser_combinator/token/token_parser"
    require_relative "parser_combinator/token/token_matcher"
    require_relative "parser_combinator/token/token_sequence"
    require_relative "parser_combinator/token/token_alternative"
    require_relative "parser_combinator/token/token_map"
    require_relative "parser_combinator/token/token_many"
    require_relative "parser_combinator/token/token_many1"
    require_relative "parser_combinator/token/token_optional"
    require_relative "parser_combinator/token/token_sep_by"
    require_relative "parser_combinator/token/token_sep_by1"
    require_relative "parser_combinator/token/token_skip_right"
    require_relative "parser_combinator/token/token_label"
    require_relative "parser_combinator/token/token_dsl"

    # High-level parsers
    require_relative "parser_combinator/token/expression_parser"
    require_relative "parser_combinator/token/statement_parser"
    require_relative "parser_combinator/token/token_declaration_parser"
    require_relative "parser_combinator/token/token_body_parser"

    # Type and declaration parsers (string-based)
    require_relative "parser_combinator/type_parser"
    require_relative "parser_combinator/declaration_parser"

    # Error reporting
    require_relative "parser_combinator/parse_error"
  end
end
