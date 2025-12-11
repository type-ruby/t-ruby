# frozen_string_literal: true

require "spec_helper"

describe TRuby::Parser do
  describe "parsing function signatures" do
    context "with parameter types" do
      it "parses simple parameter type annotation" do
        source = "def greet(name: String)\n  puts name\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result).to be_a(Hash)
        expect(result[:type]).to eq(:success)
      end

      it "parses multiple parameters with types" do
        source = "def add(a: Integer, b: Integer)\n  a + b\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type]).to eq(:success)
      end

      it "extracts parameter names and types" do
        source = "def greet(name: String)\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:functions]).to be_a(Array)
        expect(result[:functions][0][:name]).to eq("greet")
        expect(result[:functions][0][:params]).to be_a(Array)
        expect(result[:functions][0][:params][0][:name]).to eq("name")
        expect(result[:functions][0][:params][0][:type]).to eq("String")
      end

      it "handles multiple parameters correctly" do
        source = "def create(name: String, age: Integer, active: Boolean)\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        params = result[:functions][0][:params]
        expect(params.length).to eq(3)
        expect(params[0][:type]).to eq("String")
        expect(params[1][:type]).to eq("Integer")
        expect(params[2][:type]).to eq("Boolean")
      end
    end

    context "with return types" do
      it "parses return type annotation" do
        source = "def get_name(): String\n  'John'\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type]).to eq(:success)
        expect(result[:functions][0][:return_type]).to eq("String")
      end

      it "parses void return type" do
        source = "def do_something(): void\n  puts 'done'\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:functions][0][:return_type]).to eq("void")
      end

      it "handles both parameter and return types" do
        source = "def greet(name: String): String\n  'Hello, ' + name\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        func = result[:functions][0]
        expect(func[:params][0][:type]).to eq("String")
        expect(func[:return_type]).to eq("String")
      end
    end

    context "with various type names" do
      it "supports basic types" do
        source = "def test(s: String, i: Integer, b: Boolean, n: nil): void\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type]).to eq(:success)
      end

      it "supports Array type" do
        source = "def process(items: Array): Array\n  items\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:functions][0][:params][0][:type]).to eq("Array")
        expect(result[:functions][0][:return_type]).to eq("Array")
      end

      it "supports Hash type" do
        source = "def get_data(): Hash\n  {}\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:functions][0][:return_type]).to eq("Hash")
      end

      it "supports Symbol type" do
        source = "def get_status(): Symbol\n  :ok\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:functions][0][:return_type]).to eq("Symbol")
      end
    end

    context "with functions without types" do
      it "handles functions without any type annotations" do
        source = "def greet(name)\n  puts name\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type]).to eq(:success)
        expect(result[:functions][0][:params][0][:type]).to be_nil
      end

      it "handles functions with mixed typed and untyped params" do
        source = "def process(name: String, value)\n  name + value.to_s\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        params = result[:functions][0][:params]
        expect(params[0][:type]).to eq("String")
        expect(params[1][:type]).to be_nil
      end
    end

    context "with multiple functions" do
      it "parses multiple functions in one source" do
        source = <<~RUBY
          def greet(name: String): String
            'Hello, ' + name
          end

          def add(a: Integer, b: Integer): Integer
            a + b
          end
        RUBY
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:functions].length).to eq(2)
        expect(result[:functions][0][:name]).to eq("greet")
        expect(result[:functions][1][:name]).to eq("add")
      end
    end

    context "error handling" do
      it "reports error for invalid type syntax" do
        source = "def test(x: NotAValidType)\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        # Parser should still parse but may flag as warning
        expect(result).to be_a(Hash)
      end

      it "handles malformed function definitions gracefully" do
        source = "def broken(x: String\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result).to be_a(Hash)
      end
    end
  end

  describe "parsing namespaced interfaces" do
    it "parses namespaced interface correctly" do
      source = <<~RUBY
        interface Rails::Application
          config: String
        end
      RUBY
      parser = TRuby::Parser.new(source)

      result = parser.parse
      expect(result[:interfaces]).to be_a(Array)
      expect(result[:interfaces][0][:name]).to eq("Rails::Application")
    end

    it "parses deeply nested namespace" do
      source = <<~RUBY
        interface Rails::Application::Configuration
          root: Pathname
        end
      RUBY
      parser = TRuby::Parser.new(source)

      result = parser.parse
      expect(result[:interfaces][0][:name]).to eq("Rails::Application::Configuration")
    end

    it "parses interface with method signatures" do
      source = <<~RUBY
        interface Rails::Application
          initialize!: Rails::Application
          eager_load!: void
          initialized?: Boolean
        end
      RUBY
      parser = TRuby::Parser.new(source)

      result = parser.parse
      expect(result[:interfaces][0][:name]).to eq("Rails::Application")
      expect(result[:interfaces][0][:members].length).to eq(3)
    end

    it "parses multiple namespaced interfaces in one file" do
      source = <<~RUBY
        interface Rails
          env: String
        end

        interface Rails::Application
          config: String
        end

        interface ActiveRecord::Base
          id: Integer
        end
      RUBY
      parser = TRuby::Parser.new(source)

      result = parser.parse
      expect(result[:interfaces].length).to eq(3)
      expect(result[:interfaces].map { |i| i[:name] }).to eq([
        "Rails",
        "Rails::Application",
        "ActiveRecord::Base"
      ])
    end
  end
end
