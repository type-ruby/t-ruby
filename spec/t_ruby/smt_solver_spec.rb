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
        double_neg = TRuby::SMT::Not.new(TRuby::SMT::Not.new(v))
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
        expect(cnf).to eq([%w[x y]])
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
      cnf = [%w[x y]]
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
            ),
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
            ),
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
            ),
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

  # Additional coverage tests
  describe "Formula base class" do
    it "raises NotImplementedError for free_variables" do
      formula = TRuby::SMT::Formula.new
      expect { formula.free_variables }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for substitute" do
      formula = TRuby::SMT::Formula.new
      expect { formula.substitute({}) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for to_cnf" do
      formula = TRuby::SMT::Formula.new
      expect { formula.to_cnf }.to raise_error(NotImplementedError)
    end
  end

  describe TRuby::SMT::BoolConst do
    it "returns empty set for free_variables" do
      expect(TRuby::SMT::TRUE.free_variables).to eq(Set.new)
    end

    it "returns self for substitute" do
      result = TRuby::SMT::TRUE.substitute({ "x" => TRuby::SMT::FALSE })
      expect(result).to eq(TRuby::SMT::TRUE)
    end

    it "returns CNF for to_cnf" do
      expect(TRuby::SMT::TRUE.to_cnf).to eq([[]])
    end

    it "returns string for to_s" do
      expect(TRuby::SMT::TRUE.to_s).to eq("true")
      expect(TRuby::SMT::FALSE.to_s).to eq("false")
    end
  end

  describe TRuby::SMT::Variable do
    it "has consistent hash based on name" do
      v1 = var("x")
      v2 = var("x")
      expect(v1.hash).to eq(v2.hash)
    end

    it "implements eql? for hash key equality" do
      v1 = var("x")
      v2 = var("x")
      expect(v1.eql?(v2)).to be true
    end

    it "returns name for to_s" do
      v = var("my_var")
      expect(v.to_s).to eq("my_var")
    end
  end

  describe TRuby::SMT::Not do
    it "returns operand free_variables" do
      v = var("x")
      neg = !v
      expect(neg.free_variables).to eq(Set.new(["x"]))
    end

    it "substitutes in operand" do
      v = var("x")
      neg = !v
      result = neg.substitute({ "x" => TRuby::SMT::TRUE })
      expect(result.operand).to eq(TRuby::SMT::TRUE)
    end

    it "converts double negation to CNF" do
      v = var("x")
      double_neg = TRuby::SMT::Not.new(TRuby::SMT::Not.new(v))
      cnf = double_neg.to_cnf
      expect(cnf).to eq([["x"]])
    end

    it "converts negation of And to CNF (De Morgan)" do
      x = var("x")
      y = var("y")
      neg_and = TRuby::SMT::Not.new(x & y)
      cnf = neg_and.to_cnf
      expect(cnf).to be_a(Array)
    end

    it "converts negation of Or to CNF (De Morgan)" do
      x = var("x")
      y = var("y")
      neg_or = TRuby::SMT::Not.new(x | y)
      cnf = neg_or.to_cnf
      expect(cnf).to eq([["!x"], ["!y"]])
    end

    it "converts negation of unknown to CNF" do
      bool = TRuby::SMT::TRUE
      neg = TRuby::SMT::Not.new(bool)
      cnf = neg.to_cnf
      expect(cnf).to be_a(Array)
    end

    it "returns string for to_s" do
      v = var("x")
      neg = !v
      expect(neg.to_s).to eq("!x")
    end
  end

  describe TRuby::SMT::And do
    it "returns combined free_variables" do
      x = var("x")
      y = var("y")
      conj = x & y
      expect(conj.free_variables).to eq(Set.new(%w[x y]))
    end

    it "creates new And when simplify produces neither TRUE nor FALSE" do
      x = var("x")
      y = var("y")
      result = (x & y).simplify
      expect(result).to be_a(TRuby::SMT::And)
    end

    it "implements ==" do
      x = var("x")
      y = var("y")
      a1 = x & y
      a2 = x & y
      expect(a1 == a2).to be true
    end

    it "returns string for to_s" do
      x = var("x")
      y = var("y")
      expect((x & y).to_s).to eq("(x && y)")
    end
  end

  describe TRuby::SMT::Or do
    it "returns combined free_variables" do
      x = var("x")
      y = var("y")
      disj = x | y
      expect(disj.free_variables).to eq(Set.new(%w[x y]))
    end

    it "substitutes in both operands" do
      x = var("x")
      y = var("y")
      disj = x | y
      result = disj.substitute({ "x" => TRuby::SMT::TRUE })
      expect(result.left).to eq(TRuby::SMT::TRUE)
    end

    it "implements ==" do
      x = var("x")
      y = var("y")
      o1 = x | y
      o2 = x | y
      expect(o1 == o2).to be true
    end

    it "returns string for to_s" do
      x = var("x")
      y = var("y")
      expect((x | y).to_s).to eq("(x || y)")
    end
  end

  describe TRuby::SMT::Implies do
    it "returns combined free_variables" do
      x = var("x")
      y = var("y")
      impl = x.implies(y)
      expect(impl.free_variables).to eq(Set.new(%w[x y]))
    end

    it "substitutes in both operands" do
      x = var("x")
      y = var("y")
      impl = x.implies(y)
      result = impl.substitute({ "x" => TRuby::SMT::TRUE })
      expect(result.antecedent).to eq(TRuby::SMT::TRUE)
    end

    it "converts to CNF" do
      x = var("x")
      y = var("y")
      impl = x.implies(y)
      cnf = impl.to_cnf
      expect(cnf).to be_a(Array)
    end

    it "implements ==" do
      x = var("x")
      y = var("y")
      i1 = x.implies(y)
      i2 = x.implies(y)
      expect(i1 == i2).to be true
    end

    it "returns string for to_s" do
      x = var("x")
      y = var("y")
      expect(x.implies(y).to_s).to eq("(x -> y)")
    end
  end

  describe TRuby::SMT::Iff do
    it "returns combined free_variables" do
      x = var("x")
      y = var("y")
      iff = x.iff(y)
      expect(iff.free_variables).to eq(Set.new(%w[x y]))
    end

    it "substitutes in both operands" do
      x = var("x")
      y = var("y")
      iff = x.iff(y)
      result = iff.substitute({ "x" => TRuby::SMT::TRUE })
      expect(result.left).to eq(TRuby::SMT::TRUE)
    end

    it "simplifies to conjunction of implications" do
      x = var("x")
      y = var("y")
      iff = x.iff(y)
      simplified = iff.simplify
      # A <-> B = (A -> B) & (B -> A) which simplifies to And with Or operands
      expect(simplified).to be_a(TRuby::SMT::And)
    end

    it "converts to CNF" do
      x = var("x")
      y = var("y")
      iff = x.iff(y)
      cnf = iff.to_cnf
      expect(cnf).to be_a(Array)
    end

    it "implements ==" do
      x = var("x")
      y = var("y")
      iff1 = x.iff(y)
      iff2 = x.iff(y)
      expect(iff1 == iff2).to be true
    end

    it "returns string for to_s" do
      x = var("x")
      y = var("y")
      expect(x.iff(y).to_s).to eq("(x <-> y)")
    end
  end

  describe TRuby::SMT::TypeVar do
    it "substitutes when binding exists" do
      t = type_var("T")
      concrete_type = concrete("String")
      result = t.substitute({ "T" => concrete_type })
      expect(result).to eq(concrete_type)
    end

    it "returns self when no binding" do
      t = type_var("T")
      result = t.substitute({ "X" => concrete("String") })
      expect(result).to eq(t)
    end

    it "converts to CNF" do
      t = type_var("T")
      expect(t.to_cnf).to eq([["T"]])
    end

    it "has consistent hash" do
      t1 = type_var("T")
      t2 = type_var("T")
      expect(t1.hash).to eq(t2.hash)
    end

    it "implements eql?" do
      t1 = type_var("T")
      t2 = type_var("T")
      expect(t1.eql?(t2)).to be true
    end

    it "returns name for to_s" do
      t = type_var("MyType")
      expect(t.to_s).to eq("MyType")
    end
  end

  describe TRuby::SMT::Subtype do
    it "substitutes with concrete types" do
      sub = subtype(concrete("Integer"), concrete("Numeric"))
      result = sub.substitute({ "Integer" => concrete("Float") })
      expect(result.subtype.name).to eq("Integer")
    end

    it "substitutes type vars" do
      t1 = type_var("T1")
      t2 = type_var("T2")
      sub = subtype(t1, t2)
      result = sub.substitute({ "T1" => concrete("String") })
      expect(result.subtype.name).to eq("String")
    end

    it "returns string for to_s" do
      t1 = type_var("T1")
      t2 = type_var("T2")
      expect(subtype(t1, t2).to_s).to eq("T1 <: T2")
    end

    it "converts to CNF" do
      t1 = type_var("T1")
      t2 = type_var("T2")
      cnf = subtype(t1, t2).to_cnf
      expect(cnf).to eq([["T1<:T2"]])
    end
  end

  describe TRuby::SMT::TypeEqual do
    it "substitutes type vars" do
      t1 = type_var("T1")
      t2 = type_var("T2")
      eq = type_equal(t1, t2)
      result = eq.substitute({ "T1" => concrete("String") })
      expect(result.left.name).to eq("String")
    end

    it "returns string for to_s" do
      t1 = type_var("T1")
      t2 = type_var("T2")
      expect(type_equal(t1, t2).to_s).to eq("T1 = T2")
    end

    it "converts to CNF" do
      t1 = type_var("T1")
      t2 = type_var("T2")
      cnf = type_equal(t1, t2).to_cnf
      expect(cnf).to eq([["T1=T2"]])
    end
  end

  describe TRuby::SMT::HasProperty do
    it "returns free_variables from type_var and property_type" do
      t = type_var("T")
      pt = type_var("PT")
      prop = has_property(t, "name", pt)
      expect(prop.free_variables).to eq(Set.new(%w[T PT]))
    end

    it "substitutes type_var and property_type" do
      t = type_var("T")
      pt = type_var("PT")
      prop = has_property(t, "name", pt)
      result = prop.substitute({ "T" => concrete("User"), "PT" => concrete("String") })
      expect(result.type_var.name).to eq("User")
      expect(result.property_type.name).to eq("String")
    end

    it "converts to CNF" do
      t = type_var("T")
      pt = concrete("String")
      prop = has_property(t, "name", pt)
      cnf = prop.to_cnf
      expect(cnf).to eq([["T.name:String"]])
    end

    it "returns string for to_s" do
      t = type_var("T")
      pt = concrete("String")
      prop = has_property(t, "name", pt)
      expect(prop.to_s).to eq("T has name: String")
    end
  end

  describe TRuby::SMT::ConcreteType do
    it "has consistent hash based on name" do
      t1 = concrete("String")
      t2 = concrete("String")
      expect(t1.hash).to eq(t2.hash)
    end

    it "implements eql?" do
      t1 = concrete("String")
      t2 = concrete("String")
      expect(t1.eql?(t2)).to be true
    end

    it "returns name for to_s" do
      t = concrete("MyClass")
      expect(t.to_s).to eq("MyClass")
    end
  end

  describe TRuby::SMT::TypeInferenceEngine do
    let(:engine) { described_class.new }

    describe "#infer_expression" do
      it "infers array literal type" do
        arr = TRuby::IR::ArrayLiteral.new(
          elements: [
            TRuby::IR::Literal.new(value: 1, literal_type: :integer),
            TRuby::IR::Literal.new(value: 2, literal_type: :integer),
          ]
        )
        result = engine.infer_expression(arr)
        expect(result.name).to eq("Array")
      end

      it "handles empty array literal" do
        arr = TRuby::IR::ArrayLiteral.new(elements: [])
        result = engine.infer_expression(arr)
        expect(result.name).to eq("Array")
      end

      it "creates fresh var for unknown expression" do
        # Using a generic struct as unknown expression type
        unknown = Struct.new(:type).new(:unknown)
        result = engine.infer_expression(unknown)
        expect(result).to be_a(TRuby::SMT::TypeVar)
      end

      it "handles method call without receiver" do
        call = TRuby::IR::MethodCall.new(
          receiver: nil,
          method_name: "some_method"
        )
        result = engine.infer_expression(call)
        expect(result).to be_a(TRuby::SMT::TypeVar)
      end

      it "handles comparison operators" do
        cmp = TRuby::IR::BinaryOp.new(
          operator: "==",
          left: TRuby::IR::Literal.new(value: 1, literal_type: :integer),
          right: TRuby::IR::Literal.new(value: 2, literal_type: :integer)
        )
        result = engine.infer_expression(cmp)
        expect(result.name).to eq("Boolean")
      end

      it "handles logical operators" do
        logical = TRuby::IR::BinaryOp.new(
          operator: "&&",
          left: TRuby::IR::Literal.new(value: true, literal_type: :boolean),
          right: TRuby::IR::Literal.new(value: false, literal_type: :boolean)
        )
        result = engine.infer_expression(logical)
        expect(result.name).to eq("Boolean")
      end

      it "handles unknown operators" do
        unknown_op = TRuby::IR::BinaryOp.new(
          operator: "**",
          left: TRuby::IR::Literal.new(value: 2, literal_type: :integer),
          right: TRuby::IR::Literal.new(value: 3, literal_type: :integer)
        )
        result = engine.infer_expression(unknown_op)
        expect(result).to be_a(TRuby::SMT::TypeVar)
      end
    end

    describe "#infer_statement" do
      it "handles assignment with type annotation" do
        assign = TRuby::IR::Assignment.new(
          target: "x",
          value: TRuby::IR::Literal.new(value: 42, literal_type: :integer),
          type_annotation: TRuby::IR::SimpleType.new(name: "Numeric")
        )
        # Need to set up method context
        engine.infer_statement(assign, TRuby::SMT::ConcreteType.new("Object"))
        expect(engine.type_env["x"]).to be_a(TRuby::SMT::ConcreteType)
      end

      it "handles conditional statements" do
        cond = TRuby::IR::Conditional.new(
          condition: TRuby::IR::Literal.new(value: true, literal_type: :boolean),
          then_branch: TRuby::IR::Block.new(statements: []),
          else_branch: TRuby::IR::Block.new(statements: [])
        )
        engine.infer_statement(cond, TRuby::SMT::ConcreteType.new("Object"))
        # Should not raise
      end
    end

    describe "#infer_method with generic types" do
      it "handles generic type annotations" do
        method = TRuby::IR::MethodDef.new(
          name: "get_first",
          params: [
            TRuby::IR::Parameter.new(
              name: "arr",
              type_annotation: TRuby::IR::GenericType.new(base: "Array", type_args: ["T"])
            ),
          ],
          return_type: nil
        )

        result = engine.infer_method(method)
        expect(result[:success]).to be true
      end

      it "handles union type annotations" do
        method = TRuby::IR::MethodDef.new(
          name: "process",
          params: [
            TRuby::IR::Parameter.new(
              name: "val",
              type_annotation: TRuby::IR::UnionType.new(types: %w[String Integer])
            ),
          ],
          return_type: nil
        )

        result = engine.infer_method(method)
        expect(result[:success]).to be true
      end

      it "handles nullable type annotations" do
        method = TRuby::IR::MethodDef.new(
          name: "maybe_string",
          params: [
            TRuby::IR::Parameter.new(
              name: "val",
              type_annotation: TRuby::IR::NullableType.new(inner_type: "String")
            ),
          ],
          return_type: nil
        )

        result = engine.infer_method(method)
        expect(result[:success]).to be true
      end

      it "handles unknown type annotation" do
        unknown_type = Struct.new(:type).new(:unknown)
        method = TRuby::IR::MethodDef.new(
          name: "test",
          params: [
            TRuby::IR::Parameter.new(name: "val", type_annotation: unknown_type),
          ],
          return_type: nil
        )

        result = engine.infer_method(method)
        expect(result[:success]).to be true
      end
    end

    describe "#infer_body" do
      it "handles Return directly" do
        ret = TRuby::IR::Return.new(
          value: TRuby::IR::Literal.new(value: "test", literal_type: :string)
        )
        # Should not raise
        engine.infer_body(ret, TRuby::SMT::ConcreteType.new("String"))
      end
    end

    describe "literal type inference" do
      it "infers all literal types" do
        literals = [
          [:string, "String"],
          [:integer, "Integer"],
          [:float, "Float"],
          [:boolean, "Boolean"],
          [:symbol, "Symbol"],
          [:nil, "nil"],
          [:array, "Array"],
          [:hash, "Hash"],
          [:unknown, "Object"],
        ]

        literals.each do |lit_type, expected_type|
          lit = TRuby::IR::Literal.new(value: nil, literal_type: lit_type)
          result = engine.infer_expression(lit)
          expect(result.name).to eq(expected_type), "Expected #{lit_type} to infer as #{expected_type}"
        end
      end
    end
  end

  describe TRuby::SMT::ConstraintSolver do
    let(:solver) { described_class.new }

    describe "unification edge cases" do
      it "fails unification on incompatible concrete types" do
        solver.add_equal(concrete("String"), concrete("Integer"))
        result = solver.solve
        expect(result[:success]).to be false
      end

      it "handles occurs check" do
        # T = Array[T] would cause infinite recursion
        t = solver.fresh_var
        # Create a scenario where occurs check matters
        solver.add_equal(t, t)
        result = solver.solve
        expect(result[:success]).to be true
      end
    end
  end
end
