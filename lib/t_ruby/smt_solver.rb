# frozen_string_literal: true

module TRuby
  module SMT
    #==========================================================================
    # Logical Formulas
    #==========================================================================

    # Base class for all formulas
    class Formula
      def &(other)
        And.new(self, other)
      end

      def |(other)
        Or.new(self, other)
      end

      def !
        Not.new(self)
      end

      def implies(other)
        Implies.new(self, other)
      end

      def iff(other)
        Iff.new(self, other)
      end

      def free_variables
        raise NotImplementedError
      end

      def substitute(bindings)
        raise NotImplementedError
      end

      def simplify
        self
      end

      def to_cnf
        raise NotImplementedError
      end
    end

    # Boolean constant
    class BoolConst < Formula
      attr_reader :value

      def initialize(value)
        @value = value
      end

      def free_variables
        Set.new
      end

      def substitute(_bindings)
        self
      end

      def simplify
        self
      end

      def to_cnf
        @value ? [[]] : [[]]
      end

      def ==(other)
        other.is_a?(BoolConst) && other.value == @value
      end

      def to_s
        @value.to_s
      end
    end

    TRUE = BoolConst.new(true)
    FALSE = BoolConst.new(false)

    # Propositional variable
    class Variable < Formula
      attr_reader :name

      def initialize(name)
        @name = name.to_s
      end

      def free_variables
        Set.new([@name])
      end

      def substitute(bindings)
        bindings[@name] || self
      end

      def to_cnf
        [[@name]]
      end

      def ==(other)
        other.is_a?(Variable) && other.name == @name
      end

      def hash
        @name.hash
      end

      def eql?(other)
        self == other
      end

      def to_s
        @name
      end
    end

    # Negation
    class Not < Formula
      attr_reader :operand

      def initialize(operand)
        @operand = operand
      end

      def free_variables
        @operand.free_variables
      end

      def substitute(bindings)
        Not.new(@operand.substitute(bindings))
      end

      def simplify
        inner = @operand.simplify
        case inner
        when BoolConst
          BoolConst.new(!inner.value)
        when Not
          inner.operand
        else
          Not.new(inner)
        end
      end

      def to_cnf
        case @operand
        when Variable
          [["!#{@operand.name}"]]
        when Not
          @operand.operand.to_cnf
        when And
          # De Morgan: !(A & B) = !A | !B
          Or.new(Not.new(@operand.left), Not.new(@operand.right)).to_cnf
        when Or
          # De Morgan: !(A | B) = !A & !B
          And.new(Not.new(@operand.left), Not.new(@operand.right)).to_cnf
        else
          [["!#{@operand}"]]
        end
      end

      def ==(other)
        other.is_a?(Not) && other.operand == @operand
      end

      def to_s
        "!#{@operand}"
      end
    end

    # Conjunction
    class And < Formula
      attr_reader :left, :right

      def initialize(left, right)
        @left = left
        @right = right
      end

      def free_variables
        @left.free_variables | @right.free_variables
      end

      def substitute(bindings)
        And.new(@left.substitute(bindings), @right.substitute(bindings))
      end

      def simplify
        l = @left.simplify
        r = @right.simplify

        return FALSE if l == FALSE || r == FALSE
        return r if l == TRUE
        return l if r == TRUE
        return l if l == r

        And.new(l, r)
      end

      def to_cnf
        @left.to_cnf + @right.to_cnf
      end

      def ==(other)
        other.is_a?(And) && other.left == @left && other.right == @right
      end

      def to_s
        "(#{@left} && #{@right})"
      end
    end

    # Disjunction
    class Or < Formula
      attr_reader :left, :right

      def initialize(left, right)
        @left = left
        @right = right
      end

      def free_variables
        @left.free_variables | @right.free_variables
      end

      def substitute(bindings)
        Or.new(@left.substitute(bindings), @right.substitute(bindings))
      end

      def simplify
        l = @left.simplify
        r = @right.simplify

        return TRUE if l == TRUE || r == TRUE
        return r if l == FALSE
        return l if r == FALSE
        return l if l == r

        Or.new(l, r)
      end

      def to_cnf
        left_cnf = @left.to_cnf
        right_cnf = @right.to_cnf

        # Distribute: (A & B) | C = (A | C) & (B | C)
        result = []
        left_cnf.each do |left_clause|
          right_cnf.each do |right_clause|
            result << (left_clause + right_clause).uniq
          end
        end
        result
      end

      def ==(other)
        other.is_a?(Or) && other.left == @left && other.right == @right
      end

      def to_s
        "(#{@left} || #{@right})"
      end
    end

    # Implication
    class Implies < Formula
      attr_reader :antecedent, :consequent

      def initialize(antecedent, consequent)
        @antecedent = antecedent
        @consequent = consequent
      end

      def free_variables
        @antecedent.free_variables | @consequent.free_variables
      end

      def substitute(bindings)
        Implies.new(@antecedent.substitute(bindings), @consequent.substitute(bindings))
      end

      def simplify
        # A -> B = !A | B
        Or.new(Not.new(@antecedent), @consequent).simplify
      end

      def to_cnf
        # A -> B = !A | B
        Or.new(Not.new(@antecedent), @consequent).to_cnf
      end

      def ==(other)
        other.is_a?(Implies) && other.antecedent == @antecedent && other.consequent == @consequent
      end

      def to_s
        "(#{@antecedent} -> #{@consequent})"
      end
    end

    # Biconditional
    class Iff < Formula
      attr_reader :left, :right

      def initialize(left, right)
        @left = left
        @right = right
      end

      def free_variables
        @left.free_variables | @right.free_variables
      end

      def substitute(bindings)
        Iff.new(@left.substitute(bindings), @right.substitute(bindings))
      end

      def simplify
        # A <-> B = (A -> B) & (B -> A)
        And.new(Implies.new(@left, @right), Implies.new(@right, @left)).simplify
      end

      def to_cnf
        And.new(Implies.new(@left, @right), Implies.new(@right, @left)).to_cnf
      end

      def ==(other)
        other.is_a?(Iff) && other.left == @left && other.right == @right
      end

      def to_s
        "(#{@left} <-> #{@right})"
      end
    end

    #==========================================================================
    # Type Constraints
    #==========================================================================

    # Type variable
    class TypeVar < Formula
      attr_reader :name, :bounds

      def initialize(name, bounds: nil)
        @name = name.to_s
        @bounds = bounds # { upper: Type, lower: Type }
      end

      def free_variables
        Set.new([@name])
      end

      def substitute(bindings)
        bindings[@name] || self
      end

      def to_cnf
        [[@name]]
      end

      def ==(other)
        other.is_a?(TypeVar) && other.name == @name
      end

      def hash
        @name.hash
      end

      def eql?(other)
        self == other
      end

      def to_s
        @name
      end
    end

    # Subtype constraint: A <: B (A is subtype of B)
    class Subtype < Formula
      attr_reader :subtype, :supertype

      def initialize(subtype, supertype)
        @subtype = subtype
        @supertype = supertype
      end

      def free_variables
        vars = Set.new
        vars.add(@subtype.name) if @subtype.is_a?(TypeVar)
        vars.add(@supertype.name) if @supertype.is_a?(TypeVar)
        vars
      end

      def substitute(bindings)
        sub = @subtype.is_a?(TypeVar) ? (bindings[@subtype.name] || @subtype) : @subtype
        sup = @supertype.is_a?(TypeVar) ? (bindings[@supertype.name] || @supertype) : @supertype
        Subtype.new(sub, sup)
      end

      def simplify
        self
      end

      def to_cnf
        [["#{@subtype}<:#{@supertype}"]]
      end

      def ==(other)
        other.is_a?(Subtype) && other.subtype == @subtype && other.supertype == @supertype
      end

      def to_s
        "#{@subtype} <: #{@supertype}"
      end
    end

    # Type equality: A = B
    class TypeEqual < Formula
      attr_reader :left, :right

      def initialize(left, right)
        @left = left
        @right = right
      end

      def free_variables
        vars = Set.new
        vars.add(@left.name) if @left.is_a?(TypeVar)
        vars.add(@right.name) if @right.is_a?(TypeVar)
        vars
      end

      def substitute(bindings)
        l = @left.is_a?(TypeVar) ? (bindings[@left.name] || @left) : @left
        r = @right.is_a?(TypeVar) ? (bindings[@right.name] || @right) : @right
        TypeEqual.new(l, r)
      end

      def simplify
        return TRUE if @left == @right
        self
      end

      def to_cnf
        [["#{@left}=#{@right}"]]
      end

      def ==(other)
        other.is_a?(TypeEqual) && other.left == @left && other.right == @right
      end

      def to_s
        "#{@left} = #{@right}"
      end
    end

    # Instance constraint: T has property P
    class HasProperty < Formula
      attr_reader :type_var, :property, :property_type

      def initialize(type_var, property, property_type)
        @type_var = type_var
        @property = property
        @property_type = property_type
      end

      def free_variables
        vars = Set.new
        vars.add(@type_var.name) if @type_var.is_a?(TypeVar)
        vars.add(@property_type.name) if @property_type.is_a?(TypeVar)
        vars
      end

      def substitute(bindings)
        tv = @type_var.is_a?(TypeVar) ? (bindings[@type_var.name] || @type_var) : @type_var
        pt = @property_type.is_a?(TypeVar) ? (bindings[@property_type.name] || @property_type) : @property_type
        HasProperty.new(tv, @property, pt)
      end

      def to_cnf
        [["#{@type_var}.#{@property}:#{@property_type}"]]
      end

      def to_s
        "#{@type_var} has #{@property}: #{@property_type}"
      end
    end

    #==========================================================================
    # Concrete Types for Solver
    #==========================================================================

    class ConcreteType
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def ==(other)
        other.is_a?(ConcreteType) && other.name == @name
      end

      def hash
        @name.hash
      end

      def eql?(other)
        self == other
      end

      def to_s
        @name
      end
    end

    #==========================================================================
    # SAT Solver (DPLL Algorithm)
    #==========================================================================

    class SATSolver
      attr_reader :assignments, :conflicts

      def initialize
        @assignments = {}
        @conflicts = []
      end

      # Solve CNF formula
      def solve(cnf)
        @assignments = {}
        @conflicts = []

        dpll(cnf.dup, {})
      end

      private

      def dpll(clauses, assignment)
        # Unit propagation
        loop do
          unit = find_unit_clause(clauses)
          break unless unit

          var, value = parse_literal(unit)
          assignment[var] = value
          clauses = propagate(clauses, var, value)

          return nil if clauses.any?(&:empty?) # Conflict
        end

        # All clauses satisfied
        return assignment if clauses.empty?

        # Check for empty clause (conflict)
        return nil if clauses.any?(&:empty?)

        # Choose variable
        var = choose_variable(clauses)
        return assignment unless var

        # Try true
        result = dpll(propagate(clauses.dup, var, true), assignment.merge(var => true))
        return result if result

        # Try false
        dpll(propagate(clauses.dup, var, false), assignment.merge(var => false))
      end

      def find_unit_clause(clauses)
        clauses.each do |clause|
          return clause.first if clause.length == 1
        end
        nil
      end

      def parse_literal(literal)
        if literal.start_with?("!")
          [literal[1..], false]
        else
          [literal, true]
        end
      end

      def propagate(clauses, var, value)
        result = []

        clauses.each do |clause|
          # If clause contains literal with matching polarity, clause is satisfied
          satisfied = clause.any? do |lit|
            lit_var, lit_value = parse_literal(lit)
            lit_var == var && lit_value == value
          end

          next if satisfied

          # Remove literals with opposite polarity
          new_clause = clause.reject do |lit|
            lit_var, lit_value = parse_literal(lit)
            lit_var == var && lit_value != value
          end

          result << new_clause
        end

        result
      end

      def choose_variable(clauses)
        # VSIDS-like heuristic: choose most frequent variable
        counts = Hash.new(0)

        clauses.each do |clause|
          clause.each do |lit|
            var, = parse_literal(lit)
            counts[var] += 1
          end
        end

        counts.max_by { |_, v| v }&.first
      end
    end

    #==========================================================================
    # Type Constraint Solver
    #==========================================================================

    class ConstraintSolver
      attr_reader :constraints, :solution, :errors

      # Type hierarchy (built-in)
      TYPE_HIERARCHY = {
        "Integer" => ["Numeric", "Object"],
        "Float" => ["Numeric", "Object"],
        "Numeric" => ["Object"],
        "String" => ["Object"],
        "Array" => ["Enumerable", "Object"],
        "Hash" => ["Enumerable", "Object"],
        "Enumerable" => ["Object"],
        "Boolean" => ["Object"],
        "Symbol" => ["Object"],
        "nil" => ["Object"],
        "Object" => []
      }.freeze

      def initialize
        @constraints = []
        @solution = {}
        @errors = []
        @type_vars = {}
      end

      # Create a new type variable
      def fresh_var(prefix = "T")
        name = "#{prefix}#{@type_vars.length}"
        var = TypeVar.new(name)
        @type_vars[name] = var
        var
      end

      # Add constraint
      def add_constraint(constraint)
        @constraints << constraint
      end

      # Add subtype constraint
      def add_subtype(sub, sup)
        add_constraint(Subtype.new(sub, sup))
      end

      # Add equality constraint
      def add_equal(left, right)
        add_constraint(TypeEqual.new(left, right))
      end

      # Solve all constraints
      def solve
        @solution = {}
        @errors = []

        # Phase 1: Unification
        unified = unify_constraints

        # Phase 2: Subtype checking
        check_subtypes(unified) if @errors.empty?

        # Phase 3: Instantiation
        instantiate_remaining if @errors.empty?

        {
          success: @errors.empty?,
          solution: @solution,
          errors: @errors
        }
      end

      # Check if type A is subtype of type B
      def subtype?(sub, sup)
        return true if sub == sup
        return true if sup.to_s == "Object"
        return true if sub.to_s == "nil" # nil is subtype of everything (nullable)

        sub_name = sub.is_a?(ConcreteType) ? sub.name : sub.to_s
        sup_name = sup.is_a?(ConcreteType) ? sup.name : sup.to_s

        # Check type hierarchy
        ancestors = TYPE_HIERARCHY[sub_name] || []
        return true if ancestors.include?(sup_name)

        # Check transitive closure
        ancestors.any? { |a| subtype?(ConcreteType.new(a), sup) }
      end

      # Infer type from constraints
      def infer(var)
        @solution[var.name] || @solution[var.to_s]
      end

      private

      def unify_constraints
        worklist = @constraints.dup

        while (constraint = worklist.shift)
          case constraint
          when TypeEqual
            result = unify(constraint.left, constraint.right)
            if result
              # Apply substitution to remaining constraints
              worklist = worklist.map { |c| c.substitute(result) }
              @solution.merge!(result)
            else
              @errors << "Cannot unify #{constraint.left} with #{constraint.right}"
            end
          end
        end

        @constraints.reject { |c| c.is_a?(TypeEqual) }
      end

      def unify(left, right)
        return {} if left == right

        # If left is type variable, bind it
        if left.is_a?(TypeVar)
          return nil if occurs_check(left, right)
          return { left.name => right }
        end

        # If right is type variable, bind it
        if right.is_a?(TypeVar)
          return nil if occurs_check(right, left)
          return { right.name => left }
        end

        # Both are concrete types
        if left.is_a?(ConcreteType) && right.is_a?(ConcreteType)
          return {} if left.name == right.name
          return nil
        end

        nil
      end

      def occurs_check(var, type)
        return false unless type.respond_to?(:free_variables)
        type.free_variables.include?(var.name)
      end

      def check_subtypes(remaining_constraints)
        remaining_constraints.each do |constraint|
          case constraint
          when Subtype
            sub = resolve_type(constraint.subtype)
            sup = resolve_type(constraint.supertype)

            # Skip if either is still a TypeVar (unresolved)
            next if sub.is_a?(TypeVar) || sup.is_a?(TypeVar)

            unless subtype?(sub, sup)
              @errors << "Type #{sub} is not a subtype of #{sup}"
            end
          end
        end
      end

      def resolve_type(type)
        case type
        when TypeVar
          @solution[type.name] || type
        when ConcreteType
          type
        else
          ConcreteType.new(type.to_s)
        end
      end

      def instantiate_remaining
        @type_vars.each do |name, var|
          next if @solution[name]

          # Default to Object if no constraints
          @solution[name] = ConcreteType.new("Object")
        end
      end
    end

    #==========================================================================
    # Type Inference Engine using SMT
    #==========================================================================

    class TypeInferenceEngine
      attr_reader :solver, :type_env

      def initialize
        @solver = ConstraintSolver.new
        @type_env = {} # Variable name -> Type
      end

      # Infer types for a method
      def infer_method(method_ir)
        param_types = {}
        return_type = nil

        # Create type variables for parameters without annotations
        method_ir.params.each do |param|
          if param.type_annotation
            param_types[param.name] = type_from_ir(param.type_annotation)
          else
            param_types[param.name] = @solver.fresh_var("P_#{param.name}")
          end
          @type_env[param.name] = param_types[param.name]
        end

        # Create type variable for return type if not annotated
        return_type = if method_ir.return_type
          type_from_ir(method_ir.return_type)
        else
          @solver.fresh_var("R_#{method_ir.name}")
        end

        # Analyze body to generate constraints
        if method_ir.body
          infer_body(method_ir.body, return_type)
        end

        # Solve constraints
        result = @solver.solve

        if result[:success]
          # Build inferred signature
          inferred_params = param_types.transform_values do |type|
            resolve_type(type, result[:solution])
          end

          inferred_return = resolve_type(return_type, result[:solution])

          {
            success: true,
            params: inferred_params,
            return_type: inferred_return
          }
        else
          {
            success: false,
            errors: result[:errors]
          }
        end
      end

      # Generate constraints from method body
      def infer_body(body_ir, expected_return)
        case body_ir
        when IR::Block
          body_ir.statements.each do |stmt|
            infer_statement(stmt, expected_return)
          end
        when IR::Return
          if body_ir.value
            value_type = infer_expression(body_ir.value)
            @solver.add_subtype(value_type, expected_return)
          end
        end
      end

      # Infer statement
      def infer_statement(stmt, expected_return)
        case stmt
        when IR::Assignment
          value_type = infer_expression(stmt.value)
          @type_env[stmt.target] = value_type

          if stmt.type_annotation
            annotated = type_from_ir(stmt.type_annotation)
            @solver.add_subtype(value_type, annotated)
          end
        when IR::Return
          if stmt.value
            value_type = infer_expression(stmt.value)
            @solver.add_subtype(value_type, expected_return)
          end
        when IR::Conditional
          infer_expression(stmt.condition)
          infer_body(stmt.then_branch, expected_return) if stmt.then_branch
          infer_body(stmt.else_branch, expected_return) if stmt.else_branch
        end
      end

      # Infer expression type
      def infer_expression(expr)
        case expr
        when IR::Literal
          ConcreteType.new(literal_type(expr.literal_type))
        when IR::VariableRef
          @type_env[expr.name] || @solver.fresh_var("V_#{expr.name}")
        when IR::MethodCall
          infer_method_call(expr)
        when IR::BinaryOp
          infer_binary_op(expr)
        when IR::ArrayLiteral
          infer_array_literal(expr)
        else
          @solver.fresh_var("E")
        end
      end

      private

      def type_from_ir(ir_type)
        case ir_type
        when IR::SimpleType
          ConcreteType.new(ir_type.name)
        when IR::GenericType
          # Simplified: just use base type for now
          ConcreteType.new(ir_type.base)
        when IR::UnionType
          # Create fresh var with union constraint
          @solver.fresh_var("U")
        when IR::NullableType
          # T | nil
          @solver.fresh_var("N")
        else
          @solver.fresh_var("T")
        end
      end

      def resolve_type(type, solution)
        case type
        when TypeVar
          resolved = solution[type.name]
          resolved ? resolve_type(resolved, solution) : "Object"
        when ConcreteType
          type.name
        else
          type.to_s
        end
      end

      def literal_type(lit_type)
        case lit_type
        when :string then "String"
        when :integer then "Integer"
        when :float then "Float"
        when :boolean then "Boolean"
        when :symbol then "Symbol"
        when :nil then "nil"
        when :array then "Array"
        when :hash then "Hash"
        else "Object"
        end
      end

      def infer_method_call(call)
        # Get receiver type
        receiver_type = if call.receiver
          infer_expression(call.receiver)
        else
          @type_env["self"] || ConcreteType.new("Object")
        end

        # Look up method return type
        return_type = lookup_method_type(receiver_type, call.method_name)
        return_type || @solver.fresh_var("M_#{call.method_name}")
      end

      def lookup_method_type(receiver, method)
        # Built-in method types
        method_types = {
          "to_s" => ConcreteType.new("String"),
          "to_i" => ConcreteType.new("Integer"),
          "to_f" => ConcreteType.new("Float"),
          "length" => ConcreteType.new("Integer"),
          "size" => ConcreteType.new("Integer"),
          "empty?" => ConcreteType.new("Boolean"),
          "nil?" => ConcreteType.new("Boolean")
        }

        method_types[method.to_s]
      end

      def infer_binary_op(expr)
        left_type = infer_expression(expr.left)
        right_type = infer_expression(expr.right)

        case expr.operator
        when "+", "-", "*", "/", "%"
          # Numeric operations
          @solver.add_subtype(left_type, ConcreteType.new("Numeric"))
          @solver.add_subtype(right_type, ConcreteType.new("Numeric"))
          ConcreteType.new("Numeric")
        when "==", "!=", "<", ">", "<=", ">="
          ConcreteType.new("Boolean")
        when "&&", "||"
          ConcreteType.new("Boolean")
        else
          @solver.fresh_var("Op")
        end
      end

      def infer_array_literal(expr)
        if expr.elements.empty?
          ConcreteType.new("Array")
        else
          element_type = @solver.fresh_var("E")
          expr.elements.each do |elem|
            elem_type = infer_expression(elem)
            @solver.add_subtype(elem_type, element_type)
          end
          ConcreteType.new("Array")
        end
      end
    end

    #==========================================================================
    # DSL for building constraints
    #==========================================================================

    module DSL
      def var(name)
        Variable.new(name)
      end

      def type_var(name, bounds: nil)
        TypeVar.new(name, bounds: bounds)
      end

      def concrete(name)
        ConcreteType.new(name)
      end

      def subtype(sub, sup)
        Subtype.new(sub, sup)
      end

      def type_equal(left, right)
        TypeEqual.new(left, right)
      end

      def has_property(type, prop, prop_type)
        HasProperty.new(type, prop, prop_type)
      end

      def all(*constraints)
        constraints.reduce { |acc, c| acc & c }
      end

      def any(*constraints)
        constraints.reduce { |acc, c| acc | c }
      end
    end
  end
end
