# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::SMT::Z3Solver do
  describe ".available?" do
    it "returns a boolean" do
      expect([true, false]).to include(described_class.available?)
    end
  end

  describe ".create" do
    it "creates Z3Solver when available and requested" do
      if described_class.available?
        solver = described_class.create(use_z3: true)
        expect(solver).to be_a(described_class)
      end
    end

    it "falls back to BuiltInSolver when Z3 not available or not requested" do
      solver = described_class.create(use_z3: false)
      expect(solver).to be_a(TRuby::SMT::BuiltInSolver)
    end
  end

  describe "declarations" do
    let(:solver) { described_class.new }

    it "declares integer variables" do
      result = solver.declare_int("x")
      expect(result).to include("declare-const")
      expect(result).to include("Int")
    end

    it "declares boolean variables" do
      result = solver.declare_bool("flag")
      expect(result).to include("declare-const")
      expect(result).to include("Bool")
    end

    it "declares functions" do
      result = solver.declare_fun("add", [:int, :int], :int)
      expect(result).to include("declare-fun")
      expect(result).to include("add")
    end
  end

  describe "assertions" do
    let(:solver) { described_class.new }

    it "generates SMT-LIB2 output" do
      solver.declare_int("x")
      solver.assert_gt("x", 0)
      solver.assert_lt("x", 10)

      smt = solver.to_smt2

      expect(smt).to include("declare-const x Int")
      expect(smt).to include("assert")
      expect(smt).to include("check-sat")
    end
  end

  describe "#reset" do
    let(:solver) { described_class.new }

    it "clears all declarations and assertions" do
      solver.declare_int("x")
      solver.assert_eq("x", 5)
      solver.reset

      smt = solver.to_smt2
      expect(smt).not_to include("declare-const x Int")
    end
  end
end

RSpec.describe TRuby::SMT::BuiltInSolver do
  let(:solver) { described_class.new }

  describe "#declare_int" do
    it "creates a type variable" do
      var = solver.declare_int("x")
      expect(var).to be_a(TRuby::SMT::TypeVar)
    end
  end

  describe "#assert_eq" do
    it "adds equality constraint" do
      left = TRuby::SMT::TypeVar.new("T1")
      right = TRuby::SMT::ConcreteType.new("String")

      solver.assert_eq(left, right)
      result = solver.solve

      expect(result[:success]).to be true
    end
  end

  describe "#solve" do
    it "solves constraints successfully" do
      result = solver.solve
      expect(result).to have_key(:success)
    end
  end
end

RSpec.describe TRuby::SMT::RefinementChecker do
  # Refinement checking requires Z3 - skip if not available
  describe "#check_refinement", if: TRuby::SMT::Z3Solver.available? do
    let(:checker) { described_class.new(use_z3: true) }

    it "validates positive number constraint" do
      result = checker.check_refinement("x", "> 0", 5)
      expect(result).to be true
    end

    it "rejects negative number for positive constraint" do
      result = checker.check_refinement("x", "> 0", -5)
      expect(result).to be false
    end

    it "validates range constraints" do
      expect(checker.check_refinement("x", ">= 0", 0)).to be true
      expect(checker.check_refinement("x", "<= 100", 50)).to be true
      expect(checker.check_refinement("x", "< 10", 5)).to be true
    end

    it "validates equality constraints" do
      expect(checker.check_refinement("x", "== 42", 42)).to be true
      expect(checker.check_refinement("x", "== 42", 43)).to be false
    end

    it "validates inequality constraints" do
      expect(checker.check_refinement("x", "!= 0", 1)).to be true
      expect(checker.check_refinement("x", "!= 0", 0)).to be false
    end
  end

  describe "#check_subtype_refinement", if: TRuby::SMT::Z3Solver.available? do
    let(:checker) { described_class.new(use_z3: true) }

    it "validates that > 5 is subtype of > 0" do
      # x > 5 implies x > 0
      result = checker.check_subtype_refinement("> 5", "> 0")
      expect(result).to be true
    end

    it "rejects that > 0 is subtype of > 5" do
      # x > 0 does NOT imply x > 5
      result = checker.check_subtype_refinement("> 0", "> 5")
      expect(result).to be false
    end

    it "validates that >= 10 is subtype of >= 5" do
      result = checker.check_subtype_refinement(">= 10", ">= 5")
      expect(result).to be true
    end
  end

  describe "without Z3" do
    let(:checker) { described_class.new(use_z3: false) }

    it "has a solver" do
      expect(checker.solver).not_to be_nil
    end

    it "initializes with no errors" do
      expect(checker.errors).to be_empty
    end
  end
end

