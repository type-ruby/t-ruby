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

  describe "array shorthand syntax" do
    describe "basic array shorthand" do
      it "parses String[] as Array<String>" do
        scanner = TRuby::Scanner.new("def foo(names: String[])\nend")
        result = parser.parse_declaration(scanner.scan_all, 0)

        expect(result.success?).to be true
        param_type = result.value.params[0].type_annotation
        expect(param_type).to be_a(TRuby::IR::GenericType)
        expect(param_type.base).to eq("Array")
        expect(param_type.type_args.length).to eq(1)
        expect(param_type.type_args[0]).to be_a(TRuby::IR::SimpleType)
        expect(param_type.type_args[0].name).to eq("String")
      end

      it "parses Integer[] as Array<Integer>" do
        scanner = TRuby::Scanner.new("def foo(nums: Integer[])\nend")
        result = parser.parse_declaration(scanner.scan_all, 0)

        expect(result.success?).to be true
        param_type = result.value.params[0].type_annotation
        expect(param_type).to be_a(TRuby::IR::GenericType)
        expect(param_type.base).to eq("Array")
        expect(param_type.type_args[0].name).to eq("Integer")
      end

      it "parses array shorthand in return type" do
        scanner = TRuby::Scanner.new("def foo(): String[]\nend")
        result = parser.parse_declaration(scanner.scan_all, 0)

        expect(result.success?).to be true
        return_type = result.value.return_type
        expect(return_type).to be_a(TRuby::IR::GenericType)
        expect(return_type.base).to eq("Array")
        expect(return_type.type_args[0].name).to eq("String")
      end
    end

    describe "nested array shorthand" do
      it "parses Integer[][] as Array<Array<Integer>>" do
        scanner = TRuby::Scanner.new("def foo(matrix: Integer[][])\nend")
        result = parser.parse_declaration(scanner.scan_all, 0)

        expect(result.success?).to be true
        param_type = result.value.params[0].type_annotation
        expect(param_type).to be_a(TRuby::IR::GenericType)
        expect(param_type.base).to eq("Array")

        inner_type = param_type.type_args[0]
        expect(inner_type).to be_a(TRuby::IR::GenericType)
        expect(inner_type.base).to eq("Array")
        expect(inner_type.type_args[0].name).to eq("Integer")
      end

      it "parses String[][][] as triple-nested array" do
        scanner = TRuby::Scanner.new("def foo(cube: String[][][])\nend")
        result = parser.parse_declaration(scanner.scan_all, 0)

        expect(result.success?).to be true
        param_type = result.value.params[0].type_annotation

        # String[][][] = Array<Array<Array<String>>>
        expect(param_type).to be_a(TRuby::IR::GenericType)
        expect(param_type.base).to eq("Array")

        level2 = param_type.type_args[0]
        expect(level2).to be_a(TRuby::IR::GenericType)
        expect(level2.base).to eq("Array")

        level3 = level2.type_args[0]
        expect(level3).to be_a(TRuby::IR::GenericType)
        expect(level3.base).to eq("Array")
        expect(level3.type_args[0].name).to eq("String")
      end
    end

    describe "nullable array shorthand" do
      it "parses String[]? as nullable array (array itself can be nil)" do
        scanner = TRuby::Scanner.new("def foo(names: String[]?)\nend")
        result = parser.parse_declaration(scanner.scan_all, 0)

        expect(result.success?).to be true
        param_type = result.value.params[0].type_annotation

        # String[]? = NullableType(GenericType(Array, [String]))
        expect(param_type).to be_a(TRuby::IR::NullableType)
        inner = param_type.inner_type
        expect(inner).to be_a(TRuby::IR::GenericType)
        expect(inner.base).to eq("Array")
        expect(inner.type_args[0].name).to eq("String")
      end

      it "parses String?[] as array of nullable elements" do
        scanner = TRuby::Scanner.new("def foo(names: String?[])\nend")
        result = parser.parse_declaration(scanner.scan_all, 0)

        expect(result.success?).to be true
        param_type = result.value.params[0].type_annotation

        # String?[] = GenericType(Array, [NullableType(String)])
        expect(param_type).to be_a(TRuby::IR::GenericType)
        expect(param_type.base).to eq("Array")
        inner = param_type.type_args[0]
        expect(inner).to be_a(TRuby::IR::NullableType)
        expect(inner.inner_type.name).to eq("String")
      end

      it "parses Integer?[]? as nullable array of nullable elements" do
        scanner = TRuby::Scanner.new("def foo(nums: Integer?[]?)\nend")
        result = parser.parse_declaration(scanner.scan_all, 0)

        expect(result.success?).to be true
        param_type = result.value.params[0].type_annotation

        # Integer?[]? = NullableType(GenericType(Array, [NullableType(Integer)]))
        expect(param_type).to be_a(TRuby::IR::NullableType)
        array_type = param_type.inner_type
        expect(array_type).to be_a(TRuby::IR::GenericType)
        expect(array_type.base).to eq("Array")
        element_type = array_type.type_args[0]
        expect(element_type).to be_a(TRuby::IR::NullableType)
        expect(element_type.inner_type.name).to eq("Integer")
      end
    end

    describe "union type array shorthand" do
      it "parses (String | Integer)[] as array of union type" do
        scanner = TRuby::Scanner.new("def foo(values: (String | Integer)[])\nend")
        result = parser.parse_declaration(scanner.scan_all, 0)

        expect(result.success?).to be true
        param_type = result.value.params[0].type_annotation

        # (String | Integer)[] = GenericType(Array, [UnionType([String, Integer])])
        expect(param_type).to be_a(TRuby::IR::GenericType)
        expect(param_type.base).to eq("Array")
        union_type = param_type.type_args[0]
        expect(union_type).to be_a(TRuby::IR::UnionType)
        expect(union_type.types.length).to eq(2)
        expect(union_type.types[0].name).to eq("String")
        expect(union_type.types[1].name).to eq("Integer")
      end

      it "parses (String | Integer | nil)[] as array of nullable union type" do
        scanner = TRuby::Scanner.new("def foo(values: (String | Integer | nil)[])\nend")
        result = parser.parse_declaration(scanner.scan_all, 0)

        expect(result.success?).to be true
        param_type = result.value.params[0].type_annotation

        expect(param_type).to be_a(TRuby::IR::GenericType)
        expect(param_type.base).to eq("Array")
        union_type = param_type.type_args[0]
        expect(union_type).to be_a(TRuby::IR::UnionType)
        expect(union_type.types.length).to eq(3)
      end
    end

    describe "type alias with array shorthand" do
      it "parses type alias with array shorthand" do
        scanner = TRuby::Scanner.new("type StringList = String[]")
        result = parser.parse_declaration(scanner.scan_all, 0)

        expect(result.success?).to be true
        expect(result.value).to be_a(TRuby::IR::TypeAlias)
        expect(result.value.name).to eq("StringList")

        definition = result.value.definition
        expect(definition).to be_a(TRuby::IR::GenericType)
        expect(definition.base).to eq("Array")
        expect(definition.type_args[0].name).to eq("String")
      end

      it "parses type alias with nested array shorthand" do
        scanner = TRuby::Scanner.new("type IntMatrix = Integer[][]")
        result = parser.parse_declaration(scanner.scan_all, 0)

        expect(result.success?).to be true
        definition = result.value.definition
        expect(definition).to be_a(TRuby::IR::GenericType)
        expect(definition.base).to eq("Array")
        expect(definition.type_args[0]).to be_a(TRuby::IR::GenericType)
        expect(definition.type_args[0].base).to eq("Array")
      end
    end

    describe "class with array shorthand instance variables" do
      let(:source) do
        <<~RUBY
          class DataStore
            @items: String[]
            @matrix: Integer[][]
            @optional: Float[]?
          end
        RUBY
      end

      it "parses instance variables with array shorthand types" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.success?).to be true
        expect(result.value.instance_vars.length).to eq(3)

        items_type = result.value.instance_vars[0].type_annotation
        expect(items_type).to be_a(TRuby::IR::GenericType)
        expect(items_type.base).to eq("Array")

        matrix_type = result.value.instance_vars[1].type_annotation
        expect(matrix_type).to be_a(TRuby::IR::GenericType)
        expect(matrix_type.type_args[0]).to be_a(TRuby::IR::GenericType)

        optional_type = result.value.instance_vars[2].type_annotation
        expect(optional_type).to be_a(TRuby::IR::NullableType)
        expect(optional_type.inner_type).to be_a(TRuby::IR::GenericType)
      end
    end

    describe "equivalence with Array<T> syntax" do
      it "String[] and Array<String> produce equivalent IR" do
        scanner1 = TRuby::Scanner.new("def foo(a: String[])\nend")
        scanner2 = TRuby::Scanner.new("def foo(a: Array<String>)\nend")

        result1 = parser.parse_declaration(scanner1.scan_all, 0)
        result2 = parser.parse_declaration(scanner2.scan_all, 0)

        expect(result1.success?).to be true
        expect(result2.success?).to be true

        type1 = result1.value.params[0].type_annotation
        type2 = result2.value.params[0].type_annotation

        expect(type1).to be_a(TRuby::IR::GenericType)
        expect(type2).to be_a(TRuby::IR::GenericType)
        expect(type1.base).to eq(type2.base)
        expect(type1.type_args[0].name).to eq(type2.type_args[0].name)
      end

      it "Integer[][] and Array<Array<Integer>> produce equivalent IR" do
        scanner1 = TRuby::Scanner.new("def foo(a: Integer[][])\nend")
        scanner2 = TRuby::Scanner.new("def foo(a: Array<Array<Integer>>)\nend")

        result1 = parser.parse_declaration(scanner1.scan_all, 0)
        result2 = parser.parse_declaration(scanner2.scan_all, 0)

        expect(result1.success?).to be true
        expect(result2.success?).to be true

        type1 = result1.value.params[0].type_annotation
        type2 = result2.value.params[0].type_annotation

        expect(type1.base).to eq(type2.base)
        expect(type1.type_args[0].base).to eq(type2.type_args[0].base)
        expect(type1.type_args[0].type_args[0].name).to eq(type2.type_args[0].type_args[0].name)
      end
    end
  end
end
