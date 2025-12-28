# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # DSL Module - Convenience methods
    module DSL
      def literal(str)
        Literal.new(str)
      end

      def regex(pattern, description = nil)
        Regex.new(pattern, description)
      end

      def satisfy(description = "character", &predicate)
        Satisfy.new(predicate, description)
      end

      def char(c)
        Literal.new(c)
      end

      def string(str)
        Literal.new(str)
      end

      def eof
        EndOfInput.new
      end

      def pure(value)
        Pure.new(value)
      end

      def fail(message)
        Fail.new(message)
      end

      def lazy(&)
        Lazy.new(&)
      end

      def choice(*parsers)
        Choice.new(*parsers)
      end

      def sequence(*parsers)
        parsers.reduce { |acc, p| acc >> p }
      end

      # Common character parsers
      def digit
        satisfy("digit") { |c| c =~ /[0-9]/ }
      end

      def letter
        satisfy("letter") { |c| c =~ /[a-zA-Z]/ }
      end

      def alphanumeric
        satisfy("alphanumeric") { |c| c =~ /[a-zA-Z0-9]/ }
      end

      def whitespace
        satisfy("whitespace") { |c| c =~ /\s/ }
      end

      def spaces
        whitespace.many.map(&:join)
      end

      def spaces1
        whitespace.many1.map(&:join)
      end

      def newline
        char("\n") | string("\r\n")
      end

      def identifier
        (letter >> (alphanumeric | char("_")).many).map do |(first, rest)|
          first + rest.join
        end
      end

      def integer
        (char("-").optional >> digit.many1).map do |(sign, digits)|
          num = digits.join.to_i
          sign ? -num : num
        end
      end

      def float
        regex(/-?\d+\.\d+/, "float").map(&:to_f)
      end

      def quoted_string(quote = '"')
        content = satisfy("string character") { |c| c != quote && c != "\\" }
        escape = (char("\\") >> satisfy("escape char")).map { |(_bs, c)| c }

        (char(quote) >> (content | escape).many.map(&:join) << char(quote)).map { |(_, str)| str }
      end

      # Skip whitespace around parser
      def lexeme(parser)
        (spaces >> parser << spaces).map { |(_, val)| val }
      end

      # Chain for left-associative operators
      def chainl(term, op)
        ChainLeft.new(term, op)
      end
    end
  end
end
