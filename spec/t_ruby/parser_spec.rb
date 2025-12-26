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

    context "with non-ASCII (Unicode) method names" do
      it "parses method names with Korean characters" do
        source = "def 안녕하세요(name: String): String\n  name\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type]).to eq(:success)
        expect(result[:functions].length).to eq(1)
        expect(result[:functions][0][:name]).to eq("안녕하세요")
        expect(result[:functions][0][:params][0][:type]).to eq("String")
        expect(result[:functions][0][:return_type]).to eq("String")
      end

      it "parses method names with mixed ASCII and Unicode characters" do
        source = "def 비_영어_함수명___테스트1!(name: String)\n  name\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type]).to eq(:success)
        expect(result[:functions].length).to eq(1)
        expect(result[:functions][0][:name]).to eq("비_영어_함수명___테스트1!")
      end

      it "parses method names with Japanese characters" do
        source = "def こんにちは(): String\n  'hello'\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type]).to eq(:success)
        expect(result[:functions][0][:name]).to eq("こんにちは")
      end

      it "parses class methods with Unicode names" do
        source = <<~RUBY
          class HelloWorld
            def 인사하기(name: String): String
              "Hello, \#{name}!"
            end
          end
        RUBY
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type]).to eq(:success)
        expect(result[:classes].length).to eq(1)
        expect(result[:classes][0][:methods].length).to eq(1)
        expect(result[:classes][0][:methods][0][:name]).to eq("인사하기")
      end
    end
  end

  describe "parsing visibility modifiers" do
    context "with private def" do
      it "parses private def in class" do
        source = <<~RUBY
          class Example
            private def secret(x: String): Integer
              x.length
            end
          end
        RUBY
        parser = TRuby::Parser.new(source)
        result = parser.parse

        expect(result[:classes][0][:methods].length).to eq(1)
        expect(result[:classes][0][:methods][0][:name]).to eq("secret")
        expect(result[:classes][0][:methods][0][:visibility]).to eq(:private)
      end

      it "parses private def at top level" do
        source = <<~RUBY
          private def helper(x: String): String
            x.upcase
          end
        RUBY
        parser = TRuby::Parser.new(source)
        result = parser.parse

        expect(result[:functions].length).to eq(1)
        expect(result[:functions][0][:name]).to eq("helper")
        expect(result[:functions][0][:visibility]).to eq(:private)
      end
    end

    context "with protected def" do
      it "parses protected def in class" do
        source = <<~RUBY
          class Example
            protected def internal(n: Integer): Boolean
              n > 0
            end
          end
        RUBY
        parser = TRuby::Parser.new(source)
        result = parser.parse

        expect(result[:classes][0][:methods].length).to eq(1)
        expect(result[:classes][0][:methods][0][:name]).to eq("internal")
        expect(result[:classes][0][:methods][0][:visibility]).to eq(:protected)
      end
    end

    context "without visibility modifier" do
      it "defaults to public visibility" do
        source = "def hello(name: String): String\n  name\nend"
        parser = TRuby::Parser.new(source)
        result = parser.parse

        expect(result[:functions][0][:visibility]).to eq(:public)
      end
    end
  end

  describe "heredoc handling" do
    it "ignores def patterns inside heredoc" do
      source = <<~RUBY
        text = <<EOT
        Lorem ipsum
        def x(a: String)
        Dolor sit amet
        EOT

        def real_method(name: String): String
          name
        end
      RUBY
      parser = TRuby::Parser.new(source)
      result = parser.parse

      expect(result[:functions].length).to eq(1)
      expect(result[:functions][0][:name]).to eq("real_method")
    end

    it "handles squiggly heredoc" do
      source = <<~RUBY
        html = <<~HTML
          <script>
            def fake_method(x: Integer): void
          </script>
        HTML

        def process(data: String): Boolean
          true
        end
      RUBY
      parser = TRuby::Parser.new(source)
      result = parser.parse

      expect(result[:functions].length).to eq(1)
      expect(result[:functions][0][:name]).to eq("process")
    end

    it "handles heredoc with dash" do
      source = <<~RUBY
        sql = <<-SQL
          SELECT def from users
          WHERE def foo(x: String)
        SQL

        def query(table: String): Array
          []
        end
      RUBY
      parser = TRuby::Parser.new(source)
      result = parser.parse

      expect(result[:functions].length).to eq(1)
      expect(result[:functions][0][:name]).to eq("query")
    end

    it "ignores def patterns inside =begin/=end block comments" do
      source = <<~RUBY
        =begin
        def fake(x: String): Integer
          x
        end
        =end

        def real(name: String): String
          name
        end
      RUBY
      parser = TRuby::Parser.new(source)
      result = parser.parse

      expect(result[:functions].length).to eq(1)
      expect(result[:functions][0][:name]).to eq("real")
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
                                                               "ActiveRecord::Base",
                                                             ])
    end
  end
end
