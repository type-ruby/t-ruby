# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::TypeHierarchy do
  let(:hierarchy) { TRuby::TypeHierarchy.new }

  describe "#subtype_of?" do
    it "recognizes same type" do
      expect(hierarchy.subtype_of?("String", "String")).to be true
    end

    it "recognizes Integer as subtype of Numeric" do
      expect(hierarchy.subtype_of?("Integer", "Numeric")).to be true
    end

    it "recognizes Float as subtype of Numeric" do
      expect(hierarchy.subtype_of?("Float", "Numeric")).to be true
    end

    it "recognizes all types as subtype of Object" do
      expect(hierarchy.subtype_of?("String", "Object")).to be true
      expect(hierarchy.subtype_of?("Integer", "Object")).to be true
    end

    it "does not recognize Numeric as subtype of Integer" do
      expect(hierarchy.subtype_of?("Numeric", "Integer")).to be false
    end
  end

  describe "#compatible?" do
    it "recognizes compatible types" do
      expect(hierarchy.compatible?("Integer", "Numeric")).to be true
      expect(hierarchy.compatible?("Numeric", "Integer")).to be true
    end
  end

  describe "#common_supertype" do
    it "finds common supertype" do
      expect(hierarchy.common_supertype("Integer", "Float")).to eq("Numeric")
    end

    it "returns same type for identical types" do
      expect(hierarchy.common_supertype("String", "String")).to eq("String")
    end
  end
end

RSpec.describe TRuby::TypeScope do
  describe "#define and #lookup" do
    it "stores and retrieves types" do
      scope = TRuby::TypeScope.new
      scope.define("x", "Integer")
      expect(scope.lookup("x")).to eq("Integer")
    end

    it "looks up in parent scope" do
      parent = TRuby::TypeScope.new
      parent.define("x", "Integer")

      child = parent.child_scope
      expect(child.lookup("x")).to eq("Integer")
    end

    it "shadows parent scope" do
      parent = TRuby::TypeScope.new
      parent.define("x", "Integer")

      child = parent.child_scope
      child.define("x", "String")
      expect(child.lookup("x")).to eq("String")
      expect(parent.lookup("x")).to eq("Integer")
    end
  end
end

RSpec.describe TRuby::FlowContext do
  describe "#narrow" do
    it "narrows variable type" do
      context = TRuby::FlowContext.new
      context.narrow("x", "String")
      expect(context.get_narrowed_type("x")).to eq("String")
    end
  end

  describe "#branch" do
    it "creates independent copy" do
      context = TRuby::FlowContext.new
      context.narrow("x", "String")

      branch = context.branch
      branch.narrow("x", "Integer")

      expect(context.get_narrowed_type("x")).to eq("String")
      expect(branch.get_narrowed_type("x")).to eq("Integer")
    end
  end

  describe "#merge" do
    it "creates union for different types" do
      context1 = TRuby::FlowContext.new
      context1.narrow("x", "String")

      context2 = TRuby::FlowContext.new
      context2.narrow("x", "Integer")

      merged = context1.merge(context2)
      expect(merged.get_narrowed_type("x")).to include("String")
      expect(merged.get_narrowed_type("x")).to include("Integer")
    end

    it "keeps same type when both branches agree" do
      context1 = TRuby::FlowContext.new
      context1.narrow("x", "String")

      context2 = TRuby::FlowContext.new
      context2.narrow("x", "String")

      merged = context1.merge(context2)
      expect(merged.get_narrowed_type("x")).to eq("String")
    end
  end
end

