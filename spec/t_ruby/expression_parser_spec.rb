# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::ParserCombinator::ExpressionParser do
  include TRuby::ParserCombinator::TokenDSL

  let(:parser) { described_class.new }
  let(:scanner) { TRuby::Scanner.new(source) }
  let(:tokens) { scanner.scan_all }

  describe "literals" do
    describe "integer literals" do
      let(:source) { "42" }

      it "parses integer literals" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Literal)
        expect(result.value.literal_type).to eq(:integer)
        expect(result.value.value).to eq(42)
      end
    end

    describe "float literals" do
      let(:source) { "3.14" }

      it "parses float literals" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Literal)
        expect(result.value.literal_type).to eq(:float)
        expect(result.value.value).to eq(3.14)
      end
    end

    describe "string literals" do
      let(:source) { '"hello world"' }

      it "parses string literals" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Literal)
        expect(result.value.literal_type).to eq(:string)
        expect(result.value.value).to eq("hello world")
      end
    end

    describe "symbol literals" do
      let(:source) { ":foo" }

      it "parses symbol literals" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Literal)
        expect(result.value.literal_type).to eq(:symbol)
        expect(result.value.value).to eq(:foo)
      end
    end

    describe "boolean literals" do
      it "parses true" do
        scanner = TRuby::Scanner.new("true")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Literal)
        expect(result.value.literal_type).to eq(:boolean)
        expect(result.value.value).to be true
      end

      it "parses false" do
        scanner = TRuby::Scanner.new("false")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.literal_type).to eq(:boolean)
        expect(result.value.value).to be false
      end
    end

    describe "nil literal" do
      let(:source) { "nil" }

      it "parses nil" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Literal)
        expect(result.value.literal_type).to eq(:nil)
        expect(result.value.value).to be_nil
      end
    end
  end

  describe "variable references" do
    describe "local variables" do
      let(:source) { "foo" }

      it "parses local variable reference" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::VariableRef)
        expect(result.value.name).to eq("foo")
        expect(result.value.scope).to eq(:local)
      end
    end

    describe "instance variables" do
      let(:source) { "@name" }

      it "parses instance variable reference" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::VariableRef)
        expect(result.value.name).to eq("@name")
        expect(result.value.scope).to eq(:instance)
      end
    end

    describe "class variables" do
      let(:source) { "@@count" }

      it "parses class variable reference" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::VariableRef)
        expect(result.value.name).to eq("@@count")
        expect(result.value.scope).to eq(:class)
      end
    end

    describe "global variables" do
      let(:source) { "$stdout" }

      it "parses global variable reference" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::VariableRef)
        expect(result.value.name).to eq("$stdout")
        expect(result.value.scope).to eq(:global)
      end
    end

    describe "constants" do
      let(:source) { "MyClass" }

      it "parses constant reference" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::VariableRef)
        expect(result.value.name).to eq("MyClass")
        expect(result.value.scope).to eq(:constant)
      end
    end
  end

  describe "binary operations" do
    describe "arithmetic" do
      it "parses addition" do
        scanner = TRuby::Scanner.new("1 + 2")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::BinaryOp)
        expect(result.value.operator).to eq(:+)
        expect(result.value.left).to be_a(TRuby::IR::Literal)
        expect(result.value.right).to be_a(TRuby::IR::Literal)
      end

      it "parses subtraction" do
        scanner = TRuby::Scanner.new("5 - 3")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::BinaryOp)
        expect(result.value.operator).to eq(:-)
      end

      it "parses multiplication" do
        scanner = TRuby::Scanner.new("4 * 3")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.operator).to eq(:*)
      end

      it "parses division" do
        scanner = TRuby::Scanner.new("10 / 2")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.operator).to eq(:/)
      end

      it "parses modulo" do
        scanner = TRuby::Scanner.new("7 % 3")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.operator).to eq(:%)
      end

      it "parses exponentiation" do
        scanner = TRuby::Scanner.new("2 ** 3")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.operator).to eq(:**)
      end
    end

    describe "comparison" do
      it "parses equality" do
        scanner = TRuby::Scanner.new("a == b")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.operator).to eq(:==)
      end

      it "parses inequality" do
        scanner = TRuby::Scanner.new("a != b")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.operator).to eq(:!=)
      end

      it "parses less than" do
        scanner = TRuby::Scanner.new("a < b")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.operator).to eq(:<)
      end

      it "parses greater than" do
        scanner = TRuby::Scanner.new("a > b")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.operator).to eq(:>)
      end

      it "parses less than or equal" do
        scanner = TRuby::Scanner.new("a <= b")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.operator).to eq(:<=)
      end

      it "parses greater than or equal" do
        scanner = TRuby::Scanner.new("a >= b")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.operator).to eq(:>=)
      end

      it "parses spaceship operator" do
        scanner = TRuby::Scanner.new("a <=> b")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.operator).to eq(:<=>)
      end
    end

    describe "logical" do
      it "parses logical and" do
        scanner = TRuby::Scanner.new("a && b")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.operator).to eq(:"&&")
      end

      it "parses logical or" do
        scanner = TRuby::Scanner.new("a || b")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.operator).to eq(:"||")
      end
    end

    describe "operator precedence" do
      it "respects multiplication over addition" do
        scanner = TRuby::Scanner.new("1 + 2 * 3")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        # Should be parsed as 1 + (2 * 3)
        expect(result.value).to be_a(TRuby::IR::BinaryOp)
        expect(result.value.operator).to eq(:+)
        expect(result.value.right).to be_a(TRuby::IR::BinaryOp)
        expect(result.value.right.operator).to eq(:*)
      end

      it "respects exponentiation over multiplication" do
        scanner = TRuby::Scanner.new("2 * 3 ** 2")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        # Should be parsed as 2 * (3 ** 2)
        expect(result.value.operator).to eq(:*)
        expect(result.value.right.operator).to eq(:**)
      end

      it "respects comparison over logical" do
        scanner = TRuby::Scanner.new("a > b && c < d")
        result = parser.parse_expression(scanner.scan_all, 0)

        expect(result.success?).to be true
        # Should be parsed as (a > b) && (c < d)
        expect(result.value.operator).to eq(:"&&")
        expect(result.value.left.operator).to eq(:>)
        expect(result.value.right.operator).to eq(:<)
      end
    end
  end

  describe "unary operations" do
    it "parses logical not" do
      scanner = TRuby::Scanner.new("!foo")
      result = parser.parse_expression(scanner.scan_all, 0)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::UnaryOp)
      expect(result.value.operator).to eq(:!)
      expect(result.value.operand).to be_a(TRuby::IR::VariableRef)
    end

    it "parses negative numbers as unary minus" do
      scanner = TRuby::Scanner.new("-42")
      result = parser.parse_expression(scanner.scan_all, 0)

      expect(result.success?).to be true
      # Could be parsed as UnaryOp or negative Literal
      if result.value.is_a?(TRuby::IR::UnaryOp)
        expect(result.value.operator).to eq(:-)
      else
        expect(result.value).to be_a(TRuby::IR::Literal)
        expect(result.value.value).to eq(-42)
      end
    end
  end

  describe "method calls" do
    describe "simple method call" do
      let(:source) { "foo()" }

      it "parses method call without arguments" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::MethodCall)
        expect(result.value.method_name).to eq("foo")
        expect(result.value.arguments).to be_empty
      end
    end

    describe "method call with arguments" do
      let(:source) { "foo(1, 2, 3)" }

      it "parses method call with arguments" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::MethodCall)
        expect(result.value.method_name).to eq("foo")
        expect(result.value.arguments.length).to eq(3)
      end
    end

    describe "method call on receiver" do
      let(:source) { "obj.method(arg)" }

      it "parses method call with receiver" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::MethodCall)
        expect(result.value.method_name).to eq("method")
        expect(result.value.receiver).to be_a(TRuby::IR::VariableRef)
        expect(result.value.receiver.name).to eq("obj")
      end
    end

    describe "chained method calls" do
      let(:source) { "a.b.c" }

      it "parses chained method calls" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::MethodCall)
        expect(result.value.method_name).to eq("c")
        expect(result.value.receiver).to be_a(TRuby::IR::MethodCall)
        expect(result.value.receiver.method_name).to eq("b")
      end
    end
  end

  describe "array literals" do
    describe "empty array" do
      let(:source) { "[]" }

      it "parses empty array" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::ArrayLiteral)
        expect(result.value.elements).to be_empty
      end
    end

    describe "array with elements" do
      let(:source) { "[1, 2, 3]" }

      it "parses array with elements" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::ArrayLiteral)
        expect(result.value.elements.length).to eq(3)
      end
    end
  end

  describe "hash literals" do
    describe "empty hash" do
      let(:source) { "{}" }

      it "parses empty hash" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::HashLiteral)
        expect(result.value.pairs).to be_empty
      end
    end

    describe "hash with pairs" do
      let(:source) { "{ a: 1, b: 2 }" }

      it "parses hash with symbol keys" do
        result = parser.parse_expression(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::HashLiteral)
        expect(result.value.pairs.length).to eq(2)
      end
    end
  end

  describe "parenthesized expressions" do
    let(:source) { "(1 + 2)" }

    it "parses parenthesized expression" do
      result = parser.parse_expression(tokens, 0)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::BinaryOp)
      expect(result.value.operator).to eq(:+)
    end

    it "respects parentheses for precedence override" do
      scanner = TRuby::Scanner.new("(1 + 2) * 3")
      result = parser.parse_expression(scanner.scan_all, 0)

      expect(result.success?).to be true
      # Should be parsed as (1 + 2) * 3
      expect(result.value.operator).to eq(:*)
      expect(result.value.left).to be_a(TRuby::IR::BinaryOp)
      expect(result.value.left.operator).to eq(:+)
    end
  end

  describe "complex expressions" do
    it "parses method call with binary operation" do
      scanner = TRuby::Scanner.new("foo(1 + 2)")
      result = parser.parse_expression(scanner.scan_all, 0)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::MethodCall)
      expect(result.value.arguments[0]).to be_a(TRuby::IR::BinaryOp)
    end

    it "parses nested method calls" do
      scanner = TRuby::Scanner.new("foo(bar(1))")
      result = parser.parse_expression(scanner.scan_all, 0)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::MethodCall)
      expect(result.value.arguments[0]).to be_a(TRuby::IR::MethodCall)
    end

    it "parses array access" do
      scanner = TRuby::Scanner.new("arr[0]")
      result = parser.parse_expression(scanner.scan_all, 0)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::MethodCall)
      expect(result.value.method_name).to eq("[]")
    end
  end

  describe "yield expressions" do
    it "parses yield without arguments as expression" do
      scanner = TRuby::Scanner.new("yield")
      result = parser.parse_expression(scanner.scan_all, 0)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::Yield)
      expect(result.value.arguments).to be_empty
    end

    it "parses yield with parenthesized arguments" do
      scanner = TRuby::Scanner.new("yield(1, 2)")
      result = parser.parse_expression(scanner.scan_all, 0)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::Yield)
      expect(result.value.arguments.length).to eq(2)
    end

    it "parses yield in assignment context" do
      # This tests that yield can appear on RHS of assignment
      scanner = TRuby::Scanner.new("yield(x)")
      result = parser.parse_expression(scanner.scan_all, 0)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::Yield)
      expect(result.value.arguments.length).to eq(1)
    end
  end
end
