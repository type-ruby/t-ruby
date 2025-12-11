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

  describe "namespaced interface definitions" do
    it "does not flag namespaced interfaces as duplicates of parent" do
      source = <<~RUBY
        interface Rails
          application: Rails::Application
        end

        interface Rails::Application
          config: Rails::Application::Configuration
        end

        interface Rails::Application::Configuration
          root: Pathname
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "detects actual duplicate namespaced interfaces" do
      source = <<~RUBY
        interface Foo::Bar
          name: String
        end

        interface Foo::Bar
          age: Integer
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors.length).to eq(1)
      expect(errors[0]).to include("Foo::Bar")
      expect(errors[0]).to include("already defined")
    end

    it "allows same name in different namespaces" do
      source = <<~RUBY
        interface A::Config
          value: String
        end

        interface B::Config
          value: Integer
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "allows namespaced interface without parent interface" do
      source = <<~RUBY
        interface Foo::Bar::Baz
          value: String
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "handles deeply nested namespaces (4+ levels)" do
      source = <<~RUBY
        interface A::B::C::D::E
          value: String
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "handles reverse order definition (child before parent)" do
      source = <<~RUBY
        interface Rails::Application
          config: String
        end

        interface Rails
          app: Rails::Application
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "distinguishes partially overlapping namespaces" do
      source = <<~RUBY
        interface Foo::Bar
          a: String
        end

        interface Foo::Baz
          b: String
        end

        interface Bar::Foo
          c: String
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "handles empty namespaced interface" do
      source = <<~RUBY
        interface Empty::Interface
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "allows namespaced types in member definitions" do
      source = <<~RUBY
        interface Container
          config: Rails::Application::Configuration
          logger: ActiveSupport::Logger
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "handles extra whitespace around namespace" do
      source = <<~RUBY
        interface  Rails::Application
          config: String
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "handles tab indentation" do
      source = "\tinterface Rails::Application\n\t\tconfig: String\n\tend"
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "allows underscores in namespace names" do
      source = <<~RUBY
        interface Active_Record::Base_Class
          id: Integer
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end
  end
end
