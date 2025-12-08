# frozen_string_literal: true

module TRuby
  # Represents a type constraint
  class Constraint
    attr_reader :type, :condition, :message

    def initialize(type:, condition:, message: nil)
      @type = type
      @condition = condition
      @message = message
    end

    def to_s
      "#{@type} where #{@condition}"
    end
  end

  # Bounds constraint: T <: BaseType (T is subtype of BaseType)
  class BoundsConstraint < Constraint
    attr_reader :subtype, :supertype

    def initialize(subtype:, supertype:)
      @subtype = subtype
      @supertype = supertype
      super(type: :bounds, condition: "#{subtype} <: #{supertype}")
    end

    def satisfied?(type_hierarchy)
      type_hierarchy.subtype_of?(@subtype, @supertype)
    end
  end

  # Equality constraint: T == SpecificType
  class EqualityConstraint < Constraint
    attr_reader :left_type, :right_type

    def initialize(left_type:, right_type:)
      @left_type = left_type
      @right_type = right_type
      super(type: :equality, condition: "#{left_type} == #{right_type}")
    end

    def satisfied?(value_type)
      @left_type == value_type || @right_type == value_type
    end
  end

  # Numeric range constraint: Integer where min..max
  class NumericRangeConstraint < Constraint
    attr_reader :base_type, :min, :max

    def initialize(base_type:, min: nil, max: nil)
      @base_type = base_type
      @min = min
      @max = max
      range_str = build_range_string
      super(type: :numeric_range, condition: range_str)
    end

    def satisfied?(value)
      return false unless value.is_a?(Numeric)
      return false if @min && value < @min
      return false if @max && value > @max
      true
    end

    def validation_code(var_name)
      conditions = []
      conditions << "#{var_name} >= #{@min}" if @min
      conditions << "#{var_name} <= #{@max}" if @max
      conditions.join(" && ")
    end

    private

    def build_range_string
      return "#{@min}..#{@max}" if @min && @max
      return ">= #{@min}" if @min
      return "<= #{@max}" if @max
      ""
    end
  end

  # Pattern constraint for strings: String where /pattern/
  class PatternConstraint < Constraint
    attr_reader :base_type, :pattern

    def initialize(base_type:, pattern:)
      @base_type = base_type
      @pattern = pattern.is_a?(Regexp) ? pattern : Regexp.new(pattern)
      super(type: :pattern, condition: "=~ #{@pattern.inspect}")
    end

    def satisfied?(value)
      return false unless value.is_a?(String)
      @pattern.match?(value)
    end

    def validation_code(var_name)
      "#{@pattern.inspect}.match?(#{var_name})"
    end
  end

  # Predicate constraint: Type where predicate_method
  class PredicateConstraint < Constraint
    attr_reader :base_type, :predicate

    def initialize(base_type:, predicate:)
      @base_type = base_type
      @predicate = predicate
      super(type: :predicate, condition: predicate.to_s)
    end

    def satisfied?(value)
      if @predicate.is_a?(Proc)
        @predicate.call(value)
      elsif @predicate.is_a?(Symbol)
        value.respond_to?(@predicate) && value.send(@predicate)
      else
        false
      end
    end

    def validation_code(var_name)
      if @predicate.is_a?(Symbol)
        "#{var_name}.#{@predicate}"
      else
        "true" # Proc constraints require runtime evaluation
      end
    end
  end

  # Length constraint for strings/arrays: Type where length condition
  class LengthConstraint < Constraint
    attr_reader :base_type, :min_length, :max_length, :exact_length

    def initialize(base_type:, min_length: nil, max_length: nil, exact_length: nil)
      @base_type = base_type
      @min_length = min_length
      @max_length = max_length
      @exact_length = exact_length
      super(type: :length, condition: build_condition)
    end

    def satisfied?(value)
      return false unless value.respond_to?(:length)
      len = value.length
      return len == @exact_length if @exact_length
      return false if @min_length && len < @min_length
      return false if @max_length && len > @max_length
      true
    end

    def validation_code(var_name)
      conditions = []
      if @exact_length
        conditions << "#{var_name}.length == #{@exact_length}"
      else
        conditions << "#{var_name}.length >= #{@min_length}" if @min_length
        conditions << "#{var_name}.length <= #{@max_length}" if @max_length
      end
      conditions.join(" && ")
    end

    private

    def build_condition
      return "length == #{@exact_length}" if @exact_length
      parts = []
      parts << "length >= #{@min_length}" if @min_length
      parts << "length <= #{@max_length}" if @max_length
      parts.join(", ")
    end
  end

  # Main constraint checker class
  class ConstraintChecker
    attr_reader :constraints, :errors

    def initialize
      @constraints = {}
      @errors = []
    end

    # Register a constrained type
    def register(name, base_type:, constraints: [])
      @constraints[name] = {
        base_type: base_type,
        constraints: constraints
      }
    end

    # Parse constraint syntax from source
    def parse_constraint(definition)
      # Match: type Name <: BaseType where condition
      if definition.match?(/^(\w+)\s*<:\s*(\w+)\s*where\s*(.+)$/)
        match = definition.match(/^(\w+)\s*<:\s*(\w+)\s*where\s*(.+)$/)
        name = match[1]
        base_type = match[2]
        condition = match[3].strip

        constraints = parse_condition(base_type, condition)
        return { name: name, base_type: base_type, constraints: constraints }
      end

      # Match: type Name <: BaseType (bounds only)
      if definition.match?(/^(\w+)\s*<:\s*(\w+)\s*$/)
        match = definition.match(/^(\w+)\s*<:\s*(\w+)\s*$/)
        name = match[1]
        base_type = match[2]

        return {
          name: name,
          base_type: base_type,
          constraints: [BoundsConstraint.new(subtype: name, supertype: base_type)]
        }
      end

      # Match: type Name = BaseType where condition
      if definition.match?(/^(\w+)\s*=\s*(\w+)\s*where\s*(.+)$/)
        match = definition.match(/^(\w+)\s*=\s*(\w+)\s*where\s*(.+)$/)
        name = match[1]
        base_type = match[2]
        condition = match[3].strip

        constraints = parse_condition(base_type, condition)
        return { name: name, base_type: base_type, constraints: constraints }
      end

      nil
    end

    # Validate a value against a constrained type
    def validate(type_name, value)
      @errors = []

      unless @constraints.key?(type_name)
        @errors << "Unknown constrained type: #{type_name}"
        return false
      end

      type_info = @constraints[type_name]

      # Check base type
      unless matches_base_type?(value, type_info[:base_type])
        @errors << "Value #{value.inspect} does not match base type #{type_info[:base_type]}"
        return false
      end

      # Check all constraints
      type_info[:constraints].each do |constraint|
        unless constraint.satisfied?(value)
          @errors << "Constraint violation: #{constraint.condition}"
          return false
        end
      end

      true
    end

    # Generate validation code for runtime checking
    def generate_validation_code(type_name, var_name)
      return nil unless @constraints.key?(type_name)

      type_info = @constraints[type_name]
      conditions = []

      # Base type check
      case type_info[:base_type]
      when "Integer"
        conditions << "#{var_name}.is_a?(Integer)"
      when "String"
        conditions << "#{var_name}.is_a?(String)"
      when "Float"
        conditions << "#{var_name}.is_a?(Float)"
      when "Numeric"
        conditions << "#{var_name}.is_a?(Numeric)"
      when "Array"
        conditions << "#{var_name}.is_a?(Array)"
      end

      # Constraint checks
      type_info[:constraints].each do |constraint|
        if constraint.respond_to?(:validation_code)
          code = constraint.validation_code(var_name)
          conditions << code unless code.empty?
        end
      end

      conditions.join(" && ")
    end

    private

    def parse_condition(base_type, condition)
      constraints = []

      # Numeric comparison: > N, < N, >= N, <= N
      if condition.match?(/^([<>]=?)\s*(\d+(?:\.\d+)?)$/)
        match = condition.match(/^([<>]=?)\s*(\d+(?:\.\d+)?)$/)
        op = match[1]
        value = match[2].include?(".") ? match[2].to_f : match[2].to_i

        case op
        when ">"
          constraints << NumericRangeConstraint.new(base_type: base_type, min: value + 1)
        when ">="
          constraints << NumericRangeConstraint.new(base_type: base_type, min: value)
        when "<"
          constraints << NumericRangeConstraint.new(base_type: base_type, max: value - 1)
        when "<="
          constraints << NumericRangeConstraint.new(base_type: base_type, max: value)
        end
      end

      # Range: min..max
      if condition.match?(/^(\d+)\.\.(\d+)$/)
        match = condition.match(/^(\d+)\.\.(\d+)$/)
        constraints << NumericRangeConstraint.new(
          base_type: base_type,
          min: match[1].to_i,
          max: match[2].to_i
        )
      end

      # Pattern: /regex/
      if condition.match?(/^\/(.+)\/$/)
        match = condition.match(/^\/(.+)\/$/)
        constraints << PatternConstraint.new(base_type: base_type, pattern: match[1])
      end

      # Length constraint: length > N, length == N, etc.
      if condition.match?(/^length\s*([<>=]+)\s*(\d+)$/)
        match = condition.match(/^length\s*([<>=]+)\s*(\d+)$/)
        op = match[1]
        value = match[2].to_i

        case op
        when "=="
          constraints << LengthConstraint.new(base_type: base_type, exact_length: value)
        when ">="
          constraints << LengthConstraint.new(base_type: base_type, min_length: value)
        when "<="
          constraints << LengthConstraint.new(base_type: base_type, max_length: value)
        when ">"
          constraints << LengthConstraint.new(base_type: base_type, min_length: value + 1)
        when "<"
          constraints << LengthConstraint.new(base_type: base_type, max_length: value - 1)
        end
      end

      # Predicate: positive?, negative?, empty?, etc.
      if condition.match?(/^(\w+)\?$/)
        match = condition.match(/^(\w+)\?$/)
        constraints << PredicateConstraint.new(base_type: base_type, predicate: "#{match[1]}?".to_sym)
      end

      constraints
    end

    def matches_base_type?(value, type_name)
      case type_name
      when "Integer" then value.is_a?(Integer)
      when "String" then value.is_a?(String)
      when "Float" then value.is_a?(Float)
      when "Numeric" then value.is_a?(Numeric)
      when "Array" then value.is_a?(Array)
      when "Hash" then value.is_a?(Hash)
      when "Boolean" then value == true || value == false
      when "Symbol" then value.is_a?(Symbol)
      else true # Unknown types pass through
      end
    end
  end

  # Constrained type registry for managing type constraints
  class ConstrainedTypeRegistry
    attr_reader :types

    def initialize
      @types = {}
      @checker = ConstraintChecker.new
    end

    # Register a constrained type from parsed definition
    def register(name, base_type:, constraints: [])
      @types[name] = {
        base_type: base_type,
        constraints: constraints,
        defined_at: caller_locations(1, 1).first
      }
      @checker.register(name, base_type: base_type, constraints: constraints)
    end

    # Parse and register from source line
    def register_from_source(line)
      result = @checker.parse_constraint(line)
      return false unless result

      register(result[:name], base_type: result[:base_type], constraints: result[:constraints])
      true
    end

    # Check if a type is registered
    def registered?(name)
      @types.key?(name)
    end

    # Get type info
    def get(name)
      @types[name]
    end

    # Validate value against type
    def validate(type_name, value)
      @checker.validate(type_name, value)
    end

    # Get validation errors
    def errors
      @checker.errors
    end

    # Generate validation code
    def validation_code(type_name, var_name)
      @checker.generate_validation_code(type_name, var_name)
    end

    # List all registered types
    def list
      @types.keys
    end

    # Clear all registrations
    def clear
      @types.clear
      @checker = ConstraintChecker.new
    end
  end
end
