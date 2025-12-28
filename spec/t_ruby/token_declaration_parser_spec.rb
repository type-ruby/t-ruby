# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::ParserCombinator::TokenDeclarationParser do
  include TRuby::ParserCombinator::TokenDSL

  let(:parser) { described_class.new }
  let(:scanner) { TRuby::Scanner.new(source) }
  let(:tokens) { scanner.scan_all }

  describe "method definitions" do
    describe "simple method" do
      let(:source) do
        <<~RUBY
          def foo
            bar
          end
        RUBY
      end

      it "parses simple method definition" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::MethodDef)
        expect(result.value.name).to eq("foo")
        expect(result.value.params).to be_empty
        expect(result.value.body).to be_a(TRuby::IR::Block)
      end
    end

    describe "method with parameters" do
      let(:source) do
        <<~RUBY
          def greet(name)
            name
          end
        RUBY
      end

      it "parses method with untyped parameters" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.name).to eq("greet")
        expect(result.value.params.length).to eq(1)
        expect(result.value.params[0].name).to eq("name")
      end
    end

    describe "method with typed parameters" do
      let(:source) do
        <<~RUBY
          def greet(name: String)
            name
          end
        RUBY
      end

      it "parses method with typed parameters" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.params[0].type_annotation).not_to be_nil
        expect(result.value.params[0].type_annotation).to be_a(TRuby::IR::SimpleType)
      end
    end

    describe "method with return type" do
      let(:source) do
        <<~RUBY
          def greet(name: String): String
            name
          end
        RUBY
      end

      it "parses method with return type annotation" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.return_type).not_to be_nil
        expect(result.value.return_type).to be_a(TRuby::IR::SimpleType)
        expect(result.value.return_type.name).to eq("String")
      end
    end

    describe "method with visibility" do
      let(:source) do
        <<~RUBY
          private def secret
            42
          end
        RUBY
      end

      it "parses method with visibility modifier" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::MethodDef)
        expect(result.value.name).to eq("secret")
        expect(result.value.visibility).to eq(:private)
      end
    end

    describe "method with special names" do
      it "parses method with ? suffix" do
        scanner = TRuby::Scanner.new("def valid?\n  true\nend")
        result = parser.parse_declaration(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.name).to eq("valid?")
      end

      it "parses method with ! suffix" do
        scanner = TRuby::Scanner.new("def save!\n  true\nend")
        result = parser.parse_declaration(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value.name).to eq("save!")
      end
    end
  end

  describe "class definitions" do
    describe "simple class" do
      let(:source) do
        <<~RUBY
          class User
          end
        RUBY
      end

      it "parses simple class definition" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::ClassDecl)
        expect(result.value.name).to eq("User")
      end
    end

    describe "class with superclass" do
      let(:source) do
        <<~RUBY
          class Admin < User
          end
        RUBY
      end

      it "parses class with inheritance" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.superclass).to eq("User")
      end
    end

    describe "class with methods" do
      let(:source) do
        <<~RUBY
          class User
            def initialize(name: String)
              @name = name
            end

            def greet: String
              @name
            end
          end
        RUBY
      end

      it "parses class with method definitions" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.body.length).to eq(2)
        expect(result.value.body[0]).to be_a(TRuby::IR::MethodDef)
        expect(result.value.body[1]).to be_a(TRuby::IR::MethodDef)
      end
    end

    describe "class with instance variables" do
      let(:source) do
        <<~RUBY
          class User
            @name: String
            @age: Integer
          end
        RUBY
      end

      it "parses class with typed instance variables" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.instance_vars.length).to eq(2)
        expect(result.value.instance_vars[0].name).to eq("name")
        expect(result.value.instance_vars[1].name).to eq("age")
      end
    end
  end

  describe "module definitions" do
    describe "simple module" do
      let(:source) do
        <<~RUBY
          module Greeting
          end
        RUBY
      end

      it "parses module definition" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::ModuleDecl)
        expect(result.value.name).to eq("Greeting")
      end
    end

    describe "module with methods" do
      let(:source) do
        <<~RUBY
          module Greeting
            def greet: String
              "Hello"
            end
          end
        RUBY
      end

      it "parses module with methods" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.body.length).to eq(1)
      end
    end
  end

  describe "type alias" do
    let(:source) { "type UserId = Integer" }

    it "parses type alias" do
      result = parser.parse_declaration(tokens, 0)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::TypeAlias)
      expect(result.value.name).to eq("UserId")
      expect(result.value.definition).to be_a(TRuby::IR::SimpleType)
    end
  end

  describe "interface" do
    describe "simple interface" do
      let(:source) do
        <<~RUBY
          interface Printable
            print: -> void
          end
        RUBY
      end

      it "parses interface definition" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::Interface)
        expect(result.value.name).to eq("Printable")
        expect(result.value.members.length).to eq(1)
      end
    end

    describe "interface with multiple members" do
      let(:source) do
        <<~RUBY
          interface Comparable
            compare: (Self) -> Integer
            equal: (Self) -> Boolean
          end
        RUBY
      end

      it "parses interface with multiple members" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.members.length).to eq(2)
      end
    end
  end

  describe "program parsing" do
    let(:source) do
      <<~RUBY
        type UserId = Integer

        class User
          @id: UserId
          @name: String

          def initialize(id: UserId, name: String)
            @id = id
            @name = name
          end

          def greet: String
            @name
          end
        end
      RUBY
    end

    it "parses a complete program" do
      result = parser.parse_program(tokens)

      expect(result.success?).to be true
      expect(result.value).to be_a(TRuby::IR::Program)
      expect(result.value.declarations.length).to eq(2)
      expect(result.value.declarations[0]).to be_a(TRuby::IR::TypeAlias)
      expect(result.value.declarations[1]).to be_a(TRuby::IR::ClassDecl)
    end
  end
end
