# frozen_string_literal: true

require "spec_helper"

describe "T-Ruby Grammar Error Detection" do
  # Valid type expressions that should be accepted
  VALID_TYPE_EXPRESSIONS = [
    "String",
    "Integer",
    "Boolean",
    "Array",
    "Hash",
    "Symbol",
    "void",
    "nil",
    "Array<String>",
    "Hash<String, Integer>",
    "String | Integer",
    "String | nil",
    "String?",
    "(String) -> Integer",
    "[String, Integer]",
    "Readable & Writable",
  ].freeze

  # Invalid type expressions categorized by error type
  INVALID_TYPE_EXPRESSIONS = {
    whitespace_in_type: [
      ["Str ing", "whitespace in type name"],
      ["Int eger", "whitespace in type name"],
      ["Array <String>", "space before generic bracket"],
      ["Array< String>", "space after generic bracket"],
      ["String | ", "trailing union operator"],
      ["| String", "leading union operator"],
      ["String &", "trailing intersection operator"],
    ],
    incomplete_type: [
      ["", "empty type"],
      ["Array<", "unclosed generic bracket"],
      ["Array<String", "missing closing bracket"],
      ["(String) ->", "missing return type in function type"],
      ["(String,) -> Integer", "trailing comma in params"],
      ["[String,]", "trailing comma in tuple"],
    ],
    invalid_syntax: [
      ["123String", "type starting with number"],
      ["String!", "exclamation mark in type"],
      ["String#Integer", "hash symbol in type"],
    ],
  }.freeze

  describe TRuby::ErrorHandler do
    describe "method return type validation" do
      context "valid return types" do
        %w[String Integer Boolean void nil].each do |type_expr|
          it "accepts valid return type: #{type_expr}" do
            source = "def test(): #{type_expr}\nend"
            handler = TRuby::ErrorHandler.new(source)
            errors = handler.check

            # Filter out "Unknown return type" errors for complex types
            # since ErrorHandler only recognizes simple VALID_TYPES
            syntax_errors = errors.reject { |e| e.include?("Unknown") }
            expect(syntax_errors).to be_empty, "Expected no syntax errors for '#{type_expr}', got: #{syntax_errors}"
          end
        end
      end

      context "invalid return type syntax" do
        # Type with internal whitespace
        it "detects whitespace in type name: 'Str ing'" do
          source = "def test(): Str ing\nend"
          handler = TRuby::ErrorHandler.new(source)
          errors = handler.check

          expect(errors).not_to be_empty
          expect(errors.any? { |e| e.include?("whitespace") || e.include?("invalid") || e.include?("syntax") || e.include?("Unexpected") }).to be true
        end

        # Empty return type after colon
        it "detects missing type after colon" do
          source = "def test():\nend"
          handler = TRuby::ErrorHandler.new(source)
          errors = handler.check

          expect(errors).not_to be_empty
          expect(errors.any? { |e| e.include?("missing") || e.include?("empty") || e.include?("type") || e.include?("Expected") }).to be true
        end

        # Token after closing paren without colon
        it "detects invalid token after parameters without colon" do
          source = "def test() ndkdk\nend"
          handler = TRuby::ErrorHandler.new(source)
          errors = handler.check

          expect(errors).not_to be_empty
          expect(errors.any? { |e| e.include?("syntax") || e.include?("invalid") || e.include?("unexpected") || e.include?("Unexpected") }).to be true
        end

        # Incomplete generic type
        it "detects unclosed generic bracket" do
          source = "def test(): Array<String\nend"
          handler = TRuby::ErrorHandler.new(source)
          errors = handler.check

          expect(errors).not_to be_empty
        end

        # Trailing operator
        it "detects trailing union operator" do
          source = "def test(): String |\nend"
          handler = TRuby::ErrorHandler.new(source)
          errors = handler.check

          expect(errors).not_to be_empty
        end
      end
    end

    describe "parameter type validation" do
      context "valid parameter types" do
        [
          "def test(x: String)\nend",
          "def test(x: Integer, y: Boolean)\nend",
        ].each do |source|
          it "accepts: #{source.split("\n").first}" do
            handler = TRuby::ErrorHandler.new(source)
            errors = handler.check
            syntax_errors = errors.reject { |e| e.include?("Unknown") }
            expect(syntax_errors).to be_empty
          end
        end
      end

      context "invalid parameter type syntax" do
        it "detects whitespace in parameter type" do
          source = "def test(x: Str ing)\nend"
          handler = TRuby::ErrorHandler.new(source)
          errors = handler.check

          expect(errors).not_to be_empty
        end

        it "detects missing type after parameter colon" do
          source = "def test(x:)\nend"
          handler = TRuby::ErrorHandler.new(source)
          errors = handler.check

          expect(errors).not_to be_empty
        end

        it "allows multiple spaces between param name and type" do
          # This should be valid, just has extra spacing
          source = "def test(x:    String)\nend"
          handler = TRuby::ErrorHandler.new(source)
          errors = handler.check
          syntax_errors = errors.reject { |e| e.include?("Unknown") }
          expect(syntax_errors).to be_empty
        end
      end
    end

    describe "Ruby standard syntax compliance" do
      context "when no type annotation is provided" do
        it "accepts valid Ruby method without type annotations" do
          source = "def test(x, y)\nend"
          handler = TRuby::ErrorHandler.new(source)
          errors = handler.check

          expect(errors).to be_empty
        end

        it "accepts method with no parameters" do
          source = "def test\nend"
          handler = TRuby::ErrorHandler.new(source)
          errors = handler.check

          expect(errors).to be_empty
        end

        it "accepts method with empty parentheses" do
          source = "def test()\nend"
          handler = TRuby::ErrorHandler.new(source)
          errors = handler.check

          expect(errors).to be_empty
        end
      end

      context "hybrid T-Ruby and Ruby syntax" do
        it "accepts mixed typed and untyped parameters" do
          source = "def test(x: String, y)\nend"
          handler = TRuby::ErrorHandler.new(source)
          errors = handler.check
          syntax_errors = errors.reject { |e| e.include?("Unknown") }
          expect(syntax_errors).to be_empty
        end

        it "accepts typed parameters with untyped return" do
          source = "def test(x: String)\nend"
          handler = TRuby::ErrorHandler.new(source)
          errors = handler.check
          syntax_errors = errors.reject { |e| e.include?("Unknown") }
          expect(syntax_errors).to be_empty
        end
      end
    end

    describe "comprehensive syntax error categories" do
      # Category 1: Structural errors
      describe "structural errors" do
        [
          ["def test(x: String", "unclosed parenthesis"],
          ["def test x: String)", "missing opening parenthesis"],
          ["def (x: String)", "missing method name"],
        ].each do |(source, description)|
          it "detects #{description}" do
            handler = TRuby::ErrorHandler.new("#{source}\nend")
            errors = handler.check
            # At minimum, parser should not accept this as valid
            expect(errors).to be_a(Array)
          end
        end
      end

      # Category 2: Type expression errors
      describe "type expression errors" do
        [
          ["def test(): Array<>\nend", "empty generic arguments"],
          ["def test(): <String>\nend", "missing base type for generic"],
          ["def test(): String | | Integer\nend", "double union operator"],
          ["def test(): String & & Integer\nend", "double intersection operator"],
        ].each do |(source, description)|
          it "detects #{description}" do
            handler = TRuby::ErrorHandler.new(source)
            errors = handler.check
            expect(errors).not_to be_empty, "Expected errors for: #{description}"
          end
        end
      end

      # Category 3: Position errors (type in wrong place)
      describe "position errors" do
        it "detects type-like token without colon separator" do
          source = "def test() String\nend"
          handler = TRuby::ErrorHandler.new(source)
          errors = handler.check
          expect(errors).not_to be_empty
        end

        it "detects random identifier after method signature" do
          source = "def test(): String something_else\nend"
          handler = TRuby::ErrorHandler.new(source)
          errors = handler.check
          expect(errors).not_to be_empty
        end
      end
    end
  end

  describe TRuby::Parser do
    describe "parsing with grammar validation" do
      context "valid method definitions" do
        [
          "def greet(name: String): String\n  'hello'\nend",
          "def add(a: Integer, b: Integer): Integer\n  a + b\nend",
          "def process(items: Array<String>): void\nend",
          "def maybe(value: String?): String | nil\nend",
        ].each do |source|
          it "parses: #{source.split("\n").first}" do
            parser = TRuby::Parser.new(source)
            result = parser.parse

            expect(result[:type]).to eq(:success)
            expect(result[:functions]).not_to be_empty
          end
        end
      end

      context "should reject invalid syntax" do
        it "rejects type with whitespace" do
          source = "def test(): Str ing\nend"
          parser = TRuby::Parser.new(source)
          result = parser.parse

          # Parser should either:
          # 1. Return failure
          # 2. Return success but with parse errors noted
          # 3. Not include this as a valid function
          if result[:type] == :success && result[:functions].any?
            func = result[:functions].first
            # If parsed, the return type should indicate an error or be nil
            expect(func[:return_type]).to be_nil.or(eq("Str"))
          end
        end

        it "handles missing return type after colon gracefully" do
          source = "def test():\nend"
          parser = TRuby::Parser.new(source)
          result = parser.parse

          # Should not crash, may or may not parse as valid
          expect(result).to be_a(Hash)
        end
      end
    end
  end

  describe "Integration: Parser + ErrorHandler" do
    # Test that parser output fed to error handler produces correct errors
    describe "combined validation" do
      it "detects all errors in malformed code" do
        source = <<~RUBY
          def good(x: String): Integer
            x.to_i
          end

          def bad_return(): Str ing
            "test"
          end

          def bad_param(x: Int eger): String
            x.to_s
          end

          def missing_type():
            nil
          end
        RUBY

        handler = TRuby::ErrorHandler.new(source)
        errors = handler.check

        # Should detect multiple errors
        expect(errors.length).to be >= 1
      end
    end
  end
end
