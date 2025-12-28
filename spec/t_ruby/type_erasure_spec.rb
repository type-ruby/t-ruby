# frozen_string_literal: true

require "spec_helper"

describe TRuby::TypeErasure do
  describe "type annotation removal" do
    context "parameter type annotations" do
      it "removes simple parameter type annotation" do
        source = "def greet(name: String)\n  puts name\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def greet(name)")
        expect(result).not_to include(": String")
      end

      it "removes multiple parameter type annotations" do
        source = "def add(a: Integer, b: Integer)\n  a + b\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def add(a, b)")
        expect(result).not_to include(": Integer")
      end

      it "preserves function body" do
        source = "def greet(name: String)" + "\n  " \
                                             'puts "Hello, #{name}"' + "\n" \
                                                                       "end"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include('puts "Hello, #{')
      end

      it "handles multiple parameters with various types" do
        source = "def create(name: String, age: Integer, active: Boolean)\n  name\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def create(name, age, active)")
      end

      it "preserves default value for parameter with type" do
        source = "def greet(name: String, greeting: String = \"Hello\")\n  " \
                 "\"\#{greeting}, \#{name}!\"\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include('def greet(name, greeting = "Hello")')
        expect(result).not_to include(": String")
      end

      it "preserves default value with numeric value" do
        source = "def add(a: Integer, b: Integer = 0)\n  a + b\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def add(a, b = 0)")
      end

      it "preserves default value with nil" do
        source = "def find(id: Integer, fallback: String = nil)\n  id\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def find(id, fallback = nil)")
      end

      it "preserves multiple default values" do
        source = "def config(host: String = \"localhost\", port: Integer = 8080)\n  " \
                 "host\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include('def config(host = "localhost", port = 8080)')
      end
    end

    context "return type annotations" do
      it "removes return type annotation" do
        source = "def get_name(): String\n  'John'\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def get_name()")
        expect(result).not_to include(": String")
      end

      it "removes return type when there are parameters" do
        source = "def greet(name: String): String\n  name\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def greet(name)")
        expect(result).not_to include(": String")
      end

      it "removes void return type" do
        source = "def do_something(): void\n  puts 'done'\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def do_something()")
        expect(result).not_to include(": void")
      end
    end

    context "mixed typed and untyped code" do
      it "preserves untyped function definitions" do
        source = "def untyped(x)\n  x\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to eq(source)
      end

      it "handles code with typed and untyped functions" do
        source = <<~RUBY
          def typed(x: String)
            x
          end

          def untyped(y)
            y
          end
        RUBY
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def typed(x)")
        expect(result).to include("def untyped(y)")
      end

      it "preserves comments" do
        source = <<~RUBY
          # This is a comment
          def greet(name: String): String
            # Inner comment
            name
          end
        RUBY
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("# This is a comment")
        expect(result).to include("# Inner comment")
      end
    end

    context "special cases" do
      it "handles functions with no parameters" do
        source = "def hello(): String\n  'hello'\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def hello()")
      end

      it "handles functions without parentheses and with return type" do
        source = "def hello: String\n  'hello'\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def hello")
        expect(result).not_to include(": String")
      end

      it "handles nested structures" do
        source = "class Greeter" + "\n  " \
                                   "def greet(name: String): String" + "\n    " \
                                                                       '"Hello, #{name}"' + "\n  " \
                                                                                            "end" + "\n" \
                                                                                                    "end"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def greet(name)")
        expect(result).not_to include(": String")
      end

      it "preserves whitespace in function bodies" do
        source = "def greet(name: String)\n  puts name\n\n  puts 'done'\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def greet(name)")
        expect(result).to include("\n  puts name\n\n  puts 'done'\n")
      end
    end

    context "edge cases" do
      it "handles parameter without type followed by one with type" do
        source = "def process(value, name: String)\n  value + name\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def process(value, name)")
      end

      it "handles type with spaces" do
        source = "def test(x: String , y: Integer )\n  x\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        # After type removal, spaces remain but types are gone
        expect(result).to include("def test(x , y )")
        expect(result).not_to include(": String")
        expect(result).not_to include(": Integer")
      end

      it "preserves existing Ruby code without types" do
        source = "puts 'hello'\narray = [1, 2, 3]\nhash = { key: 'value' }"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to eq(source)
      end
    end

    context "multiple functions" do
      it "erases types in all functions" do
        source = <<~RUBY
          def add(a: Integer, b: Integer): Integer
            a + b
          end

          def concat(s1: String, s2: String): String
            s1 + s2
          end
        RUBY
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def add(a, b)")
        expect(result).to include("def concat(s1, s2)")
        expect(result).not_to include(": Integer")
        expect(result).not_to include(": String")
      end
    end
  end
end
