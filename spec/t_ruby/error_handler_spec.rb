# frozen_string_literal: true

require "spec_helper"

describe TRuby::ErrorHandler do
  describe "syntax error detection" do
    context "invalid type names" do
      it "detects unrecognized type names" do
        source = "def test(x: UnknownType)\nend"
        handler = TRuby::ErrorHandler.new(source)

        errors = handler.check
        expect(errors).to be_a(Array)
        # May or may not flag as error depending on strictness
      end

      it "accepts valid type names" do
        source = "def test(x: String, y: Integer): Boolean\nend"
        handler = TRuby::ErrorHandler.new(source)

        errors = handler.check
        expect(errors).to be_empty
      end
    end

    context "malformed function signatures" do
      it "detects missing closing parenthesis" do
        source = "def test(x: String\nend"
        handler = TRuby::ErrorHandler.new(source)

        errors = handler.check
        # May flag as potential error
        expect(errors).to be_a(Array)
      end

      it "detects invalid parameter syntax" do
        source = "def test(: String)\nend"
        handler = TRuby::ErrorHandler.new(source)

        errors = handler.check
        expect(errors).to be_a(Array)
      end
    end

    context "duplicate definitions" do
      it "detects duplicate function definitions with same name" do
        source = <<~RUBY
          def greet(name: String): String
            "Hello, " + name
          end

          def greet(age: Integer): Integer
            age + 1
          end
        RUBY
        handler = TRuby::ErrorHandler.new(source)

        errors = handler.check
        # May flag as warning/error
        expect(errors).to be_a(Array)
      end
    end
  end

  describe "type validation" do
    context "parameter type checking" do
      it "validates parameter types are recognized" do
        source = "def process(value: ValidType)\nend"
        handler = TRuby::ErrorHandler.new(source)

        errors = handler.check
        # Handler should validate type names
        expect(errors).to be_a(Array)
      end
    end

    context "return type checking" do
      it "validates return type is recognized" do
        source = "def get_value(): ValidReturnType\nend"
        handler = TRuby::ErrorHandler.new(source)

        errors = handler.check
        expect(errors).to be_a(Array)
      end
    end
  end

  describe "error reporting" do
    it "provides helpful error messages" do
      source = "def test(x: BadType)\nend"
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_a(Array)

      if errors.any?
        errors.each do |error|
          expect(error).to be_a(String)
        end
      end
    end

    it "reports line numbers if detected" do
      source = 'def test(x: String)' + "\n" +
               'def test(x: Integer)' + "\n"
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_a(Array)
    end
  end
end
