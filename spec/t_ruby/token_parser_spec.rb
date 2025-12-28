# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::ParserCombinator::TokenParser do
  include TRuby::ParserCombinator::TokenDSL

  let(:scanner) { TRuby::Scanner.new(source) }
  let(:tokens) { scanner.scan_all }

  describe "basic token matching" do
    let(:source) { "def foo" }

    it "matches a specific token type" do
      parser = token(:def)
      result = parser.parse(tokens, 0)

      expect(result.success?).to be true
      expect(result.value.type).to eq(:def)
      expect(result.value.value).to eq("def")
      expect(result.position).to eq(1)
    end

    it "fails when token type does not match" do
      parser = token(:class)
      result = parser.parse(tokens, 0)

      expect(result.failure?).to be true
      expect(result.error).to include("Expected :class")
    end
  end

  describe "#keyword" do
    let(:source) { "def end class if return" }

    it "matches Ruby keywords" do
      expect(keyword(:def).parse(tokens, 0).success?).to be true
      expect(keyword(:end).parse(tokens, 1).success?).to be true
      expect(keyword(:class).parse(tokens, 2).success?).to be true
      expect(keyword(:if).parse(tokens, 3).success?).to be true
      expect(keyword(:return).parse(tokens, 4).success?).to be true
    end
  end

  describe "combinator operations" do
    describe "sequence (>>)" do
      let(:source) { "def foo" }

      it "sequences two token parsers" do
        parser = token(:def) >> token(:identifier)
        result = parser.parse(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_an(Array)
        expect(result.value[0].type).to eq(:def)
        expect(result.value[1].value).to eq("foo")
        expect(result.position).to eq(2)
      end

      it "fails if first parser fails" do
        parser = token(:class) >> token(:identifier)
        result = parser.parse(tokens, 0)

        expect(result.failure?).to be true
      end

      it "fails if second parser fails" do
        parser = token(:def) >> token(:class)
        result = parser.parse(tokens, 0)

        expect(result.failure?).to be true
      end
    end

    describe "alternative (|)" do
      let(:source) { "class Foo" }

      it "tries alternative when first fails" do
        parser = token(:def) | token(:class)
        result = parser.parse(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.type).to eq(:class)
      end
    end

    describe "#many" do
      let(:source) { "public private protected def" }

      it "matches zero or more tokens" do
        visibility = token(:public) | token(:private) | token(:protected)
        parser = visibility.many

        result = parser.parse(tokens, 0)
        expect(result.success?).to be true
        expect(result.value.length).to eq(3)
        expect(result.value.map(&:type)).to eq(%i[public private protected])
      end

      it "returns empty array when no matches" do
        parser = token(:class).many
        result = parser.parse(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to eq([])
      end
    end

    describe "#optional" do
      let(:source) { "def foo" }

      it "returns nil when not matching" do
        parser = token(:public).optional >> token(:def)
        result = parser.parse(tokens, 0)

        expect(result.success?).to be true
        expect(result.value[0]).to be_nil
        expect(result.value[1].type).to eq(:def)
      end

      let(:source_with_visibility) { "private def foo" }

      it "returns value when matching" do
        scanner2 = TRuby::Scanner.new("private def foo")
        tokens2 = scanner2.scan_all

        parser = token(:private).optional >> token(:def)
        result = parser.parse(tokens2, 0)

        expect(result.success?).to be true
        expect(result.value[0].type).to eq(:private)
        expect(result.value[1].type).to eq(:def)
      end
    end

    describe "#sep_by" do
      let(:source) { "String, Integer, Boolean" }

      it "parses comma-separated tokens" do
        parser = token(:constant).sep_by(token(:comma))
        result = parser.parse(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.length).to eq(3)
        expect(result.value.map(&:value)).to eq(%w[String Integer Boolean])
      end
    end

    describe "#map" do
      let(:source) { "42" }

      it "transforms the result" do
        parser = token(:integer).map { |t| t.value.to_i }
        result = parser.parse(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to eq(42)
      end
    end

    describe "skip right (<<)" do
      let(:source) { "foo;" }

      it "keeps left, discards right" do
        # Simulate semicolon by using newline
        scanner2 = TRuby::Scanner.new("foo\n")
        tokens2 = scanner2.scan_all

        parser = token(:identifier) << token(:newline)
        result = parser.parse(tokens2, 0)

        expect(result.success?).to be true
        expect(result.value.value).to eq("foo")
      end
    end
  end

  describe "complex parsing patterns" do
    describe "function signature" do
      let(:source) { "def greet(name: String): String" }

      it "parses a complete function signature" do
        # def identifier ( params ) : return_type
        param = token(:identifier) >> token(:colon) >> token(:constant)
        params = param.sep_by(token(:comma))
        return_type = (token(:colon) >> token(:constant)).optional

        func_sig = token(:def) >> token(:identifier) >>
                   token(:lparen) >> params >> token(:rparen) >>
                   return_type

        result = func_sig.parse(tokens, 0)

        expect(result.success?).to be true
      end
    end

    describe "type alias" do
      let(:source) { "type UserId = Integer" }

      it "parses a type alias" do
        type_alias = token(:type) >> token(:constant) >> token(:eq) >> token(:constant)
        result = type_alias.parse(tokens, 0)

        expect(result.success?).to be true
        values = flatten_tokens(result.value)
        expect(values.map(&:value)).to eq(%w[type UserId = Integer])
      end
    end

    describe "union type" do
      let(:source) { "String | Integer | nil" }

      it "parses union type syntax" do
        base_type = token(:constant) | token(:nil)
        union_type = base_type.sep_by(token(:pipe))

        result = union_type.parse(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.length).to eq(3)
      end
    end

    describe "generic type" do
      let(:source) { "Array<String>" }

      it "parses generic type syntax" do
        type_arg = token(:constant)
        generic = token(:constant) >> token(:lt) >> type_arg >> token(:gt)

        result = generic.parse(tokens, 0)

        expect(result.success?).to be true
      end
    end

    describe "visibility modifier" do
      let(:source) { "private def secret" }

      it "parses visibility with method definition" do
        visibility = token(:public) | token(:private) | token(:protected)
        method_def = visibility.optional >> token(:def) >> token(:identifier)

        result = method_def.parse(tokens, 0)

        expect(result.success?).to be true
      end
    end
  end

  describe "error handling" do
    let(:source) { "def 123" }

    it "provides useful error messages" do
      parser = token(:def) >> token(:identifier)
      result = parser.parse(tokens, 0)

      expect(result.failure?).to be true
      expect(result.error).to include("identifier")
    end
  end

  describe "position tracking" do
    let(:source) { "def foo end" }

    it "correctly advances position" do
      parser = token(:def) >> token(:identifier) >> token(:end)
      result = parser.parse(tokens, 0)

      expect(result.success?).to be true
      expect(result.position).to eq(3)
    end

    it "can parse from arbitrary position" do
      parser = token(:identifier)
      result = parser.parse(tokens, 1)

      expect(result.success?).to be true
      expect(result.value.value).to eq("foo")
    end
  end

  # Helper to flatten nested arrays of tokens
  def flatten_tokens(value)
    case value
    when Array
      value.flat_map { |v| flatten_tokens(v) }
    when TRuby::Scanner::Token
      [value]
    else
      []
    end
  end
end
