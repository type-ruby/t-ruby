# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::IR do
  describe TRuby::IR::Node do
    it "has location and metadata" do
      node = described_class.new(location: { line: 1, column: 0 })
      expect(node.location).to eq({ line: 1, column: 0 })
      expect(node.metadata).to eq({})
    end
  end

  describe TRuby::IR::Program do
    it "holds declarations" do
      alias_node = TRuby::IR::TypeAlias.new(
        name: "UserId",
        definition: TRuby::IR::SimpleType.new(name: "String")
      )
      program = described_class.new(declarations: [alias_node])

      expect(program.declarations.length).to eq(1)
      expect(program.children).to eq([alias_node])
    end
  end

  describe TRuby::IR::SimpleType do
    it "converts to RBS format" do
      type = described_class.new(name: "String")
      expect(type.to_rbs).to eq("String")
      expect(type.to_trb).to eq("String")
    end
  end

  describe TRuby::IR::GenericType do
    it "converts to RBS format" do
      inner = TRuby::IR::SimpleType.new(name: "String")
      type = described_class.new(base: "Array", type_args: [inner])

      expect(type.to_rbs).to eq("Array[String]")
      expect(type.to_trb).to eq("Array<String>")
    end

    it "handles multiple type arguments" do
      key = TRuby::IR::SimpleType.new(name: "String")
      value = TRuby::IR::SimpleType.new(name: "Integer")
      type = described_class.new(base: "Hash", type_args: [key, value])

      expect(type.to_rbs).to eq("Hash[String, Integer]")
      expect(type.to_trb).to eq("Hash<String, Integer>")
    end
  end

  describe TRuby::IR::UnionType do
    it "converts to RBS format" do
      string_type = TRuby::IR::SimpleType.new(name: "String")
      nil_type = TRuby::IR::SimpleType.new(name: "nil")
      type = described_class.new(types: [string_type, nil_type])

      expect(type.to_rbs).to eq("String | nil")
      expect(type.to_trb).to eq("String | nil")
    end
  end

  describe TRuby::IR::IntersectionType do
    it "converts to RBS format" do
      readable = TRuby::IR::SimpleType.new(name: "Readable")
      writable = TRuby::IR::SimpleType.new(name: "Writable")
      type = described_class.new(types: [readable, writable])

      expect(type.to_rbs).to eq("Readable & Writable")
      expect(type.to_trb).to eq("Readable & Writable")
    end
  end

  describe TRuby::IR::FunctionType do
    it "converts to RBS format" do
      param = TRuby::IR::SimpleType.new(name: "String")
      ret = TRuby::IR::SimpleType.new(name: "Integer")
      type = described_class.new(param_types: [param], return_type: ret)

      expect(type.to_rbs).to eq("^(String) -> Integer")
      expect(type.to_trb).to eq("(String) -> Integer")
    end
  end

  describe TRuby::IR::NullableType do
    it "converts to RBS format" do
      inner = TRuby::IR::SimpleType.new(name: "String")
      type = described_class.new(inner_type: inner)

      expect(type.to_rbs).to eq("String?")
      expect(type.to_trb).to eq("String?")
    end
  end

  describe TRuby::IR::TupleType do
    it "converts to RBS format" do
      string_type = TRuby::IR::SimpleType.new(name: "String")
      int_type = TRuby::IR::SimpleType.new(name: "Integer")
      type = described_class.new(element_types: [string_type, int_type])

      expect(type.to_rbs).to eq("[String, Integer]")
      expect(type.to_trb).to eq("[String, Integer]")
    end
  end

  describe TRuby::IR::Builder do
    let(:builder) { described_class.new }

    describe "#build" do
      it "builds program from parse result" do
        parse_result = {
          type: :success,
          type_aliases: [{ name: "UserId", definition: "String" }],
          interfaces: [],
          functions: []
        }

        program = builder.build(parse_result)

        expect(program).to be_a(TRuby::IR::Program)
        expect(program.declarations.length).to eq(1)
        expect(program.declarations.first).to be_a(TRuby::IR::TypeAlias)
      end

      it "builds type aliases with correct type" do
        parse_result = {
          type: :success,
          type_aliases: [{ name: "UserId", definition: "String" }],
          interfaces: [],
          functions: []
        }

        program = builder.build(parse_result)
        alias_node = program.declarations.first

        expect(alias_node.name).to eq("UserId")
        expect(alias_node.definition).to be_a(TRuby::IR::SimpleType)
        expect(alias_node.definition.name).to eq("String")
      end

      it "builds union types" do
        parse_result = {
          type: :success,
          type_aliases: [{ name: "StringOrNil", definition: "String | nil" }],
          interfaces: [],
          functions: []
        }

        program = builder.build(parse_result)
        alias_node = program.declarations.first

        expect(alias_node.definition).to be_a(TRuby::IR::UnionType)
        expect(alias_node.definition.types.length).to eq(2)
      end

      it "builds generic types" do
        parse_result = {
          type: :success,
          type_aliases: [{ name: "StringArray", definition: "Array<String>" }],
          interfaces: [],
          functions: []
        }

        program = builder.build(parse_result)
        alias_node = program.declarations.first

        expect(alias_node.definition).to be_a(TRuby::IR::GenericType)
        expect(alias_node.definition.base).to eq("Array")
        expect(alias_node.definition.type_args.length).to eq(1)
      end

      it "builds nested generic types" do
        parse_result = {
          type: :success,
          type_aliases: [{ name: "Matrix", definition: "Array<Array<Integer>>" }],
          interfaces: [],
          functions: []
        }

        program = builder.build(parse_result)
        alias_node = program.declarations.first

        expect(alias_node.definition).to be_a(TRuby::IR::GenericType)
        expect(alias_node.definition.type_args.first).to be_a(TRuby::IR::GenericType)
      end

      it "builds interfaces" do
        parse_result = {
          type: :success,
          type_aliases: [],
          interfaces: [{
            name: "Serializable",
            members: [
              { name: "to_json", type: "String" }
            ]
          }],
          functions: []
        }

        program = builder.build(parse_result)
        interface = program.declarations.first

        expect(interface).to be_a(TRuby::IR::Interface)
        expect(interface.name).to eq("Serializable")
        expect(interface.members.length).to eq(1)
        expect(interface.members.first.name).to eq("to_json")
      end

      it "builds methods with parameters" do
        parse_result = {
          type: :success,
          type_aliases: [],
          interfaces: [],
          functions: [{
            name: "greet",
            params: [
              { name: "name", type: "String" }
            ],
            return_type: "String"
          }]
        }

        program = builder.build(parse_result)
        method = program.declarations.first

        expect(method).to be_a(TRuby::IR::MethodDef)
        expect(method.name).to eq("greet")
        expect(method.params.length).to eq(1)
        expect(method.params.first.name).to eq("name")
        expect(method.return_type).to be_a(TRuby::IR::SimpleType)
      end

      it "builds function types" do
        parse_result = {
          type: :success,
          type_aliases: [{ name: "Callback", definition: "(String) -> Integer" }],
          interfaces: [],
          functions: []
        }

        program = builder.build(parse_result)
        alias_node = program.declarations.first

        expect(alias_node.definition).to be_a(TRuby::IR::FunctionType)
        expect(alias_node.definition.param_types.length).to eq(1)
        expect(alias_node.definition.return_type.name).to eq("Integer")
      end

      it "builds nullable types" do
        parse_result = {
          type: :success,
          type_aliases: [{ name: "MaybeString", definition: "String?" }],
          interfaces: [],
          functions: []
        }

        program = builder.build(parse_result)
        alias_node = program.declarations.first

        expect(alias_node.definition).to be_a(TRuby::IR::NullableType)
        expect(alias_node.definition.inner_type.name).to eq("String")
      end
    end

    describe "#build_from_source" do
      it "parses source and builds IR" do
        source = <<~TRB
          type UserId = String

          def greet(name: String): String
          end
        TRB

        program = builder.build_from_source(source)

        expect(program.declarations.length).to eq(2)
        expect(program.declarations[0]).to be_a(TRuby::IR::TypeAlias)
        expect(program.declarations[1]).to be_a(TRuby::IR::MethodDef)
      end
    end
  end

  describe TRuby::IR::CodeGenerator do
    let(:generator) { described_class.new }

    it "generates Ruby code from method definition" do
      method = TRuby::IR::MethodDef.new(
        name: "greet",
        params: [TRuby::IR::Parameter.new(name: "name")]
      )
      program = TRuby::IR::Program.new(declarations: [method])

      output = generator.generate(program)

      expect(output).to include("def greet(name)")
      expect(output).to include("end")
    end

    it "generates comments for type aliases" do
      type_alias = TRuby::IR::TypeAlias.new(
        name: "UserId",
        definition: TRuby::IR::SimpleType.new(name: "String")
      )
      program = TRuby::IR::Program.new(declarations: [type_alias])

      output = generator.generate(program)

      expect(output).to include("# type UserId = String")
    end
  end

  describe TRuby::IR::RBSGenerator do
    let(:generator) { described_class.new }

    it "generates RBS type alias" do
      type_alias = TRuby::IR::TypeAlias.new(
        name: "UserId",
        definition: TRuby::IR::SimpleType.new(name: "String")
      )
      program = TRuby::IR::Program.new(declarations: [type_alias])

      output = generator.generate(program)

      expect(output).to include("type UserId = String")
    end

    it "generates RBS interface" do
      interface = TRuby::IR::Interface.new(
        name: "Serializable",
        members: [
          TRuby::IR::InterfaceMember.new(
            name: "to_json",
            type_signature: TRuby::IR::SimpleType.new(name: "String")
          )
        ]
      )
      program = TRuby::IR::Program.new(declarations: [interface])

      output = generator.generate(program)

      expect(output).to include("interface _Serializable")
      expect(output).to include("def to_json: String")
      expect(output).to include("end")
    end

    it "generates RBS method signature" do
      method = TRuby::IR::MethodDef.new(
        name: "greet",
        params: [
          TRuby::IR::Parameter.new(
            name: "name",
            type_annotation: TRuby::IR::SimpleType.new(name: "String")
          )
        ],
        return_type: TRuby::IR::SimpleType.new(name: "String")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      output = generator.generate(program)

      expect(output).to include("def greet: (String name) -> String")
    end
  end

  describe TRuby::IR::Passes::DeadCodeElimination do
    let(:pass) { described_class.new }

    it "removes code after return statement" do
      statements = [
        TRuby::IR::Return.new(value: TRuby::IR::Literal.new(value: 1, literal_type: :integer)),
        TRuby::IR::Assignment.new(
          target: "x",
          value: TRuby::IR::Literal.new(value: 2, literal_type: :integer)
        )
      ]

      block = TRuby::IR::Block.new(statements: statements)
      method = TRuby::IR::MethodDef.new(name: "test", body: block)
      program = TRuby::IR::Program.new(declarations: [method])

      result = pass.run(program)

      expect(result[:changes]).to eq(1)
      expect(method.body.statements.length).to eq(1)
    end
  end

  describe TRuby::IR::Passes::ConstantFolding do
    let(:pass) { described_class.new }

    it "folds constant arithmetic expressions" do
      expr = TRuby::IR::BinaryOp.new(
        operator: "+",
        left: TRuby::IR::Literal.new(value: 2, literal_type: :integer),
        right: TRuby::IR::Literal.new(value: 3, literal_type: :integer)
      )

      ret = TRuby::IR::Return.new(value: expr)
      block = TRuby::IR::Block.new(statements: [ret])
      method = TRuby::IR::MethodDef.new(name: "test", body: block)
      program = TRuby::IR::Program.new(declarations: [method])

      result = pass.run(program)

      expect(result[:changes]).to eq(1)
      expect(method.body.statements.first.value).to be_a(TRuby::IR::Literal)
      expect(method.body.statements.first.value.value).to eq(5)
    end

    it "folds multiplication" do
      expr = TRuby::IR::BinaryOp.new(
        operator: "*",
        left: TRuby::IR::Literal.new(value: 4, literal_type: :integer),
        right: TRuby::IR::Literal.new(value: 5, literal_type: :integer)
      )

      ret = TRuby::IR::Return.new(value: expr)
      block = TRuby::IR::Block.new(statements: [ret])
      method = TRuby::IR::MethodDef.new(name: "test", body: block)
      program = TRuby::IR::Program.new(declarations: [method])

      pass.run(program)

      expect(method.body.statements.first.value.value).to eq(20)
    end

    it "does not fold division by zero" do
      expr = TRuby::IR::BinaryOp.new(
        operator: "/",
        left: TRuby::IR::Literal.new(value: 10, literal_type: :integer),
        right: TRuby::IR::Literal.new(value: 0, literal_type: :integer)
      )

      ret = TRuby::IR::Return.new(value: expr)
      block = TRuby::IR::Block.new(statements: [ret])
      method = TRuby::IR::MethodDef.new(name: "test", body: block)
      program = TRuby::IR::Program.new(declarations: [method])

      result = pass.run(program)

      expect(result[:changes]).to eq(0)
      expect(method.body.statements.first.value).to be_a(TRuby::IR::BinaryOp)
    end
  end

  describe TRuby::IR::Optimizer do
    let(:optimizer) { described_class.new }

    it "runs multiple optimization passes" do
      statements = [
        TRuby::IR::Return.new(
          value: TRuby::IR::BinaryOp.new(
            operator: "+",
            left: TRuby::IR::Literal.new(value: 2, literal_type: :integer),
            right: TRuby::IR::Literal.new(value: 3, literal_type: :integer)
          )
        ),
        TRuby::IR::Assignment.new(
          target: "x",
          value: TRuby::IR::Literal.new(value: 1, literal_type: :integer)
        )
      ]

      block = TRuby::IR::Block.new(statements: statements)
      method = TRuby::IR::MethodDef.new(name: "test", body: block)
      program = TRuby::IR::Program.new(declarations: [method])

      result = optimizer.optimize(program)

      expect(result[:stats][:total_changes]).to be > 0
      expect(method.body.statements.length).to eq(1)
      expect(method.body.statements.first.value.value).to eq(5)
    end

    it "returns optimization statistics" do
      program = TRuby::IR::Program.new(declarations: [])

      result = optimizer.optimize(program)

      expect(result[:stats]).to have_key(:iterations)
      expect(result[:stats]).to have_key(:total_changes)
      expect(result[:stats]).to have_key(:pass_stats)
    end

    it "stops when no more changes" do
      program = TRuby::IR::Program.new(declarations: [])

      result = optimizer.optimize(program, max_iterations: 100)

      expect(result[:stats][:iterations]).to be < 100
    end
  end

  describe TRuby::IR::Visitor do
    it "visits nodes with visitor pattern" do
      visited = []

      visitor = Class.new(TRuby::IR::Visitor) do
        define_method(:visit_type_alias) do |node|
          visited << node.name
        end
      end.new

      type_alias = TRuby::IR::TypeAlias.new(
        name: "Test",
        definition: TRuby::IR::SimpleType.new(name: "String")
      )
      program = TRuby::IR::Program.new(declarations: [type_alias])

      visitor.visit(program)

      expect(visited).to eq(["Test"])
    end
  end
end