RSpec.describe TRuby::TypeChecker do
  let(:checker) { TRuby::TypeChecker.new }

  describe "#register_function" do
    it "registers function signature" do
      checker.register_function(
        "greet",
        params: [{ name: "name", type: "String" }],
        return_type: "String"
      )

      # Verify by checking a call
      result = checker.check_call("greet", ['"hello"'])
      expect(result).to eq("String")
    end
  end

  describe "#check_call" do
    before do
      checker.register_function(
        "add",
        params: [
          { name: "a", type: "Integer" },
          { name: "b", type: "Integer" },
        ],
        return_type: "Integer"
      )
    end

    it "validates correct argument types" do
      checker.check_call("add", %w[1 2])
      expect(checker.errors).to be_empty
    end

    it "reports wrong argument count" do
      checker.check_call("add", ["1"])
      expect(checker.errors).not_to be_empty
      expect(checker.errors.first.message).to include("Wrong number")
    end

    it "reports type mismatch" do
      checker.check_call("add", ['"hello"', "2"])
      expect(checker.errors).not_to be_empty
      expect(checker.errors.first.message).to include("Type mismatch")
    end

    it "warns about unknown functions" do
      checker.check_call("unknown_func", [])
      expect(checker.warnings).not_to be_empty
    end
  end

  describe "#check_return" do
    it "validates matching return type" do
      result = checker.check_return('"hello"', "String")
      expect(result).to be true
      expect(checker.errors).to be_empty
    end

    it "reports return type mismatch" do
      checker.check_return("42", "String")
      expect(checker.errors).not_to be_empty
    end
  end

  describe "#check_assignment" do
    it "allows compatible assignment" do
      result = checker.check_assignment("x", "42", declared_type: "Integer")
      expect(result).to be true
    end

    it "reports incompatible assignment" do
      checker.check_assignment("x", '"hello"', declared_type: "Integer")
      expect(checker.errors).not_to be_empty
    end
  end

  describe "#check_operator" do
    it "validates arithmetic operators" do
      result = checker.check_operator("Integer", "+", "Integer")
      expect(result).to eq("Integer")
    end

    it "promotes to Float when needed" do
      result = checker.check_operator("Integer", "+", "Float")
      expect(result).to eq("Float")
    end

    it "allows string concatenation" do
      result = checker.check_operator("String", "+", "String")
      expect(result).to eq("String")
    end

    it "reports error for invalid string concatenation" do
      checker.check_operator("String", "+", "Integer")
      expect(checker.errors).not_to be_empty
    end

    it "returns Boolean for comparisons" do
      result = checker.check_operator("Integer", "==", "Integer")
      expect(result).to eq("Boolean")
    end
  end

  describe "#narrow_in_conditional" do
    it "narrows type from is_a? guard" do
      then_scope = TRuby::FlowContext.new
      else_scope = TRuby::FlowContext.new

      checker.narrow_in_conditional("x.is_a?(String)", then_scope, else_scope)

      expect(then_scope.get_narrowed_type("x")).to eq("String")
    end

    it "narrows from nil? check" do
      then_scope = TRuby::FlowContext.new
      else_scope = TRuby::FlowContext.new

      checker.narrow_in_conditional("x.nil?", then_scope, else_scope)

      expect(then_scope.get_narrowed_type("x")).to eq("nil")
    end
  end

  describe "#register_alias" do
    it "registers and resolves type aliases" do
      checker.register_alias("UserId", "Integer")
      expect(checker.resolve_type("UserId")).to eq("Integer")
    end
  end

  describe "#reset" do
    it "clears all state" do
      checker.register_function("test", params: [], return_type: "String")
      checker.check_call("unknown", [])

      checker.reset

      expect(checker.errors).to be_empty
      expect(checker.warnings).to be_empty
    end
  end

  describe "#diagnostics" do
    it "returns combined errors and warnings" do
      checker.check_call("unknown", [])

      diagnostics = checker.diagnostics
      expect(diagnostics).not_to be_empty
      expect(diagnostics.first[:type]).to eq(:warning)
    end
  end
end

