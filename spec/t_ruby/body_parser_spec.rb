# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::ParserCombinator::TokenBodyParser do
  subject(:parser) { described_class.new }

  describe "#parse" do
    it "parses string literal" do
      lines = ['  "hello world"']
      result = parser.parse(lines, 0, 1)

      expect(result).to be_a(TRuby::IR::Block)
      expect(result.statements.length).to eq(1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::Literal)
      expect(stmt.literal_type).to eq(:string)
      expect(stmt.value).to eq("hello world")
    end

    it "parses integer literal" do
      lines = ["  42"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::Literal)
      expect(stmt.literal_type).to eq(:integer)
      expect(stmt.value).to eq(42)
    end

    it "parses float literal" do
      lines = ["  3.14"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::Literal)
      expect(stmt.literal_type).to eq(:float)
      expect(stmt.value).to eq(3.14)
    end

    it "parses boolean literals" do
      lines = ["  true"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::Literal)
      expect(stmt.literal_type).to eq(:boolean)
      expect(stmt.value).to eq(true)
    end

    it "parses nil literal" do
      lines = ["  nil"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::Literal)
      expect(stmt.literal_type).to eq(:nil)
      expect(stmt.value).to be_nil
    end

    it "parses symbol literal" do
      lines = ["  :ok"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::Literal)
      expect(stmt.literal_type).to eq(:symbol)
      expect(stmt.value).to eq(:ok)
    end
  end

  describe "variable references" do
    it "parses local variable reference" do
      lines = ["  name"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::VariableRef)
      expect(stmt.name).to eq("name")
      expect(stmt.scope).to eq(:local)
    end

    it "parses instance variable reference" do
      lines = ["  @name"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::VariableRef)
      expect(stmt.name).to eq("@name")
      expect(stmt.scope).to eq(:instance)
    end
  end

  describe "assignments" do
    it "parses local variable assignment" do
      lines = ["  x = 42"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::Assignment)
      expect(stmt.target).to eq("x")
      expect(stmt.value).to be_a(TRuby::IR::Literal)
      expect(stmt.value.value).to eq(42)
    end

    it "parses instance variable assignment" do
      lines = ['  @name = "John"']
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::Assignment)
      expect(stmt.target).to eq("@name")
      expect(stmt.value).to be_a(TRuby::IR::Literal)
      expect(stmt.value.value).to eq("John")
    end
  end

  describe "return statements" do
    it "parses return with value" do
      lines = ['  return "done"']
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::Return)
      expect(stmt.value).to be_a(TRuby::IR::Literal)
      expect(stmt.value.value).to eq("done")
    end

    it "parses return without value" do
      lines = ["  return"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::Return)
      expect(stmt.value).to be_nil
    end
  end

  describe "binary operations" do
    it "parses addition" do
      lines = ["  a + b"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::BinaryOp)
      expect(stmt.operator).to eq(:+)
      expect(stmt.left).to be_a(TRuby::IR::VariableRef)
      expect(stmt.right).to be_a(TRuby::IR::VariableRef)
    end

    it "parses comparison" do
      lines = ["  x == y"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::BinaryOp)
      expect(stmt.operator).to eq(:==)
    end

    it "parses logical operators" do
      lines = ["  a && b"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::BinaryOp)
      expect(stmt.operator).to eq(:"&&")
    end
  end

  describe "method calls" do
    it "parses method call with receiver" do
      lines = ["  text.upcase"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::MethodCall)
      expect(stmt.method_name).to eq("upcase")
      expect(stmt.receiver).to be_a(TRuby::IR::VariableRef)
      expect(stmt.receiver.name).to eq("text")
    end

    it "parses method call with arguments" do
      lines = ['  str.gsub("a", "b")']
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::MethodCall)
      expect(stmt.method_name).to eq("gsub")
      expect(stmt.arguments.length).to eq(2)
    end

    it "parses method call without receiver" do
      lines = ['  puts("hello")']
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::MethodCall)
      expect(stmt.method_name).to eq("puts")
      expect(stmt.receiver).to be_nil
    end
  end

  describe "array literals" do
    it "parses empty array" do
      lines = ["  []"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::ArrayLiteral)
      expect(stmt.elements).to be_empty
    end

    it "parses array with elements" do
      lines = ["  [1, 2, 3]"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::ArrayLiteral)
      expect(stmt.elements.length).to eq(3)
      expect(stmt.elements.first.value).to eq(1)
    end
  end

  describe "hash literals" do
    it "parses empty hash" do
      lines = ["  {}"]
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::HashLiteral)
      expect(stmt.pairs).to be_empty
    end

    it "parses hash with symbol keys" do
      lines = ['  { name: "John", age: 30 }']
      result = parser.parse(lines, 0, 1)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::HashLiteral)
      expect(stmt.pairs.length).to eq(2)
    end
  end

  describe "multiple statements" do
    it "parses multiple lines" do
      lines = [
        "  x = 1",
        "  y = 2",
        "  x + y",
      ]
      result = parser.parse(lines, 0, 3)

      expect(result.statements.length).to eq(3)
      expect(result.statements[0]).to be_a(TRuby::IR::Assignment)
      expect(result.statements[1]).to be_a(TRuby::IR::Assignment)
      expect(result.statements[2]).to be_a(TRuby::IR::BinaryOp)
    end

    it "skips empty lines and comments" do
      lines = [
        "  x = 1",
        "",
        "  # this is a comment",
        "  x",
      ]
      result = parser.parse(lines, 0, 4)

      expect(result.statements.length).to eq(2)
    end
  end

  describe "conditional expressions" do
    it "parses if/else conditional" do
      lines = [
        "  if x == 1",
        "    true",
        "  else",
        "    false",
        "  end",
      ]
      result = parser.parse(lines, 0, 5)

      expect(result.statements.length).to eq(1)
      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::Conditional)
      expect(stmt.kind).to eq(:if)
      expect(stmt.then_branch).to be_a(TRuby::IR::Block)
      expect(stmt.else_branch).to be_a(TRuby::IR::Block)
    end

    it "parses if without else" do
      lines = [
        "  if x == 1",
        "    true",
        "  end",
      ]
      result = parser.parse(lines, 0, 3)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::Conditional)
      expect(stmt.then_branch).to be_a(TRuby::IR::Block)
      expect(stmt.else_branch).to be_nil
    end

    it "parses unless conditional" do
      lines = [
        "  unless x.nil?",
        "    x",
        "  end",
      ]
      result = parser.parse(lines, 0, 3)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::Conditional)
      expect(stmt.kind).to eq(:unless)
    end

    it "parses conditional returning nil or value" do
      lines = [
        "  if name == \"test\"",
        "    nil",
        "  else",
        "    name",
        "  end",
      ]
      result = parser.parse(lines, 0, 5)

      stmt = result.statements.first
      expect(stmt).to be_a(TRuby::IR::Conditional)

      then_stmt = stmt.then_branch.statements.first
      expect(then_stmt).to be_a(TRuby::IR::Literal)
      expect(then_stmt.literal_type).to eq(:nil)

      else_stmt = stmt.else_branch.statements.first
      expect(else_stmt).to be_a(TRuby::IR::VariableRef)
      expect(else_stmt.name).to eq("name")
    end
  end
end