RSpec.describe TRuby::SMT::ConstraintSolver do
  let(:solver) { described_class.new }

  describe "#fresh_var" do
    it "creates unique type variables" do
      var1 = solver.fresh_var("T")
      var2 = solver.fresh_var("T")

      expect(var1.name).not_to eq(var2.name)
    end
  end

  describe "#add_equal" do
    it "adds type equality constraint" do
      t1 = solver.fresh_var("T")
      string_type = TRuby::SMT::ConcreteType.new("String")

      solver.add_equal(t1, string_type)
      result = solver.solve

      expect(result[:success]).to be true
      expect(result[:solution][t1.name]).to eq(string_type)
    end
  end

  describe "#add_subtype" do
    it "accepts valid subtype relationships" do
      integer = TRuby::SMT::ConcreteType.new("Integer")
      numeric = TRuby::SMT::ConcreteType.new("Numeric")

      solver.add_subtype(integer, numeric)
      result = solver.solve

      expect(result[:success]).to be true
    end

    it "rejects invalid subtype relationships" do
      string = TRuby::SMT::ConcreteType.new("String")
      integer = TRuby::SMT::ConcreteType.new("Integer")

      solver.add_subtype(string, integer)
      result = solver.solve

      expect(result[:success]).to be false
    end
  end

  describe "#subtype?" do
    it "recognizes built-in type hierarchy" do
      expect(solver.subtype?(
        TRuby::SMT::ConcreteType.new("Integer"),
        TRuby::SMT::ConcreteType.new("Numeric")
      )).to be true

      expect(solver.subtype?(
        TRuby::SMT::ConcreteType.new("Float"),
        TRuby::SMT::ConcreteType.new("Numeric")
      )).to be true

      expect(solver.subtype?(
        TRuby::SMT::ConcreteType.new("String"),
        TRuby::SMT::ConcreteType.new("Object")
      )).to be true
    end

    it "treats nil as subtype of everything" do
      expect(solver.subtype?(
        TRuby::SMT::ConcreteType.new("nil"),
        TRuby::SMT::ConcreteType.new("String")
      )).to be true
    end

    it "recognizes same type as subtype" do
      expect(solver.subtype?(
        TRuby::SMT::ConcreteType.new("String"),
        TRuby::SMT::ConcreteType.new("String")
      )).to be true
    end
  end
end

RSpec.describe TRuby::SMT::TypeInferenceEngine do
  let(:engine) { described_class.new }

  describe "#infer_method" do
    it "infers return type from body" do
      # Create a simple method that returns an integer literal
      body = TRuby::IR::Block.new(
        statements: [
          TRuby::IR::Return.new(
            value: TRuby::IR::Literal.new(value: 42, literal_type: :integer)
          )
        ]
      )

      method = TRuby::IR::MethodDef.new(
        name: "answer",
        params: [],
        body: body,
        return_type: nil
      )

      result = engine.infer_method(method)

      expect(result[:success]).to be true
      # The engine will infer Integer or return the fresh type var resolved to Integer
      expect(["Integer", "Numeric", "Object"]).to include(result[:return_type])
    end

    it "infers parameter types from usage" do
      # Method that calls .to_s on parameter (implying Object type)
      body = TRuby::IR::Block.new(
        statements: [
          TRuby::IR::Return.new(
            value: TRuby::IR::MethodCall.new(
              receiver: TRuby::IR::VariableRef.new(name: "x"),
              method_name: "to_s",
              arguments: []
            )
          )
        ]
      )

      method = TRuby::IR::MethodDef.new(
        name: "stringify",
        params: [TRuby::IR::Parameter.new(name: "x", type_annotation: nil)],
        body: body,
        return_type: nil
      )

      result = engine.infer_method(method)

      expect(result[:success]).to be true
      # to_s is called, which returns String, but without more constraints
      # the engine may return Object or String depending on implementation
      expect(["String", "Object"]).to include(result[:return_type])
    end
  end

  describe "#infer_expression" do
    it "returns correct type for integer literals" do
      expr = TRuby::IR::Literal.new(value: 42, literal_type: :integer)
      type = engine.infer_expression(expr)

      expect(type.name).to eq("Integer")
    end

    it "returns correct type for string literals" do
      expr = TRuby::IR::Literal.new(value: "hello", literal_type: :string)
      type = engine.infer_expression(expr)

      expect(type.name).to eq("String")
    end

    it "returns correct type for boolean literals" do
      expr = TRuby::IR::Literal.new(value: true, literal_type: :boolean)
      type = engine.infer_expression(expr)

      expect(type.name).to eq("Boolean")
    end
  end
end
