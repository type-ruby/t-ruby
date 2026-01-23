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

    it "converts tuple with rest element to RBS (fallback to union array)" do
      string_type = TRuby::IR::SimpleType.new(name: "String")
      rest_int = TRuby::IR::TupleRestElement.new(
        inner_type: TRuby::IR::GenericType.new(base: "Array", type_args: [
                                                 TRuby::IR::SimpleType.new(name: "Integer"),
                                               ])
      )
      tuple = described_class.new(element_types: [string_type, rest_int])

      # RBS fallback: tuple with rest → union array
      expect(tuple.to_rbs).to eq("Array[String | Integer]")
    end

    it "preserves tuple with rest in TRB format" do
      string_type = TRuby::IR::SimpleType.new(name: "String")
      rest_int = TRuby::IR::TupleRestElement.new(
        inner_type: TRuby::IR::GenericType.new(base: "Array", type_args: [
                                                 TRuby::IR::SimpleType.new(name: "Integer"),
                                               ])
      )
      tuple = described_class.new(element_types: [string_type, rest_int])

      expect(tuple.to_trb).to eq("[String, *Array<Integer>]")
    end
  end

  describe TRuby::IR::TupleRestElement do
    it "converts to TRB format" do
      inner = TRuby::IR::GenericType.new(base: "Array", type_args: [
                                           TRuby::IR::SimpleType.new(name: "Integer"),
                                         ])
      rest = described_class.new(inner_type: inner)

      expect(rest.to_trb).to eq("*Array<Integer>")
    end

    it "converts to RBS format (fallback to untyped)" do
      inner = TRuby::IR::GenericType.new(base: "Array", type_args: [
                                           TRuby::IR::SimpleType.new(name: "Integer"),
                                         ])
      rest = described_class.new(inner_type: inner)

      # RBS doesn't support tuple rest, fallback
      expect(rest.to_rbs).to eq("*untyped")
    end

    it "extracts element type from Array type" do
      inner = TRuby::IR::GenericType.new(base: "Array", type_args: [
                                           TRuby::IR::SimpleType.new(name: "Integer"),
                                         ])
      rest = described_class.new(inner_type: inner)

      expect(rest.element_type).to be_a(TRuby::IR::SimpleType)
      expect(rest.element_type.name).to eq("Integer")
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
          functions: [],
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
          functions: [],
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
          functions: [],
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
          functions: [],
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
          functions: [],
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
              { name: "to_json", type: "String" },
            ],
          }],
          functions: [],
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
              { name: "name", type: "String" },
            ],
            return_type: "String",
          }],
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
          functions: [],
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
          functions: [],
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
          ),
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
          ),
        ],
        return_type: TRuby::IR::SimpleType.new(name: "String")
      )
      program = TRuby::IR::Program.new(declarations: [method])

      output = generator.generate(program)

      expect(output).to include("def greet: (name: String) -> String")
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
        ),
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
        ),
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

  # Additional coverage tests for Node methods
  describe "Node methods" do
    describe TRuby::IR::Node do
      it "accepts visitor" do
        visitor = double("Visitor")
        node = described_class.new
        expect(visitor).to receive(:visit).with(node)
        node.accept(visitor)
      end

      it "returns empty children by default" do
        node = described_class.new
        expect(node.children).to eq([])
      end

      it "transforms with block" do
        node = described_class.new
        result = node.transform { |_n| "transformed" }
        expect(result).to eq("transformed")
      end
    end

    describe TRuby::IR::Interface do
      it "returns members as children" do
        member = TRuby::IR::InterfaceMember.new(
          name: "method1",
          type_signature: TRuby::IR::SimpleType.new(name: "String")
        )
        interface = described_class.new(name: "Test", members: [member])
        expect(interface.children).to eq([member])
      end
    end

    describe TRuby::IR::ClassDecl do
      it "returns body as children" do
        method = TRuby::IR::MethodDef.new(name: "foo")
        class_decl = described_class.new(name: "MyClass", body: [method])
        expect(class_decl.children).to eq([method])
      end
    end

    describe TRuby::IR::ModuleDecl do
      it "returns body as children" do
        method = TRuby::IR::MethodDef.new(name: "helper")
        module_decl = described_class.new(name: "Helpers", body: [method])
        expect(module_decl.children).to eq([method])
      end
    end

    describe TRuby::IR::MethodDef do
      it "returns body as children when present" do
        body = TRuby::IR::Block.new(statements: [])
        method = described_class.new(name: "test", body: body)
        expect(method.children).to eq([body])
      end

      it "returns empty array when body is nil" do
        method = described_class.new(name: "test", body: nil)
        expect(method.children).to eq([])
      end

      it "has return_type_slot attribute" do
        method = described_class.new(name: "test")
        slot = TRuby::IR::TypeSlot.new(kind: :return, location: { line: 1, column: 0 })
        method.return_type_slot = slot
        expect(method.return_type_slot).to eq(slot)
      end
    end

    describe TRuby::IR::Parameter do
      it "has type_slot attribute" do
        param = described_class.new(name: "x")
        slot = TRuby::IR::TypeSlot.new(kind: :parameter, location: { line: 1, column: 5 })
        param.type_slot = slot
        expect(param.type_slot).to eq(slot)
      end
    end

    describe TRuby::IR::Block do
      it "returns statements as children" do
        stmt1 = TRuby::IR::Return.new
        stmt2 = TRuby::IR::Return.new
        block = described_class.new(statements: [stmt1, stmt2])
        expect(block.children).to eq([stmt1, stmt2])
      end
    end

    describe TRuby::IR::Assignment do
      it "returns value as children" do
        value = TRuby::IR::Literal.new(value: 42, literal_type: :integer)
        assignment = described_class.new(target: "x", value: value)
        expect(assignment.children).to eq([value])
      end
    end

    describe TRuby::IR::MethodCall do
      it "returns receiver, block and arguments as children" do
        receiver = TRuby::IR::VariableRef.new(name: "obj")
        arg = TRuby::IR::Literal.new(value: 1, literal_type: :integer)
        block = TRuby::IR::Block.new
        call = described_class.new(
          receiver: receiver,
          method_name: "foo",
          arguments: [arg],
          block: block
        )
        expect(call.children).to include(receiver, block, arg)
      end
    end

    describe TRuby::IR::InterpolatedString do
      it "returns parts as children" do
        part1 = TRuby::IR::Literal.new(value: "hello ", literal_type: :string)
        part2 = TRuby::IR::VariableRef.new(name: "name")
        str = described_class.new(parts: [part1, part2])
        expect(str.children).to eq([part1, part2])
      end
    end

    describe TRuby::IR::ArrayLiteral do
      it "returns elements as children" do
        elem1 = TRuby::IR::Literal.new(value: 1, literal_type: :integer)
        elem2 = TRuby::IR::Literal.new(value: 2, literal_type: :integer)
        arr = described_class.new(elements: [elem1, elem2])
        expect(arr.children).to eq([elem1, elem2])
      end
    end

    describe TRuby::IR::HashPair do
      it "returns key and value as children" do
        key = TRuby::IR::Literal.new(value: :foo, literal_type: :symbol)
        value = TRuby::IR::Literal.new(value: 1, literal_type: :integer)
        pair = described_class.new(key: key, value: value)
        expect(pair.children).to eq([key, value])
      end
    end

    describe TRuby::IR::Conditional do
      it "returns condition, then_branch, and else_branch as children" do
        condition = TRuby::IR::Literal.new(value: true, literal_type: :boolean)
        then_branch = TRuby::IR::Return.new
        else_branch = TRuby::IR::Return.new
        cond = described_class.new(
          condition: condition,
          then_branch: then_branch,
          else_branch: else_branch
        )
        expect(cond.children).to eq([condition, then_branch, else_branch])
      end
    end

    describe TRuby::IR::CaseExpr do
      it "returns subject, else_clause, and when_clauses as children" do
        subject = TRuby::IR::VariableRef.new(name: "x")
        when_clause = TRuby::IR::WhenClause.new(
          patterns: [TRuby::IR::Literal.new(value: 1, literal_type: :integer)],
          body: TRuby::IR::Return.new
        )
        else_clause = TRuby::IR::Return.new
        case_expr = described_class.new(
          subject: subject,
          when_clauses: [when_clause],
          else_clause: else_clause
        )
        expect(case_expr.children).to include(subject, else_clause, when_clause)
      end
    end

    describe TRuby::IR::WhenClause do
      it "returns body and patterns as children" do
        pattern = TRuby::IR::Literal.new(value: 1, literal_type: :integer)
        body = TRuby::IR::Return.new
        when_clause = described_class.new(patterns: [pattern], body: body)
        expect(when_clause.children).to include(body, pattern)
      end
    end

    describe TRuby::IR::Loop do
      it "returns condition and body as children" do
        condition = TRuby::IR::Literal.new(value: true, literal_type: :boolean)
        body = TRuby::IR::Block.new
        loop_node = described_class.new(kind: :while, condition: condition, body: body)
        expect(loop_node.children).to eq([condition, body])
      end
    end

    describe TRuby::IR::ForLoop do
      it "returns iterable and body as children" do
        iterable = TRuby::IR::VariableRef.new(name: "arr")
        body = TRuby::IR::Block.new
        for_loop = described_class.new(variable: "x", iterable: iterable, body: body)
        expect(for_loop.children).to eq([iterable, body])
      end
    end

    describe TRuby::IR::Return do
      it "returns value as children when present" do
        value = TRuby::IR::Literal.new(value: 42, literal_type: :integer)
        ret = described_class.new(value: value)
        expect(ret.children).to eq([value])
      end

      it "returns empty array when value is nil" do
        ret = described_class.new(value: nil)
        expect(ret.children).to eq([])
      end
    end

    describe TRuby::IR::BinaryOp do
      it "returns left and right as children" do
        left = TRuby::IR::Literal.new(value: 1, literal_type: :integer)
        right = TRuby::IR::Literal.new(value: 2, literal_type: :integer)
        op = described_class.new(operator: "+", left: left, right: right)
        expect(op.children).to eq([left, right])
      end
    end

    describe TRuby::IR::UnaryOp do
      it "returns operand as children" do
        operand = TRuby::IR::Literal.new(value: true, literal_type: :boolean)
        op = described_class.new(operator: "!", operand: operand)
        expect(op.children).to eq([operand])
      end
    end

    describe TRuby::IR::TypeCast do
      it "returns expression as children" do
        expr = TRuby::IR::VariableRef.new(name: "x")
        cast = described_class.new(
          expression: expr,
          target_type: TRuby::IR::SimpleType.new(name: "String")
        )
        expect(cast.children).to eq([expr])
      end
    end

    describe TRuby::IR::TypeGuard do
      it "returns expression as children" do
        expr = TRuby::IR::VariableRef.new(name: "x")
        guard = described_class.new(expression: expr, type_check: "String")
        expect(guard.children).to eq([expr])
      end
    end

    describe TRuby::IR::Lambda do
      it "returns body as children" do
        body = TRuby::IR::Block.new
        lambda_node = described_class.new(body: body)
        expect(lambda_node.children).to eq([body])
      end
    end

    describe TRuby::IR::BeginBlock do
      it "returns body, clauses as children" do
        body = TRuby::IR::Block.new
        rescue_clause = TRuby::IR::RescueClause.new(body: TRuby::IR::Block.new)
        else_clause = TRuby::IR::Block.new
        ensure_clause = TRuby::IR::Block.new
        begin_block = described_class.new(
          body: body,
          rescue_clauses: [rescue_clause],
          else_clause: else_clause,
          ensure_clause: ensure_clause
        )
        expect(begin_block.children).to include(body, else_clause, ensure_clause, rescue_clause)
      end
    end

    describe TRuby::IR::RescueClause do
      it "returns body as children" do
        body = TRuby::IR::Block.new
        rescue_clause = described_class.new(body: body)
        expect(rescue_clause.children).to eq([body])
      end
    end
  end

  # TypeNode base class
  describe TRuby::IR::TypeNode do
    it "raises NotImplementedError for to_rbs" do
      node = described_class.new
      expect { node.to_rbs }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for to_trb" do
      node = described_class.new
      expect { node.to_trb }.to raise_error(NotImplementedError)
    end
  end

  # LiteralType
  describe TRuby::IR::LiteralType do
    it "converts to RBS format" do
      type = described_class.new(value: "hello")
      expect(type.to_rbs).to eq('"hello"')
    end

    it "converts to TRB format" do
      type = described_class.new(value: 42)
      expect(type.to_trb).to eq("42")
    end
  end

  # HashLiteralType
  describe TRuby::IR::HashLiteralType do
    it "converts to RBS format" do
      type = described_class.new(
        fields: [{ name: "foo", type: TRuby::IR::SimpleType.new(name: "String") }]
      )
      expect(type.to_rbs).to eq("Hash[Symbol, untyped]")
    end

    it "converts to TRB format" do
      type = described_class.new(
        fields: [
          { name: "foo", type: TRuby::IR::SimpleType.new(name: "String") },
          { name: "bar", type: TRuby::IR::SimpleType.new(name: "Integer") },
        ]
      )
      expect(type.to_trb).to eq("{ foo: String, bar: Integer }")
    end
  end

  # Visitor class
  describe TRuby::IR::Visitor do
    it "visits children when method not defined" do
      visitor = TRuby::IR::Visitor.new
      stmt = TRuby::IR::Return.new(value: TRuby::IR::Literal.new(value: 1, literal_type: :integer))
      block = TRuby::IR::Block.new(statements: [stmt])

      # Should not raise
      visitor.visit(block)
    end

    it "visit_children visits all children" do
      visited = []
      visitor = Class.new(TRuby::IR::Visitor) do
        define_method(:visit_literal) do |node|
          visited << node.value
        end
      end.new

      stmt1 = TRuby::IR::Literal.new(value: 1, literal_type: :integer)
      stmt2 = TRuby::IR::Literal.new(value: 2, literal_type: :integer)
      block = TRuby::IR::Block.new(statements: [stmt1, stmt2])

      visitor.visit_children(block)
      expect(visited).to eq([1, 2])
    end
  end
end