RSpec.describe TRuby::TypeCheckError do
  it "formats error message" do
    error = TRuby::TypeCheckError.new(
      message: "Type mismatch",
      expected: "String",
      actual: "Integer",
      suggestion: "Use .to_s"
    )

    str = error.to_s
    expect(str).to include("Type mismatch")
    expect(str).to include("Expected: String")
    expect(str).to include("Actual: Integer")
    expect(str).to include("Suggestion: Use .to_s")
  end

  it "converts to diagnostic" do
    error = TRuby::TypeCheckError.new(
      message: "Type error",
      location: "line 5",
      expected: "String",
      actual: "Integer",
      severity: :error
    )

    diagnostic = error.to_diagnostic
    expect(diagnostic[:severity]).to eq(:error)
    expect(diagnostic[:message]).to eq("Type error")
    expect(diagnostic[:location]).to eq("line 5")
    expect(diagnostic[:expected]).to eq("String")
    expect(diagnostic[:actual]).to eq("Integer")
  end
end

RSpec.describe TRuby::TypeHierarchy do
  describe "#register_subtype" do
    it "registers custom subtype relationships" do
      hierarchy = TRuby::TypeHierarchy.new
      hierarchy.register_subtype("MyClass", "BaseClass")
      hierarchy.register_subtype("MyClass", "Interface")

      # Should be idempotent
      hierarchy.register_subtype("MyClass", "BaseClass")
    end
  end
end

RSpec.describe TRuby::FlowContext do
  describe "#push_guard and #pop_guard" do
    it "manages guard condition stack" do
      context = TRuby::FlowContext.new
      context.push_guard("x.is_a?(String)")
      context.push_guard("y > 0")

      expect(context.guard_conditions.length).to eq(2)

      context.pop_guard
      expect(context.guard_conditions.length).to eq(1)
    end
  end

  describe "#merge" do
    it "handles variables only in one branch" do
      context1 = TRuby::FlowContext.new
      context1.narrow("x", "String")

      context2 = TRuby::FlowContext.new
      # y not in context1

      merged = context1.merge(context2)
      expect(merged.get_narrowed_type("x")).to eq("String")
    end
  end
end

