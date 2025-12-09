# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::ParserCombinator do
  include TRuby::ParserCombinator::DSL

  describe TRuby::ParserCombinator::ParseResult do
    describe ".success" do
      it "creates a successful result" do
        result = described_class.success("value", "input", 5)
        expect(result.success?).to be true
        expect(result.value).to eq("value")
        expect(result.position).to eq(5)
      end
    end

    describe ".failure" do
      it "creates a failed result" do
        result = described_class.failure("error", "input", 3)
        expect(result.failure?).to be true
        expect(result.error).to eq("error")
      end
    end

    describe "#map" do
      it "transforms successful result" do
        result = described_class.success(5, "input", 1)
        mapped = result.map { |v| v * 2 }
        expect(mapped.value).to eq(10)
      end

      it "returns same failure" do
        result = described_class.failure("error", "input", 1)
        mapped = result.map { |v| v * 2 }
        expect(mapped.failure?).to be true
      end
    end
  end

  describe "Primitive Parsers" do
    describe TRuby::ParserCombinator::Literal do
      it "parses matching string" do
        parser = literal("hello")
        result = parser.parse("hello world")
        expect(result.success?).to be true
        expect(result.value).to eq("hello")
        expect(result.position).to eq(5)
      end

      it "fails on non-matching string" do
        parser = literal("hello")
        result = parser.parse("world")
        expect(result.failure?).to be true
      end
    end

    describe TRuby::ParserCombinator::Regex do
      it "parses matching pattern" do
        parser = regex(/\d+/)
        result = parser.parse("123abc")
        expect(result.success?).to be true
        expect(result.value).to eq("123")
      end

      it "fails on non-matching pattern" do
        parser = regex(/\d+/)
        result = parser.parse("abc")
        expect(result.failure?).to be true
      end
    end

    describe TRuby::ParserCombinator::Satisfy do
      it "parses character matching predicate" do
        parser = satisfy("digit") { |c| c =~ /\d/ }
        result = parser.parse("5abc")
        expect(result.success?).to be true
        expect(result.value).to eq("5")
      end
    end

    describe TRuby::ParserCombinator::EndOfInput do
      it "succeeds at end of input" do
        parser = eof
        result = parser.parse("", 0)
        expect(result.success?).to be true
      end

      it "fails when not at end" do
        parser = eof
        result = parser.parse("abc", 0)
        expect(result.failure?).to be true
      end
    end
  end

  describe "Combinators" do
    describe "sequence (>>)" do
      it "combines two parsers" do
        parser = literal("a") >> literal("b")
        result = parser.parse("ab")
        expect(result.success?).to be true
        expect(result.value).to eq(["a", "b"])
      end

      it "fails if first fails" do
        parser = literal("a") >> literal("b")
        result = parser.parse("bb")
        expect(result.failure?).to be true
      end

      it "fails if second fails" do
        parser = literal("a") >> literal("b")
        result = parser.parse("ac")
        expect(result.failure?).to be true
      end
    end

    describe "alternative (|)" do
      it "tries second if first fails" do
        parser = literal("a") | literal("b")
        result = parser.parse("b")
        expect(result.success?).to be true
        expect(result.value).to eq("b")
      end

      it "returns first if it succeeds" do
        parser = literal("a") | literal("b")
        result = parser.parse("a")
        expect(result.value).to eq("a")
      end
    end

    describe "#many" do
      it "parses zero occurrences" do
        parser = literal("a").many
        result = parser.parse("bbb")
        expect(result.success?).to be true
        expect(result.value).to eq([])
      end

      it "parses multiple occurrences" do
        parser = literal("a").many
        result = parser.parse("aaab")
        expect(result.success?).to be true
        expect(result.value).to eq(["a", "a", "a"])
      end
    end

    describe "#many1" do
      it "fails on zero occurrences" do
        parser = literal("a").many1
        result = parser.parse("bbb")
        expect(result.failure?).to be true
      end

      it "parses multiple occurrences" do
        parser = literal("a").many1
        result = parser.parse("aaab")
        expect(result.success?).to be true
        expect(result.value).to eq(["a", "a", "a"])
      end
    end

    describe "#optional" do
      it "returns nil when not present" do
        parser = literal("a").optional
        result = parser.parse("b")
        expect(result.success?).to be true
        expect(result.value).to be_nil
      end

      it "returns value when present" do
        parser = literal("a").optional
        result = parser.parse("a")
        expect(result.success?).to be true
        expect(result.value).to eq("a")
      end
    end

    describe "#sep_by" do
      it "parses items separated by delimiter" do
        parser = digit.sep_by(char(","))
        result = parser.parse("1,2,3")
        expect(result.success?).to be true
        expect(result.value).to eq(["1", "2", "3"])
      end

      it "returns empty array when no items" do
        parser = digit.sep_by(char(","))
        result = parser.parse("abc")
        expect(result.success?).to be true
        expect(result.value).to eq([])
      end
    end

    describe "#sep_by1" do
      it "requires at least one item" do
        parser = digit.sep_by1(char(","))
        result = parser.parse("abc")
        expect(result.failure?).to be true
      end

      it "parses one item" do
        parser = digit.sep_by1(char(","))
        result = parser.parse("1")
        expect(result.success?).to be true
        expect(result.value).to eq(["1"])
      end
    end

    describe "#between" do
      it "parses content between delimiters" do
        parser = identifier.between(char("("), char(")"))
        result = parser.parse("(foo)")
        expect(result.success?).to be true
        expect(result.value).to eq("foo")
      end
    end

    describe "skip right (<<)" do
      it "keeps left result, discards right" do
        parser = identifier << char(";")
        result = parser.parse("foo;")
        expect(result.success?).to be true
        expect(result.value).to eq("foo")
      end
    end

    describe "#map" do
      it "transforms result" do
        parser = digit.many1.map { |ds| ds.join.to_i }
        result = parser.parse("123")
        expect(result.success?).to be true
        expect(result.value).to eq(123)
      end
    end
  end

  describe "DSL helpers" do
    describe "#identifier" do
      it "parses valid identifier" do
        result = identifier.parse("foo_bar123")
        expect(result.success?).to be true
        expect(result.value).to eq("foo_bar123")
      end

      it "fails on starting with number" do
        result = identifier.parse("123foo")
        expect(result.failure?).to be true
      end
    end

    describe "#integer" do
      it "parses positive integer" do
        result = integer.parse("123")
        expect(result.success?).to be true
        expect(result.value).to eq(123)
      end

      it "parses negative integer" do
        result = integer.parse("-456")
        expect(result.success?).to be true
        expect(result.value).to eq(-456)
      end
    end

    describe "#float" do
      it "parses float" do
        result = float.parse("3.14")
        expect(result.success?).to be true
        expect(result.value).to eq(3.14)
      end
    end

    describe "#quoted_string" do
      it "parses quoted string" do
        result = quoted_string('"').parse('"hello world"')
        expect(result.success?).to be true
        expect(result.value).to eq("hello world")
      end
    end

    describe "#choice" do
      it "tries parsers in order" do
        parser = choice(literal("foo"), literal("bar"), literal("baz"))

        expect(parser.parse("foo").value).to eq("foo")
        expect(parser.parse("bar").value).to eq("bar")
        expect(parser.parse("baz").value).to eq("baz")
      end
    end

    describe "#lazy" do
      it "enables recursive parsers" do
        # Simple recursive expression: nested parens
        expr = nil
        expr = lazy { char("(") >> expr.optional << char(")") | char("x") }

        expect(expr.parse("x").success?).to be true
        expect(expr.parse("()").success?).to be true
        expect(expr.parse("(())").success?).to be true
      end
    end
  end

  describe TRuby::ParserCombinator::TypeParser do
    let(:parser) { described_class.new }

    describe "#parse" do
      it "parses simple type" do
        result = parser.parse("String")
        expect(result[:success]).to be true
        expect(result[:type]).to be_a(TRuby::IR::SimpleType)
        expect(result[:type].name).to eq("String")
      end

      it "parses generic type" do
        result = parser.parse("Array<String>")
        expect(result[:success]).to be true
        expect(result[:type]).to be_a(TRuby::IR::GenericType)
        expect(result[:type].base).to eq("Array")
        expect(result[:type].type_args.length).to eq(1)
      end

      it "parses nested generic type" do
        result = parser.parse("Map<String, Array<Integer>>")
        expect(result[:success]).to be true
        expect(result[:type]).to be_a(TRuby::IR::GenericType)
        expect(result[:type].base).to eq("Map")
        expect(result[:type].type_args.length).to eq(2)
        expect(result[:type].type_args[1]).to be_a(TRuby::IR::GenericType)
      end

      it "parses union type" do
        result = parser.parse("String | Integer | nil")
        expect(result[:success]).to be true
        expect(result[:type]).to be_a(TRuby::IR::UnionType)
        expect(result[:type].types.length).to eq(3)
      end

      it "parses intersection type" do
        result = parser.parse("Readable & Writable")
        expect(result[:success]).to be true
        expect(result[:type]).to be_a(TRuby::IR::IntersectionType)
        expect(result[:type].types.length).to eq(2)
      end

      it "parses nullable type" do
        result = parser.parse("String?")
        expect(result[:success]).to be true
        expect(result[:type]).to be_a(TRuby::IR::NullableType)
        expect(result[:type].inner_type.name).to eq("String")
      end

      it "parses function type" do
        result = parser.parse("(String, Integer) -> Boolean")
        expect(result[:success]).to be true
        expect(result[:type]).to be_a(TRuby::IR::FunctionType)
        expect(result[:type].param_types.length).to eq(2)
        expect(result[:type].return_type.name).to eq("Boolean")
      end

      it "parses tuple type" do
        result = parser.parse("[String, Integer, Boolean]")
        expect(result[:success]).to be true
        expect(result[:type]).to be_a(TRuby::IR::TupleType)
        expect(result[:type].element_types.length).to eq(3)
      end

      it "parses complex nested type" do
        result = parser.parse("Map<String, Array<Tuple<Integer, String>>> | nil")
        expect(result[:success]).to be true
        expect(result[:type]).to be_a(TRuby::IR::UnionType)
      end

      it "parses parenthesized type" do
        result = parser.parse("(String | Integer)")
        expect(result[:success]).to be true
        expect(result[:type]).to be_a(TRuby::IR::UnionType)
      end

      it "handles whitespace" do
        result = parser.parse("  Array < String >  ")
        expect(result[:success]).to be true
        expect(result[:type]).to be_a(TRuby::IR::GenericType)
      end
    end
  end

  describe TRuby::ParserCombinator::DeclarationParser do
    let(:parser) { described_class.new }

    describe "#parse" do
      it "parses type alias" do
        result = parser.parse("type UserId = String")
        expect(result[:success]).to be true
        decl = result[:declarations]
        expect(decl).to be_a(TRuby::IR::TypeAlias)
        expect(decl.name).to eq("UserId")
      end

      it "parses complex type alias" do
        result = parser.parse("type Callback = (String) -> Integer")
        expect(result[:success]).to be true
        decl = result[:declarations]
        expect(decl.definition).to be_a(TRuby::IR::FunctionType)
      end

      it "parses method definition" do
        result = parser.parse("def greet(name: String): String")
        expect(result[:success]).to be true
        decl = result[:declarations]
        expect(decl).to be_a(TRuby::IR::MethodDef)
        expect(decl.name).to eq("greet")
        expect(decl.params.length).to eq(1)
      end

      it "parses method with multiple parameters" do
        result = parser.parse("def add(a: Integer, b: Integer): Integer")
        expect(result[:success]).to be true
        decl = result[:declarations]
        expect(decl.params.length).to eq(2)
      end

      it "parses method without return type" do
        result = parser.parse("def process(data: String)")
        expect(result[:success]).to be true
        decl = result[:declarations]
        expect(decl.return_type).to be_nil
      end
    end

    describe "#parse_file" do
      it "parses multiple declarations" do
        source = <<~TRB
          type UserId = String
          type Email = String

          def greet(name: String): String
        TRB

        result = parser.parse_file(source)
        expect(result[:success]).to be true
        expect(result[:declarations].length).to eq(3)
      end

      it "handles empty lines" do
        source = <<~TRB
          type UserId = String

          type Email = String
        TRB

        result = parser.parse_file(source)
        expect(result[:success]).to be true
        expect(result[:declarations].length).to eq(2)
      end
    end
  end

  describe TRuby::ParserCombinator::ParseError do
    it "calculates line and column" do
      input = "line1\nline2\nerror here"
      error = described_class.new(message: "Unexpected", position: 15, input: input)

      expect(error.line).to eq(3)
      expect(error.column).to eq(4)
    end

    it "formats error message" do
      input = "test"
      error = described_class.new(message: "Unexpected", position: 2, input: input)

      expect(error.to_s).to include("line 1")
      expect(error.to_s).to include("column 3")
    end

    it "provides context" do
      input = "line1\nline2\nerror here\nline4"
      error = described_class.new(message: "Unexpected", position: 15, input: input)

      context = error.context
      expect(context).to include(">>>")
      expect(context).to include("error here")
    end
  end

  describe TRuby::ParserCombinator::ChainLeft do
    include TRuby::ParserCombinator::DSL

    it "parses left-associative operations" do
      num = digit.many1.map { |ds| ds.join.to_i }
      add_op = lexeme(char("+")).map { |_| ->(a, b) { a + b } }
      parser = chainl(num, add_op)

      result = parser.parse("1 + 2 + 3")
      expect(result.success?).to be true
      expect(result.value).to eq(6)
    end

    it "handles single term" do
      num = digit.many1.map { |ds| ds.join.to_i }
      add_op = lexeme(char("+")).map { |_| ->(a, b) { a + b } }
      parser = chainl(num, add_op)

      result = parser.parse("42")
      expect(result.success?).to be true
      expect(result.value).to eq(42)
    end
  end
end
