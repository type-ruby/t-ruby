# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::ParserCombinator::StatementParser do
  include TRuby::ParserCombinator::TokenDSL

  let(:parser) { described_class.new }
  let(:scanner) { TRuby::Scanner.new(source) }
  let(:tokens) { scanner.scan_all }

  describe "expression statements" do
    let(:source) { "foo(1, 2)" }

    it "parses expression as statement" do
      result = parser.parse_statement(tokens, 0)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::MethodCall)
    end
  end

  describe "assignment statements" do
    describe "local variable assignment" do
      let(:source) { "x = 42" }

      it "parses simple assignment" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Assignment)
        expect(result.value.target).to eq("x")
        expect(result.value.value).to be_a(TRuby::IR::Literal)
        expect(result.value.value.value).to eq(42)
      end
    end

    describe "instance variable assignment" do
      let(:source) { "@name = value" }

      it "parses instance variable assignment" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Assignment)
        expect(result.value.target).to eq("@name")
      end
    end

    describe "class variable assignment" do
      let(:source) { "@@count = 0" }

      it "parses class variable assignment" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.target).to eq("@@count")
      end
    end

    describe "typed assignment" do
      let(:source) { "name: String = value" }

      it "parses typed assignment" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Assignment)
        expect(result.value.target).to eq("name")
        expect(result.value.type_annotation).not_to be_nil
      end
    end

    describe "compound assignment" do
      it "parses += operator" do
        scanner = TRuby::Scanner.new("x += 1")
        result = parser.parse_statement(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Assignment)
        # Compound assignment expands to x = x + 1
        expect(result.value.value).to be_a(TRuby::IR::BinaryOp)
        expect(result.value.value.operator).to eq(:+)
      end
    end
  end

  describe "return statements" do
    describe "return without value" do
      let(:source) { "return" }

      it "parses empty return" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Return)
        expect(result.value.value).to be_nil
      end
    end

    describe "return with value" do
      let(:source) { "return 42" }

      it "parses return with expression" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Return)
        expect(result.value.value).to be_a(TRuby::IR::Literal)
        expect(result.value.value.value).to eq(42)
      end
    end

    describe "return with complex expression" do
      let(:source) { "return foo + bar" }

      it "parses return with binary operation" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.value).to be_a(TRuby::IR::BinaryOp)
      end
    end
  end

  describe "if statements" do
    describe "simple if" do
      let(:source) { "if condition\n  foo\nend" }

      it "parses if statement" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Conditional)
        expect(result.value.kind).to eq(:if)
        expect(result.value.condition).not_to be_nil
        expect(result.value.then_branch).not_to be_nil
      end
    end

    describe "if with else" do
      let(:source) { "if condition\n  foo\nelse\n  bar\nend" }

      it "parses if-else statement" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Conditional)
        expect(result.value.else_branch).not_to be_nil
      end
    end

    describe "if with elsif" do
      let(:source) { "if a\n  1\nelsif b\n  2\nelse\n  3\nend" }

      it "parses if-elsif-else chain" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Conditional)
        # elsif becomes nested if in else branch
        expect(result.value.else_branch).to be_a(TRuby::IR::Conditional)
      end
    end
  end

  describe "unless statements" do
    let(:source) { "unless condition\n  foo\nend" }

    it "parses unless statement" do
      result = parser.parse_statement(tokens, 0)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::Conditional)
      expect(result.value.kind).to eq(:unless)
    end
  end

  describe "while statements" do
    let(:source) { "while condition\n  foo\nend" }

    it "parses while loop" do
      result = parser.parse_statement(tokens, 0)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::Loop)
      expect(result.value.kind).to eq(:while)
      expect(result.value.condition).not_to be_nil
      expect(result.value.body).not_to be_nil
    end
  end

  describe "until statements" do
    let(:source) { "until done\n  work\nend" }

    it "parses until loop" do
      result = parser.parse_statement(tokens, 0)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::Loop)
      expect(result.value.kind).to eq(:until)
    end
  end

  describe "case statements" do
    let(:source) do
      <<~RUBY
        case x
        when 1
          foo
        when 2
          bar
        else
          baz
        end
      RUBY
    end

    it "parses case expression" do
      result = parser.parse_statement(tokens, 0)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::CaseExpr)
      expect(result.value.subject).not_to be_nil
      expect(result.value.when_clauses.length).to eq(2)
      expect(result.value.else_clause).not_to be_nil
    end
  end

  describe "begin/rescue/ensure" do
    describe "simple rescue" do
      let(:source) do
        <<~RUBY
          begin
            risky
          rescue
            handle
          end
        RUBY
      end

      it "parses begin-rescue block" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::BeginBlock)
        expect(result.value.rescue_clauses).not_to be_empty
      end
    end

    describe "rescue with exception type" do
      let(:source) do
        <<~RUBY
          begin
            risky
          rescue StandardError => e
            handle(e)
          end
        RUBY
      end

      it "parses rescue with exception binding" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.rescue_clauses.first.exception_types).not_to be_empty
        expect(result.value.rescue_clauses.first.variable).to eq("e")
      end
    end

    describe "with ensure" do
      let(:source) do
        <<~RUBY
          begin
            risky
          ensure
            cleanup
          end
        RUBY
      end

      it "parses ensure clause" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.ensure_clause).not_to be_nil
      end
    end
  end

  describe "block parsing" do
    let(:source) do
      <<~RUBY
        foo
        bar
        baz
      RUBY
    end

    it "parses multiple statements into a block" do
      result = parser.parse_block(tokens, 0)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::Block)
      expect(result.value.statements.length).to eq(3)
    end
  end

  describe "modifier statements" do
    describe "if modifier" do
      let(:source) { "return 0 if x < 0" }

      it "parses statement with if modifier" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Conditional)
        expect(result.value.kind).to eq(:if)
        # then_branch is wrapped in a Block containing the Return
        expect(result.value.then_branch).to be_a(TRuby::IR::Block)
        expect(result.value.then_branch.statements.first).to be_a(TRuby::IR::Return)
      end
    end

    describe "unless modifier" do
      let(:source) { "foo unless condition" }

      it "parses statement with unless modifier" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Conditional)
        expect(result.value.kind).to eq(:unless)
      end
    end

    describe "while modifier" do
      let(:source) { "x += 1 while condition" }

      it "parses statement with while modifier" do
        result = parser.parse_statement(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Loop)
        expect(result.value.kind).to eq(:while)
      end
    end
  end
end