RSpec.describe TRuby::TypeChecker do
  describe "#check_program" do
    it "processes TypeAlias declarations" do
      checker = TRuby::TypeChecker.new(use_smt: true)
      alias_node = TRuby::IR::TypeAlias.new(
        name: "UserId",
        definition: TRuby::IR::SimpleType.new(name: "String")
      )
      program = TRuby::IR::Program.new(declarations: [alias_node])

      result = checker.check_program(program)
      expect(result[:success]).to be true
    end

    it "processes Interface declarations" do
      checker = TRuby::TypeChecker.new(use_smt: true)
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

      result = checker.check_program(program)
      expect(result[:success]).to be true
    end

    it "processes MethodDef with SMT" do
      checker = TRuby::TypeChecker.new(use_smt: true)
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

      result = checker.check_program(program)
      expect(result[:success]).to be true
    end
  end

  describe "#check_method_with_smt" do
    it "handles methods with SMT errors" do
      checker = TRuby::TypeChecker.new(use_smt: true)

      # Method that would cause type inference issues
      method = TRuby::IR::MethodDef.new(
        name: "test",
        params: [],
        return_type: nil
      )

      result = checker.check_method_with_smt(method)
      expect(result).to have_key(:success)
    end
  end

  describe "#validate_type" do
    let(:checker) { TRuby::TypeChecker.new(use_smt: true) }

    it "validates GenericType with unknown base" do
      type = TRuby::IR::GenericType.new(
        base: "UnknownGeneric",
        type_args: [TRuby::IR::SimpleType.new(name: "String")]
      )
      checker.validate_type(type)
      expect(checker.warnings).not_to be_empty
    end

    it "validates UnionType members" do
      type = TRuby::IR::UnionType.new(
        types: [
          TRuby::IR::SimpleType.new(name: "String"),
          TRuby::IR::SimpleType.new(name: "UnknownType"),
        ]
      )
      checker.validate_type(type)
      expect(checker.warnings).not_to be_empty
    end

    it "validates IntersectionType members" do
      type = TRuby::IR::IntersectionType.new(
        types: [
          TRuby::IR::SimpleType.new(name: "String"),
          TRuby::IR::SimpleType.new(name: "UnknownType"),
        ]
      )
      checker.validate_type(type)
      expect(checker.warnings).not_to be_empty
    end

    it "validates NullableType inner" do
      type = TRuby::IR::NullableType.new(
        inner_type: TRuby::IR::SimpleType.new(name: "UnknownType")
      )
      checker.validate_type(type)
      expect(checker.warnings).not_to be_empty
    end

    it "validates FunctionType" do
      type = TRuby::IR::FunctionType.new(
        param_types: [TRuby::IR::SimpleType.new(name: "UnknownParam")],
        return_type: TRuby::IR::SimpleType.new(name: "UnknownReturn")
      )
      checker.validate_type(type)
      expect(checker.warnings.length).to eq(2)
    end
  end

  describe "#subtype_with_smt?" do
    it "uses SMT solver for subtype check" do
      checker = TRuby::TypeChecker.new(use_smt: true)
      expect(checker.subtype_with_smt?("String", "String")).to be true
    end

    it "uses hierarchy without SMT" do
      checker = TRuby::TypeChecker.new(use_smt: false)
      expect(checker.subtype_with_smt?("Integer", "Numeric")).to be true
    end
  end

  describe "#to_smt_type" do
    let(:checker) { TRuby::TypeChecker.new(use_smt: true) }

    it "converts String to ConcreteType" do
      result = checker.to_smt_type("String")
      expect(result).to be_a(TRuby::SMT::ConcreteType)
      expect(result.name).to eq("String")
    end

    it "converts SimpleType to ConcreteType" do
      simple = TRuby::IR::SimpleType.new(name: "Integer")
      result = checker.to_smt_type(simple)
      expect(result).to be_a(TRuby::SMT::ConcreteType)
      expect(result.name).to eq("Integer")
    end

    it "passes through ConcreteType" do
      concrete = TRuby::SMT::ConcreteType.new("Boolean")
      result = checker.to_smt_type(concrete)
      expect(result).to eq(concrete)
    end

    it "passes through TypeVar" do
      type_var = TRuby::SMT::TypeVar.new("T")
      result = checker.to_smt_type(type_var)
      expect(result).to eq(type_var)
    end

    it "converts unknown to ConcreteType using to_s" do
      unknown = double("UnknownType", to_s: "Custom")
      result = checker.to_smt_type(unknown)
      expect(result).to be_a(TRuby::SMT::ConcreteType)
      expect(result.name).to eq("Custom")
    end
  end

  describe "#check_property_access" do
    let(:checker) { TRuby::TypeChecker.new }

    it "returns type for known property" do
      result = checker.check_property_access("String", "length")
      expect(result).to eq("Integer")
    end

    it "warns for unknown property" do
      checker.check_property_access("String", "unknown_property")
      expect(checker.warnings).not_to be_empty
    end

    it "returns nil for unknown receiver type" do
      result = checker.check_property_access("UnknownType", "foo")
      expect(result).to be_nil
    end
  end

  describe "#check_operator" do
    let(:checker) { TRuby::TypeChecker.new }

    it "handles logical operators" do
      result = checker.check_operator("Boolean", "&&", "String")
      expect(result).to eq("String")

      result = checker.check_operator("Integer", "||", "Float")
      expect(result).to eq("Float")
    end

    it "reports error for non-numeric arithmetic" do
      checker.check_operator("Boolean", "+", "String")
      expect(checker.errors).not_to be_empty
    end

    it "returns nil for unknown operator" do
      result = checker.check_operator("String", "<=>", "String")
      expect(result).to be_nil
    end
  end

  describe "#narrow_in_conditional" do
    let(:checker) { TRuby::TypeChecker.new }

    it "narrows from !nil? check" do
      then_scope = TRuby::FlowContext.new
      else_scope = TRuby::FlowContext.new

      checker.narrow_in_conditional("!x.nil?", then_scope, else_scope)

      expect(else_scope.get_narrowed_type("x")).to eq("nil")
    end
  end

  describe "#check_function" do
    let(:checker) { TRuby::TypeChecker.new }

    it "checks function body" do
      function_info = {
        name: "test",
        params: [{ name: "x", type: "Integer" }],
        return_type: "Integer",
      }

      body_lines = [
        "y = x",
        "return y",
      ]

      checker.check_function(function_info, body_lines)
      # Should not raise
    end
  end

  describe "#check_statement" do
    let(:checker) { TRuby::TypeChecker.new }

    it "parses return statement" do
      checker.check_statement("return 42")
      # Should not raise
    end

    it "parses assignment" do
      checker.check_statement("x = 42")
      # Should not raise
    end

    it "parses method call" do
      checker.register_function("puts", params: [], return_type: "nil")
      checker.check_statement("puts()")
      # Should not raise
    end
  end

  describe "#known_type?" do
    let(:checker) { TRuby::TypeChecker.new }

    it "recognizes built-in types" do
      %w[String Integer Float Boolean Array Hash Symbol void nil Object Numeric Enumerable].each do |type|
        expect(checker.known_type?(type)).to be true
      end
    end

    it "recognizes registered aliases" do
      checker.register_alias("UserId", "Integer")
      expect(checker.known_type?("UserId")).to be true
    end

    it "returns false for unknown types" do
      expect(checker.known_type?("SomeRandomType")).to be false
    end
  end

  describe "#infer_param_type" do
    let(:checker) { TRuby::TypeChecker.new }

    it "returns type from annotation" do
      param = TRuby::IR::Parameter.new(
        name: "x",
        type_annotation: TRuby::IR::SimpleType.new(name: "String")
      )
      expect(checker.infer_param_type(param)).to eq("String")
    end

    it "returns Object when no annotation" do
      param = TRuby::IR::Parameter.new(name: "x")
      expect(checker.infer_param_type(param)).to eq("Object")
    end

    it "handles non-simple type annotations" do
      param = TRuby::IR::Parameter.new(
        name: "arr",
        type_annotation: TRuby::IR::GenericType.new(base: "Array", type_args: [])
      )
      result = checker.infer_param_type(param)
      expect(result).to be_a(String)
    end
  end

  describe "#check_program_legacy" do
    it "checks program without SMT" do
      checker = TRuby::TypeChecker.new(use_smt: false)
      method = TRuby::IR::MethodDef.new(
        name: "test",
        params: [],
        return_type: nil
      )
      program = TRuby::IR::Program.new(declarations: [method])

      result = checker.check_program(program)
      expect(result[:success]).to be true
    end
  end
