# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::WASMGenerator do
  let(:generator) { described_class.new }

  describe "#generate" do
    it "generates valid WAT module structure" do
      program = TRuby::IR::Program.new(declarations: [])
      result = generator.generate(program)

      expect(result[:wat]).to include("(module")
      expect(result[:wat]).to include("(memory")
      expect(result[:errors]).to be_empty
    end

    it "exports functions by default" do
      method = TRuby::IR::MethodDef.new(
        name: "add",
        params: [
          TRuby::IR::Parameter.new(
            name: "a",
            type_annotation: TRuby::IR::SimpleType.new(name: "Integer")
          ),
          TRuby::IR::Parameter.new(
            name: "b",
            type_annotation: TRuby::IR::SimpleType.new(name: "Integer")
          )
        ],
        return_type: TRuby::IR::SimpleType.new(name: "Integer")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include('(export "add")')
      expect(result[:wat]).to include("(param $a i64)")
      expect(result[:wat]).to include("(param $b i64)")
      expect(result[:wat]).to include("(result i64)")
    end

    it "includes runtime functions when enabled" do
      generator_with_runtime = described_class.new(include_runtime: true)
      program = TRuby::IR::Program.new(declarations: [])

      result = generator_with_runtime.generate(program)

      expect(result[:wat]).to include("T-Ruby WASM Runtime")
      expect(result[:wat]).to include("$abs")
      expect(result[:wat]).to include("$min")
      expect(result[:wat]).to include("$max")
    end

    it "can disable runtime functions" do
      generator_no_runtime = described_class.new(include_runtime: false)
      program = TRuby::IR::Program.new(declarations: [])

      result = generator_no_runtime.generate(program)

      expect(result[:wat]).not_to include("T-Ruby WASM Runtime")
    end
  end

  describe "type conversion" do
    it "converts Integer to i64" do
      method = TRuby::IR::MethodDef.new(
        name: "test",
        params: [
          TRuby::IR::Parameter.new(
            name: "x",
            type_annotation: TRuby::IR::SimpleType.new(name: "Integer")
          )
        ],
        return_type: TRuby::IR::SimpleType.new(name: "Integer")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("i64")
    end

    it "converts Float to f64" do
      method = TRuby::IR::MethodDef.new(
        name: "test",
        params: [
          TRuby::IR::Parameter.new(
            name: "x",
            type_annotation: TRuby::IR::SimpleType.new(name: "Float")
          )
        ],
        return_type: TRuby::IR::SimpleType.new(name: "Float")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("f64")
    end

    it "converts Boolean to i32" do
      method = TRuby::IR::MethodDef.new(
        name: "test",
        params: [
          TRuby::IR::Parameter.new(
            name: "x",
            type_annotation: TRuby::IR::SimpleType.new(name: "Boolean")
          )
        ],
        return_type: TRuby::IR::SimpleType.new(name: "Boolean")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("i32")
    end
  end

  describe "literals" do
    it "generates integer constants" do
      literal = TRuby::IR::Literal.new(value: 42, literal_type: :integer)
      ret = TRuby::IR::Return.new(value: literal)
      block = TRuby::IR::Block.new(statements: [ret])
      method = TRuby::IR::MethodDef.new(
        name: "test",
        body: block,
        return_type: TRuby::IR::SimpleType.new(name: "Integer")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("i64.const 42")
    end

    it "generates float constants" do
      literal = TRuby::IR::Literal.new(value: 3.14, literal_type: :float)
      ret = TRuby::IR::Return.new(value: literal)
      block = TRuby::IR::Block.new(statements: [ret])
      method = TRuby::IR::MethodDef.new(
        name: "test",
        body: block,
        return_type: TRuby::IR::SimpleType.new(name: "Float")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("f64.const 3.14")
    end

    it "generates boolean constants" do
      true_literal = TRuby::IR::Literal.new(value: true, literal_type: :boolean)
      ret = TRuby::IR::Return.new(value: true_literal)
      block = TRuby::IR::Block.new(statements: [ret])
      method = TRuby::IR::MethodDef.new(
        name: "test",
        body: block,
        return_type: TRuby::IR::SimpleType.new(name: "Boolean")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("i32.const 1")
    end
  end

  describe "binary operations" do
    it "generates addition" do
      left = TRuby::IR::Literal.new(value: 1, literal_type: :integer)
      right = TRuby::IR::Literal.new(value: 2, literal_type: :integer)
      expr = TRuby::IR::BinaryOp.new(operator: "+", left: left, right: right)
      ret = TRuby::IR::Return.new(value: expr)
      block = TRuby::IR::Block.new(statements: [ret])
      method = TRuby::IR::MethodDef.new(
        name: "test",
        body: block,
        return_type: TRuby::IR::SimpleType.new(name: "Integer")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("i64.add")
    end

    it "generates subtraction" do
      left = TRuby::IR::Literal.new(value: 5, literal_type: :integer)
      right = TRuby::IR::Literal.new(value: 3, literal_type: :integer)
      expr = TRuby::IR::BinaryOp.new(operator: "-", left: left, right: right)
      ret = TRuby::IR::Return.new(value: expr)
      block = TRuby::IR::Block.new(statements: [ret])
      method = TRuby::IR::MethodDef.new(
        name: "test",
        body: block,
        return_type: TRuby::IR::SimpleType.new(name: "Integer")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("i64.sub")
    end

    it "generates multiplication" do
      left = TRuby::IR::Literal.new(value: 4, literal_type: :integer)
      right = TRuby::IR::Literal.new(value: 5, literal_type: :integer)
      expr = TRuby::IR::BinaryOp.new(operator: "*", left: left, right: right)
      ret = TRuby::IR::Return.new(value: expr)
      block = TRuby::IR::Block.new(statements: [ret])
      method = TRuby::IR::MethodDef.new(
        name: "test",
        body: block,
        return_type: TRuby::IR::SimpleType.new(name: "Integer")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("i64.mul")
    end

    it "generates comparison operations" do
      left = TRuby::IR::Literal.new(value: 1, literal_type: :integer)
      right = TRuby::IR::Literal.new(value: 2, literal_type: :integer)
      expr = TRuby::IR::BinaryOp.new(operator: "<", left: left, right: right)
      ret = TRuby::IR::Return.new(value: expr)
      block = TRuby::IR::Block.new(statements: [ret])
      method = TRuby::IR::MethodDef.new(
        name: "test",
        body: block,
        return_type: TRuby::IR::SimpleType.new(name: "Boolean")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("i64.lt_s")
    end
  end

  describe "control flow" do
    it "generates if/else blocks" do
      condition = TRuby::IR::Literal.new(value: true, literal_type: :boolean)
      then_lit = TRuby::IR::Literal.new(value: 1, literal_type: :integer)
      else_lit = TRuby::IR::Literal.new(value: 0, literal_type: :integer)
      then_ret = TRuby::IR::Return.new(value: then_lit)
      else_ret = TRuby::IR::Return.new(value: else_lit)
      then_block = TRuby::IR::Block.new(statements: [then_ret])
      else_block = TRuby::IR::Block.new(statements: [else_ret])

      conditional = TRuby::IR::Conditional.new(
        condition: condition,
        then_branch: then_block,
        else_branch: else_block
      )

      method = TRuby::IR::MethodDef.new(
        name: "test",
        body: TRuby::IR::Block.new(statements: [conditional]),
        return_type: TRuby::IR::SimpleType.new(name: "Integer")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("(if")
      expect(result[:wat]).to include("(then")
      expect(result[:wat]).to include("(else")
    end

    it "generates while loops" do
      condition = TRuby::IR::Literal.new(value: true, literal_type: :boolean)
      body = TRuby::IR::Block.new(statements: [])
      loop_node = TRuby::IR::Loop.new(kind: :while, condition: condition, body: body)

      method = TRuby::IR::MethodDef.new(
        name: "test",
        body: TRuby::IR::Block.new(statements: [loop_node])
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("(block $break")
      expect(result[:wat]).to include("(loop $continue")
      expect(result[:wat]).to include("br_if $break")
      expect(result[:wat]).to include("br $continue")
    end
  end

  describe "function calls" do
    it "generates function calls" do
      # Define a function first
      add_method = TRuby::IR::MethodDef.new(
        name: "add",
        params: [
          TRuby::IR::Parameter.new(name: "a", type_annotation: TRuby::IR::SimpleType.new(name: "Integer")),
          TRuby::IR::Parameter.new(name: "b", type_annotation: TRuby::IR::SimpleType.new(name: "Integer"))
        ],
        return_type: TRuby::IR::SimpleType.new(name: "Integer")
      )

      # Call the function
      call = TRuby::IR::MethodCall.new(
        method_name: "add",
        arguments: [
          TRuby::IR::Literal.new(value: 1, literal_type: :integer),
          TRuby::IR::Literal.new(value: 2, literal_type: :integer)
        ]
      )
      ret = TRuby::IR::Return.new(value: call)
      block = TRuby::IR::Block.new(statements: [ret])
      test_method = TRuby::IR::MethodDef.new(
        name: "test",
        body: block,
        return_type: TRuby::IR::SimpleType.new(name: "Integer")
      )

      program = TRuby::IR::Program.new(declarations: [add_method, test_method])

      result = generator.generate(program)

      expect(result[:wat]).to include("call $add")
    end
  end

  describe "unary operations" do
    it "generates negation" do
      operand = TRuby::IR::Literal.new(value: 5, literal_type: :integer)
      expr = TRuby::IR::UnaryOp.new(operator: "-", operand: operand)
      ret = TRuby::IR::Return.new(value: expr)
      block = TRuby::IR::Block.new(statements: [ret])
      method = TRuby::IR::MethodDef.new(
        name: "test",
        body: block,
        return_type: TRuby::IR::SimpleType.new(name: "Integer")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("i64.const 0")
      expect(result[:wat]).to include("i64.sub")
    end

    it "generates logical not" do
      operand = TRuby::IR::Literal.new(value: true, literal_type: :boolean)
      expr = TRuby::IR::UnaryOp.new(operator: "!", operand: operand)
      ret = TRuby::IR::Return.new(value: expr)
      block = TRuby::IR::Block.new(statements: [ret])
      method = TRuby::IR::MethodDef.new(
        name: "test",
        body: block,
        return_type: TRuby::IR::SimpleType.new(name: "Boolean")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("i32.eqz")
    end
  end

  describe "string handling" do
    it "stores strings in memory and returns pointer" do
      literal = TRuby::IR::Literal.new(value: "hello", literal_type: :string)
      ret = TRuby::IR::Return.new(value: literal)
      block = TRuby::IR::Block.new(statements: [ret])
      method = TRuby::IR::MethodDef.new(
        name: "test",
        body: block,
        return_type: TRuby::IR::SimpleType.new(name: "String")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("i32.const")  # pointer to string
      expect(result[:wat]).to include("(data")      # data section
      expect(result[:string_table]).not_to be_empty
    end
  end

  describe "variable assignment" do
    it "generates local variable assignment" do
      value = TRuby::IR::Literal.new(value: 42, literal_type: :integer)
      assignment = TRuby::IR::Assignment.new(target: "x", value: value)
      ret = TRuby::IR::Return.new(value: TRuby::IR::VariableRef.new(name: "x"))
      block = TRuby::IR::Block.new(statements: [assignment, ret])
      method = TRuby::IR::MethodDef.new(
        name: "test",
        body: block,
        return_type: TRuby::IR::SimpleType.new(name: "Integer")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = generator.generate(program)

      expect(result[:wat]).to include("local.set $x")
      expect(result[:wat]).to include("local.get $x")
    end
  end

  describe TRuby::WASMResult do
    it "indicates success when no errors" do
      result = described_class.new(
        wat: "(module)",
        errors: [],
        warnings: []
      )

      expect(result.success?).to be true
    end

    it "indicates failure when errors exist" do
      result = described_class.new(
        wat: "(module)",
        errors: ["Some error"],
        warnings: []
      )

      expect(result.success?).to be false
    end

    it "lists exported functions" do
      result = described_class.new(
        wat: "(module)",
        errors: [],
        warnings: [],
        functions: { "add" => { params: [], return_type: "i64" } }
      )

      expect(result.exported_functions).to eq(["add"])
    end
  end
end
