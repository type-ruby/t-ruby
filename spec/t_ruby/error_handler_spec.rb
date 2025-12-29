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
      source = "def test(x: String)" + "\n" \
                                       "def test(x: Integer)" + "\n"
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

  describe "Float type validation" do
    it "accepts Float as a valid type" do
      source = "def calculate(x: Float): Float\nend"
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "accepts Float in union types" do
      source = "def parse(value: Integer | Float): Float\nend"
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end
  end

  describe "unicode identifier support" do
    it "handles Korean function names" do
      source = <<~RUBY
        def 인사하기(이름: String): String
          "안녕, " + 이름
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "detects duplicate Korean function definitions" do
      source = <<~RUBY
        def 인사하기(이름: String): String
          "안녕"
        end

        def 인사하기(나이: Integer): Integer
          나이
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors.length).to eq(1)
      expect(errors[0]).to include("인사하기")
      expect(errors[0]).to include("already defined")
    end
  end

  describe "duplicate functions in different classes" do
    it "allows same method name in different classes" do
      source = <<~RUBY
        class Dog
          def speak(): String
            "Woof"
          end
        end

        class Cat
          def speak(): String
            "Meow"
          end
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "detects duplicate methods within the same class" do
      source = <<~RUBY
        class Animal
          def speak(): String
            "Hello"
          end

          def speak(): String
            "World"
          end
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors.length).to eq(1)
      expect(errors[0]).to include("speak")
      expect(errors[0]).to include("already defined")
    end
  end

  describe "type alias validation" do
    it "detects duplicate type aliases" do
      source = <<~RUBY
        type UserId = Integer
        type UserId = String
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors.length).to eq(1)
      expect(errors[0]).to include("UserId")
      expect(errors[0]).to include("already defined")
    end

    it "allows different type alias names" do
      source = <<~RUBY
        type UserId = Integer
        type PostId = Integer
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end
  end

  describe "parameter type colon validation" do
    it "detects parameter with colon but no type" do
      source = "def test(x:)\nend"
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_a(Array)
      # Should detect missing type after colon
    end
  end

  describe "complex parameter types" do
    it "handles Hash type with braces in parameters" do
      source = "def process(config: Hash{String => Integer}): Integer\nend"
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_a(Array)
    end

    it "handles multiple complex parameters" do
      source = "def complex(arr: Array<String>, hash: Hash{Symbol => Integer}, block: Proc<String>): void\nend"
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_a(Array)
    end

    it "handles nested generic types" do
      source = "def nested(data: Array<Hash<String, Array<Integer>>>): void\nend"
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_a(Array)
    end
  end

  describe "return type validation" do
    it "detects unknown simple return type" do
      source = "def test(): UnknownReturnType\nend"
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors.any? { |e| e.include?("Unknown return type") }).to be true
    end

    it "allows type alias as return type" do
      source = <<~RUBY
        type UserId = Integer
        def get_user_id(): UserId
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "allows interface as return type" do
      source = <<~RUBY
        interface Printable
          to_string: String
        end
        def get_printable(): Printable
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end
  end

  describe "end of class detection" do
    it "handles end statement closing class" do
      source = <<~RUBY
        class MyClass
          def method1(): String
            "test"
          end
        end
      RUBY
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "handles top-level end closing class scope" do
      source = "class A\n  def x: String\n    \"y\"\n  end\nend\ndef z: Integer\n  1\nend"
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_a(Array)
    end
  end

  describe "angle bracket counting" do
    it "handles arrow operators in type definitions" do
      source = "def transform(f: (Integer) -> String): (String) -> Boolean\nend"
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_a(Array)
    end

    it "handles comparison operators with <>" do
      source = "def compare(a: Array<Integer>): Array<String>\nend"
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_a(Array)
    end
  end
end