end

RSpec.describe TRuby::LegacyTypeChecker do
  it "initializes without SMT" do
    checker = TRuby::LegacyTypeChecker.new
    expect(checker.use_smt).to be false
  end
end

RSpec.describe TRuby::SMTTypeChecker do
  it "initializes with SMT" do
    checker = TRuby::SMTTypeChecker.new
    expect(checker.use_smt).to be true
  end

  describe "#check_with_constraints" do
    it "allows custom constraints" do
      checker = TRuby::SMTTypeChecker.new
      program = TRuby::IR::Program.new(declarations: [])

      result = checker.check_with_constraints(program) do |solver|
        # Add custom constraint
        solver.add_equal(
          TRuby::SMT::TypeVar.new("T"),
          TRuby::SMT::ConcreteType.new("String")
        )
      end

      expect(result[:success]).to be true
    end
  end

  describe "#solve_constraints" do
    it "solves current constraints" do
      checker = TRuby::SMTTypeChecker.new
      result = checker.solve_constraints
      expect(result[:success]).to be true
    end
  end

  describe "#inferred_type" do
    it "returns inferred type for variable" do
      checker = TRuby::SMTTypeChecker.new
      # Would need to run type inference first for meaningful result
      # Result may be nil if not inferred
      expect(checker.inferred_type("SomeVar")).to be_nil
    end
  end
end
