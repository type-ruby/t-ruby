# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::Scanner do
  describe TRuby::Scanner::Token do
    it "holds token information" do
      token = described_class.new(:identifier, "foo", 0, 3, 1, 1)
      expect(token.type).to eq(:identifier)
      expect(token.value).to eq("foo")
      expect(token.start_pos).to eq(0)
      expect(token.end_pos).to eq(3)
      expect(token.line).to eq(1)
      expect(token.column).to eq(1)
    end
  end

  describe "#scan_all" do
    subject(:scanner) { described_class.new(source) }

    context "with keywords" do
      let(:source) { "def end class module if unless else elsif return type interface" }

      it "tokenizes all Ruby and T-Ruby keywords" do
        tokens = scanner.scan_all
        types = tokens.map(&:type)

        expect(types).to eq(%i[
                              def end class module if unless else elsif
                              return type interface eof
                            ])
      end
    end

    context "with visibility modifiers" do
      let(:source) { "public private protected" }

      it "tokenizes visibility modifiers" do
        tokens = scanner.scan_all
        types = tokens.map(&:type)

        expect(types).to eq(%i[public private protected eof])
      end
    end

    context "with identifiers" do
      let(:source) { "foo bar_baz camelCase method? dangerous!" }

      it "tokenizes identifiers including ? and ! suffixes" do
        tokens = scanner.scan_all
        values = tokens.reject { |t| t.type == :eof }.map(&:value)

        expect(values).to eq(%w[foo bar_baz camelCase method? dangerous!])
      end
    end

    context "with constants" do
      let(:source) { "String Integer MyClass CONSTANT" }

      it "tokenizes constants (uppercase start)" do
        tokens = scanner.scan_all
        types = tokens.reject { |t| t.type == :eof }.map(&:type)

        expect(types).to all(eq(:constant))
      end
    end

    context "with instance variables" do
      let(:source) { "@name @age @_private" }

      it "tokenizes instance variables" do
        tokens = scanner.scan_all
        tokens = tokens.reject { |t| t.type == :eof }

        expect(tokens.map(&:type)).to all(eq(:ivar))
        expect(tokens.map(&:value)).to eq(%w[@name @age @_private])
      end
    end

    context "with class variables" do
      let(:source) { "@@count @@instance" }

      it "tokenizes class variables" do
        tokens = scanner.scan_all
        tokens = tokens.reject { |t| t.type == :eof }

        expect(tokens.map(&:type)).to all(eq(:cvar))
        expect(tokens.map(&:value)).to eq(%w[@@count @@instance])
      end
    end

    context "with global variables" do
      let(:source) { "$stdout $stderr $0" }

      it "tokenizes global variables" do
        tokens = scanner.scan_all
        tokens = tokens.reject { |t| t.type == :eof }

        expect(tokens.map(&:type)).to all(eq(:gvar))
      end
    end

    context "with integer literals" do
      let(:source) { "0 42 -123 1_000_000" }

      it "tokenizes integer literals" do
        tokens = scanner.scan_all
        tokens = tokens.reject { |t| t.type == :eof }

        expect(tokens.map(&:type)).to eq(%i[integer integer minus integer integer])
        expect(tokens.map(&:value)).to eq(["0", "42", "-", "123", "1_000_000"])
      end
    end

    context "with float literals" do
      let(:source) { "3.14 0.5 -2.718" }

      it "tokenizes float literals" do
        tokens = scanner.scan_all
        tokens = tokens.reject { |t| t.type == :eof }

        expect(tokens.map(&:type)).to eq(%i[float float minus float])
      end
    end

    context "with string literals" do
      let(:source) { '"hello" \'world\'' }

      it "tokenizes simple string literals" do
        tokens = scanner.scan_all
        tokens = tokens.reject { |t| t.type == :eof }

        expect(tokens.map(&:type)).to eq(%i[string string])
        expect(tokens.map(&:value)).to eq(['"hello"', "'world'"])
      end
    end

    context "with string interpolation" do
      let(:source) { '"Hello #{name}!"' }

      it "tokenizes string with interpolation markers" do
        tokens = scanner.scan_all
        types = tokens.reject { |t| t.type == :eof }.map(&:type)

        expect(types).to eq(%i[
                              string_start string_content interpolation_start
                              identifier interpolation_end string_content string_end
                            ])
      end
    end

    context "with symbols" do
      let(:source) { ":foo :bar_baz :CamelCase" }

      it "tokenizes symbol literals" do
        tokens = scanner.scan_all
        tokens = tokens.reject { |t| t.type == :eof }

        expect(tokens.map(&:type)).to all(eq(:symbol))
        expect(tokens.map(&:value)).to eq([":foo", ":bar_baz", ":CamelCase"])
      end
    end

    context "with boolean and nil literals" do
      let(:source) { "true false nil" }

      it "tokenizes boolean and nil literals" do
        tokens = scanner.scan_all
        types = tokens.reject { |t| t.type == :eof }.map(&:type)

        expect(types).to eq([true, false, :nil])
      end
    end

    context "with operators" do
      let(:source) { "+ - * / % ** = == != < > <= >= <=> && || !" }

      it "tokenizes all operators" do
        tokens = scanner.scan_all
        types = tokens.reject { |t| t.type == :eof }.map(&:type)

        expect(types).to eq(%i[
                              plus minus star slash percent star_star
                              eq eq_eq bang_eq lt gt lt_eq gt_eq spaceship
                              and_and or_or bang
                            ])
      end
    end

    context "with type annotation operators" do
      let(:source) { ": -> | & ?" }

      it "tokenizes type annotation operators" do
        tokens = scanner.scan_all
        types = tokens.reject { |t| t.type == :eof }.map(&:type)

        expect(types).to eq(%i[colon arrow pipe amp question])
      end
    end

    context "with delimiters" do
      let(:source) { "( ) [ ] { } , ." }

      it "tokenizes all delimiters" do
        tokens = scanner.scan_all
        types = tokens.reject { |t| t.type == :eof }.map(&:type)

        expect(types).to eq(%i[
                              lparen rparen lbracket rbracket lbrace rbrace
                              comma dot
                            ])
      end
    end

    context "with double splat" do
      let(:source) { "**opts" }

      it "tokenizes double splat operator" do
        tokens = scanner.scan_all
        types = tokens.reject { |t| t.type == :eof }.map(&:type)

        expect(types).to eq(%i[star_star identifier])
      end
    end

    context "with newlines" do
      let(:source) { "foo\nbar\nbaz" }

      it "tokenizes newlines" do
        tokens = scanner.scan_all
        types = tokens.map(&:type)

        expect(types).to eq(%i[identifier newline identifier newline identifier eof])
      end
    end

    context "with comments" do
      let(:source) { "foo # this is a comment\nbar" }

      it "tokenizes comments" do
        tokens = scanner.scan_all
        comment_token = tokens.find { |t| t.type == :comment }

        expect(comment_token).not_to be_nil
        expect(comment_token.value).to eq("# this is a comment")
      end
    end

    context "with a complete function definition" do
      let(:source) { "def greet(n: String): String" + "\n" + '  "Hello #{n}"' + "\n" + "end" }

      it "tokenizes a complete function" do
        tokens = scanner.scan_all
        types = tokens.reject { |t| t.type == :eof }.map(&:type)

        # T-Ruby uses : for return type annotation, not ->
        expect(types).to include(:def, :identifier, :lparen, :colon, :constant, :rparen, :colon, :end)
      end
    end

    context "with type alias" do
      let(:source) { "type UserId = Integer" }

      it "tokenizes type alias" do
        tokens = scanner.scan_all
        types = tokens.reject { |t| t.type == :eof }.map(&:type)

        expect(types).to eq(%i[type constant eq constant])
      end
    end

    context "with interface" do
      let(:source) { "interface Printable\n  print: -> void\nend" }

      it "tokenizes interface definition" do
        tokens = scanner.scan_all
        types = tokens.map(&:type)

        expect(types).to include(:interface, :constant, :newline, :identifier, :colon, :arrow, :identifier, :newline, :end)
      end
    end

    context "with generic types" do
      let(:source) { "Array<String>" }

      it "tokenizes generic type syntax" do
        tokens = scanner.scan_all
        types = tokens.reject { |t| t.type == :eof }.map(&:type)

        expect(types).to eq(%i[constant lt constant gt])
      end
    end

    context "with union types" do
      let(:source) { "String | Integer | nil" }

      it "tokenizes union type syntax" do
        tokens = scanner.scan_all
        types = tokens.reject { |t| t.type == :eof }.map(&:type)

        expect(types).to eq(%i[constant pipe constant pipe nil])
      end
    end

    context "with keyword arguments" do
      let(:source) { "{ name: String, age: Integer }" }

      it "tokenizes keyword argument group" do
        tokens = scanner.scan_all
        types = tokens.reject { |t| t.type == :eof }.map(&:type)

        expect(types).to eq(%i[
                              lbrace identifier colon constant comma
                              identifier colon constant rbrace
                            ])
      end
    end
  end

  describe "#next_token" do
    it "returns tokens one at a time" do
      scanner = described_class.new("foo bar")

      token1 = scanner.next_token
      expect(token1.type).to eq(:identifier)
      expect(token1.value).to eq("foo")

      token2 = scanner.next_token
      expect(token2.type).to eq(:identifier)
      expect(token2.value).to eq("bar")

      token3 = scanner.next_token
      expect(token3.type).to eq(:eof)
    end
  end

  describe "#peek" do
    it "looks ahead without consuming" do
      scanner = described_class.new("foo bar baz")

      peeked = scanner.peek
      expect(peeked.value).to eq("foo")

      # Should still return foo since peek doesn't consume
      token = scanner.next_token
      expect(token.value).to eq("foo")
    end

    it "can look ahead multiple tokens" do
      scanner = described_class.new("foo bar baz")

      tokens = scanner.peek(3)
      expect(tokens.map(&:value)).to eq(%w[foo bar baz])
    end
  end

  describe "position tracking" do
    it "tracks line and column correctly" do
      source = "foo\nbar\n  baz"
      scanner = described_class.new(source)
      tokens = scanner.scan_all

      foo = tokens[0]
      expect(foo.line).to eq(1)
      expect(foo.column).to eq(1)

      bar = tokens[2] # after newline
      expect(bar.line).to eq(2)
      expect(bar.column).to eq(1)

      baz = tokens[4] # after newline and spaces
      expect(baz.line).to eq(3)
      expect(baz.column).to eq(3)
    end
  end

  describe "error handling" do
    it "raises error on invalid character" do
      scanner = described_class.new("foo § bar")

      expect { scanner.scan_all }.to raise_error(TRuby::Scanner::ScanError) do |error|
        expect(error.message).to include("Unexpected character")
        expect(error.line).to eq(1)
        expect(error.column).to eq(5)
      end
    end

    it "raises error on unterminated string" do
      scanner = described_class.new('"hello')

      expect { scanner.scan_all }.to raise_error(TRuby::Scanner::ScanError) do |error|
        expect(error.message).to include("Unterminated string")
      end
    end
  end

  describe "heredoc handling" do
    let(:source) { "sql = <<~SQL\n  SELECT * FROM users\nSQL" }

    it "tokenizes heredoc as a unit" do
      scanner = described_class.new(source)
      tokens = scanner.scan_all

      heredoc_token = tokens.find { |t| t.type == :heredoc }
      expect(heredoc_token).not_to be_nil
    end
  end
end
