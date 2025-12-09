# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::SMT do
  include TRuby::SMT::DSL

  describe "Logical Formulas" do
    describe TRuby::SMT::Variable do
      it "has a name" do
        v = var("x")
        expect(v.name).to eq("x")
      end

      it "tracks free variables" do
        v = var("x")
        expect(v.free_variables).to include("x")
      end
    end

    describe TRuby::SMT::Not do
      it "negates a variable" do
        v = var("x")
        neg = !v
        expect(neg).to be_a(TRuby::SMT::Not)
        expect(neg.operand).to eq(v)
      end

      it "simplifies double negation" do
        v = var("x")
        double_neg = !!v
        expect(double_neg.simplify).to eq(v)
      end

      it "simplifies negation of true" do
        result = (!TRuby::SMT::TRUE).simplify
        expect(result).to eq(TRuby::SMT::FALSE)
      end
    end

    describe TRuby::SMT::And do
      it "combines two formulas" do
        x = var("x")
        y = var("y")
        conj = x & y
        expect(conj).to be_a(TRuby::SMT::And)
      end

      it "simplifies with true" do
        x = var("x")
        result = (x & TRuby::SMT::TRUE).simplify
        expect(result).to eq(x)
      end

      it "simplifies with false" do
        x = var("x")
        result = (x & TRuby::SMT::FALSE).simplify
        expect(result).to eq(TRuby::SMT::FALSE)
      end

      it "simplifies identical operands" do
        x = var("x")
        result = (x & x).simplify
        expect(result).to eq(x)
      end
    end

    describe TRuby::SMT::Or do
      it "combines two formulas" do
        x = var("x")
        y = var("y")
        disj = x | y
        expect(disj).to be_a(TRuby::SMT::Or)
      end

      it "simplifies with true" do
        x = var("x")
        result = (x | TRuby::SMT::TRUE).simplify
        expect(result).to eq(TRuby::SMT::TRUE)
      end

      it "simplifies with false" do
        x = var("x")
        result = (x | TRuby::SMT::FALSE).simplify
        expect(result).to eq(x)
      end
    end

    describe TRuby::SMT::Implies do
      it "creates implication" do
        x = var("x")
        y = var("y")
        impl = x.implies(y)
        expect(impl).to be_a(TRuby::SMT::Implies)
      end

      it "simplifies to disjunction" do
        x = var("x")
        y = var("y")
        impl = x.implies(y)
        simplified = impl.simplify
        expect(simplified).to be_a(TRuby::SMT::Or)
      end
    end

    describe TRuby::SMT::Iff do
      it "creates biconditional" do
        x = var("x")
        y = var("y")
        iff = x.iff(y)
        expect(iff).to be_a(TRuby::SMT::Iff)
      end
    end

    describe "#substitute" do
      it "replaces variables with values" do
        x = var("x")
        y = var("y")
        formula = x & y

        result = formula.substitute({ "x" => TRuby::SMT::TRUE })
        expect(result.left).to eq(TRuby::SMT::TRUE)
        expect(result.right).to eq(y)
      end
    end

    describe "#to_cnf" do
      it "converts simple variable to CNF" do
        x = var("x")
        cnf = x.to_cnf
        expect(cnf).to eq([["x"]])
      end

      it "converts negation to CNF" do
        x = var("x")
        cnf = (!x).to_cnf
        expect(cnf).to eq([["!x"]])
      end

      it "converts conjunction to CNF" do
        x = var("x")
        y = var("y")
        cnf = (x & y).to_cnf
        expect(cnf).to eq([["x"], ["y"]])
      end

      it "converts disjunction to CNF" do
        x = var("x")
        y = var("y")
        cnf = (x | y).to_cnf
        expect(cnf).to eq([["x", "y"]])
      end
    end
  end

  describe "Type Constraints" do
    describe TRuby::SMT::TypeVar do
      it "creates type variable" do
        t = type_var("T")
        expect(t.name).to eq("T")
      end

      it "can have bounds" do
        t = type_var("T", bounds: { upper: "Object" })
        expect(t.bounds[:upper]).to eq("Object")
      end
    end

    describe TRuby::SMT::Subtype do
      it "creates subtype constraint" do
        t1 = type_var("T1")
        t2 = type_var("T2")
        constraint = subtype(t1, t2)

        expect(constraint.subtype).to eq(t1)
        expect(constraint.supertype).to eq(t2)
      end

      it "tracks free variables" do
        t1 = type_var("T1")
        t2 = type_var("T2")
        constraint = subtype(t1, t2)

        expect(constraint.free_variables).to include("T1", "T2")
      end
    end

    describe TRuby::SMT::TypeEqual do
      it "creates equality constraint" do
        t1 = type_var("T1")
        t2 = type_var("T2")
        constraint = type_equal(t1, t2)

        expect(constraint.left).to eq(t1)
        expect(constraint.right).to eq(t2)
      end

      it "simplifies when equal" do
        t = type_var("T")
        constraint = type_equal(t, t)
        expect(constraint.simplify).to eq(TRuby::SMT::TRUE)
      end
    end

    describe TRuby::SMT::HasProperty do
      it "creates property constraint" do
        t = type_var("T")
        prop_type = concrete("String")
        constraint = has_property(t, "name", prop_type)

        expect(constraint.type_var).to eq(t)
        expect(constraint.property).to eq("name")
        expect(constraint.property_type).to eq(prop_type)
      end
    end

    describe TRuby::SMT::ConcreteType do
      it "wraps type name" do
        t = concrete("String")
        expect(t.name).to eq("String")
      end

      it "compares by name" do
        t1 = concrete("String")
        t2 = concrete("String")
        expect(t1).to eq(t2)
      end
    end
  end

  describe TRuby::SMT::SATSolver do
    let(:solver) { described_class.new }

    it "solves simple satisfiable formula" do
      cnf = [["x"], ["y"]]
      result = solver.solve(cnf)

      expect(result).not_to be_nil
      expect(result["x"]).to be true
      expect(result["y"]).to be true
    end

    it "returns nil for unsatisfiable formula" do
      cnf = [["x"], ["!x"]]
      result = solver.solve(cnf)

      expect(result).to be_nil
    end

    it "solves disjunction" do
      cnf = [["x", "y"]]
      result = solver.solve(cnf)

      expect(result).not_to be_nil
      expect(result["x"] || result["y"]).to be true
    end

    it "handles complex formulas" do
      # (x || y) && (!x || z) && (!y || !z)
      cnf = [["x", "y"], ["!x", "z"], ["!y", "!z"]]
      result = solver.solve(cnf)

      expect(result).not_to be_nil
    end

    it "handles empty formula (trivially satisfiable)" do
      result = solver.solve([])
      expect(result).to eq({})
    end
  end

  describe TRuby::SMT::ConstraintSolver do
    let(:solver) { described_class.new }

    describe "#fresh_var" do
      it "creates unique type variables" do
        v1 = solver.fresh_var
        v2 = solver.fresh_var

        expect(v1.name).not_to eq(v2.name)
      end

      it "uses provided prefix" do
        v = solver.fresh_var("Param")
        expect(v.name).to start_with("Param")
      end
    end

    describe "#add_constraint" do
      it "stores constraints" do
        t1 = solver.fresh_var
        t2 = concrete("String")
        solver.add_equal(t1, t2)

        expect(solver.constraints.length).to eq(1)
      end
    end

    describe "#subtype?" do
      it "returns true for equal types" do
        t = concrete("String")
        expect(solver.subtype?(t, t)).to be true
      end

      it "returns true for Object supertype" do
        t = concrete("String")
        obj = concrete("Object")
        expect(solver.subtype?(t, obj)).to be true
      end

      it "returns true for nil subtype" do
        nil_type = concrete("nil")
        string = concrete("String")
        expect(solver.subtype?(nil_type, string)).to be true
      end

      it "checks type hierarchy" do
        int = concrete("Integer")
        num = concrete("Numeric")
        expect(solver.subtype?(int, num)).to be true
      end

      it "checks transitive hierarchy" do
        int = concrete("Integer")
        obj = concrete("Object")
        expect(solver.subtype?(int, obj)).to be true
      end

      it "returns false for incompatible types" do
        string = concrete("String")
        int = concrete("Integer")
        expect(solver.subtype?(string, int)).to be false
      end
    end

    describe "#solve" do
      it "solves equality constraints" do
        t1 = solver.fresh_var
        t2 = concrete("String")
        solver.add_equal(t1, t2)

        result = solver.solve

        expect(result[:success]).to be true
        expect(result[:solution][t1.name].name).to eq("String")
      end

      it "solves chained equalities" do
        t1 = solver.fresh_var
        t2 = solver.fresh_var
        t3 = concrete("Integer")

        solver.add_equal(t1, t2)
        solver.add_equal(t2, t3)

        result = solver.solve

        expect(result[:success]).to be true
      end

      it "validates subtype constraints" do
        t1 = concrete("Integer")
        t2 = concrete("Numeric")
        solver.add_subtype(t1, t2)

        result = solver.solve

        expect(result[:success]).to be true
      end

      it "fails on invalid subtype" do
        t1 = concrete("String")
        t2 = concrete("Integer")
        solver.add_subtype(t1, t2)

        result = solver.solve

        expect(result[:success]).to be false
        expect(result[:errors]).not_to be_empty
      end

      it "instantiates unconstrained variables to Object" do
        t = solver.fresh_var

        result = solver.solve

        expect(result[:success]).to be true
        expect(result[:solution][t.name].name).to eq("Object")
      end
    end

    describe "#infer" do
      it "returns solved type for variable" do
        t = solver.fresh_var
        solver.add_equal(t, concrete("String"))
        solver.solve

        expect(solver.infer(t).name).to eq("String")
      end
    end
  end

  describe TRuby::SMT::TypeInferenceEngine do
    let(:engine) { described_class.new }

    describe "#infer_method" do
      it "infers types for annotated method" do
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

        result = engine.infer_method(method)

        expect(result[:success]).to be true
        expect(result[:params]["name"]).to eq("String")
        expect(result[:return_type]).to eq("String")
      end

      it "infers types for partially annotated method" do
        method = TRuby::IR::MethodDef.new(
          name: "process",
          params: [
            TRuby::IR::Parameter.new(name: "x"),
            TRuby::IR::Parameter.new(
              name: "y",
              type_annotation: TRuby::IR::SimpleType.new(name: "Integer")
            )
          ],
          return_type: nil
        )

        result = engine.infer_method(method)

        expect(result[:success]).to be true
        expect(result[:params]["y"]).to eq("Integer")
      end

      it "infers from return statement" do
        ret_stmt = TRuby::IR::Return.new(
          value: TRuby::IR::Literal.new(value: "hello", literal_type: :string)
        )

        method = TRuby::IR::MethodDef.new(
          name: "get_string",
          params: [],
          return_type: nil,
          body: TRuby::IR::Block.new(statements: [ret_stmt])
        )

        result = engine.infer_method(method)

        expect(result[:success]).to be true
      end

      it "infers from assignments" do
        assign = TRuby::IR::Assignment.new(
          target: "x",
          value: TRuby::IR::Literal.new(value: 42, literal_type: :integer)
        )

        ret = TRuby::IR::Return.new(
          value: TRuby::IR::VariableRef.new(name: "x")
        )

        method = TRuby::IR::MethodDef.new(
          name: "get_number",
          params: [],
          return_type: TRuby::IR::SimpleType.new(name: "Integer"),
          body: TRuby::IR::Block.new(statements: [assign, ret])
        )

        result = engine.infer_method(method)

        expect(result[:success]).to be true
      end

      it "infers from method calls" do
        call = TRuby::IR::MethodCall.new(
          receiver: TRuby::IR::Literal.new(value: "hello", literal_type: :string),
          method_name: "length"
        )

        ret = TRuby::IR::Return.new(value: call)

        method = TRuby::IR::MethodDef.new(
          name: "get_length",
          params: [],
          return_type: nil,
          body: TRuby::IR::Block.new(statements: [ret])
        )

        result = engine.infer_method(method)

        expect(result[:success]).to be true
      end

      it "validates binary operation constraints" do
        add = TRuby::IR::BinaryOp.new(
          operator: "+",
          left: TRuby::IR::VariableRef.new(name: "a"),
          right: TRuby::IR::VariableRef.new(name: "b")
        )

        ret = TRuby::IR::Return.new(value: add)

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
          return_type: nil,
          body: TRuby::IR::Block.new(statements: [ret])
        )

        result = engine.infer_method(method)

        expect(result[:success]).to be true
      end
    end
  end

  describe "DSL" do
    it "provides var helper" do
      v = var("x")
      expect(v).to be_a(TRuby::SMT::Variable)
    end

    it "provides type_var helper" do
      t = type_var("T")
      expect(t).to be_a(TRuby::SMT::TypeVar)
    end

    it "provides concrete helper" do
      c = concrete("String")
      expect(c).to be_a(TRuby::SMT::ConcreteType)
    end

    it "provides all helper" do
      x = var("x")
      y = var("y")
      z = var("z")
      result = all(x, y, z)
      expect(result).to be_a(TRuby::SMT::And)
    end

    it "provides any helper" do
      x = var("x")
      y = var("y")
      result = any(x, y)
      expect(result).to be_a(TRuby::SMT::Or)
    end
  end
end
