# frozen_string_literal: true

module TRuby
  # Represents a type checking error
  class TypeCheckError
    attr_reader :message, :location, :expected, :actual, :suggestion

    def initialize(message:, location: nil, expected: nil, actual: nil, suggestion: nil)
      @message = message
      @location = location
      @expected = expected
      @actual = actual
      @suggestion = suggestion
    end

    def to_s
      parts = [@message]
      parts << "  Expected: #{@expected}" if @expected
      parts << "  Actual: #{@actual}" if @actual
      parts << "  Suggestion: #{@suggestion}" if @suggestion
      parts << "  at #{@location}" if @location
      parts.join("\n")
    end
  end

  # Type hierarchy for subtype checking
  class TypeHierarchy
    NUMERIC_TYPES = %w[Integer Float Numeric].freeze
    COLLECTION_TYPES = %w[Array Hash Set].freeze

    def initialize
      @subtypes = {
        "Integer" => ["Numeric", "Object"],
        "Float" => ["Numeric", "Object"],
        "Numeric" => ["Object"],
        "String" => ["Object"],
        "Symbol" => ["Object"],
        "Array" => ["Enumerable", "Object"],
        "Hash" => ["Enumerable", "Object"],
        "Set" => ["Enumerable", "Object"],
        "Boolean" => ["Object"],
        "nil" => ["Object"],
        "Object" => []
      }
    end

    def subtype_of?(subtype, supertype)
      return true if subtype == supertype
      return true if supertype == "Object"

      chain = @subtypes[subtype] || []
      return true if chain.include?(supertype)

      # Check transitive relationship
      chain.any? { |t| subtype_of?(t, supertype) }
    end

    def compatible?(type_a, type_b)
      subtype_of?(type_a, type_b) || subtype_of?(type_b, type_a)
    end

    def register_subtype(subtype, supertype)
      @subtypes[subtype] ||= []
      @subtypes[subtype] << supertype unless @subtypes[subtype].include?(supertype)
    end

    def common_supertype(type_a, type_b)
      return type_a if type_a == type_b
      return type_a if subtype_of?(type_b, type_a)
      return type_b if subtype_of?(type_a, type_b)

      # Find common ancestor
      chain_a = [type_a] + (@subtypes[type_a] || [])
      chain_b = [type_b] + (@subtypes[type_b] || [])

      common = chain_a & chain_b
      common.first || "Object"
    end
  end

  # Scope for tracking variable types in a block
  class TypeScope
    attr_reader :parent, :variables

    def initialize(parent = nil)
      @parent = parent
      @variables = {}
    end

    def define(name, type)
      @variables[name] = type
    end

    def lookup(name)
      @variables[name] || @parent&.lookup(name)
    end

    def child_scope
      TypeScope.new(self)
    end
  end

  # Flow-sensitive type tracking
  class FlowContext
    attr_reader :narrowed_types, :guard_conditions

    def initialize
      @narrowed_types = {}
      @guard_conditions = []
    end

    def narrow(variable, new_type)
      @narrowed_types[variable] = new_type
    end

    def get_narrowed_type(variable)
      @narrowed_types[variable]
    end

    def push_guard(condition)
      @guard_conditions.push(condition)
    end

    def pop_guard
      @guard_conditions.pop
    end

    def branch
      new_context = FlowContext.new
      @narrowed_types.each { |k, v| new_context.narrow(k, v) }
      new_context
    end

    def merge(other)
      # Merge two branches - types that are narrowed in both become union
      merged = FlowContext.new
      all_vars = @narrowed_types.keys | other.narrowed_types.keys

      all_vars.each do |var|
        type_a = @narrowed_types[var]
        type_b = other.narrowed_types[var]

        if type_a && type_b
          if type_a == type_b
            merged.narrow(var, type_a)
          else
            merged.narrow(var, "#{type_a} | #{type_b}")
          end
        elsif type_a || type_b
          merged.narrow(var, type_a || type_b)
        end
      end

      merged
    end
  end

  # Main type checker
  class TypeChecker
    attr_reader :errors, :warnings, :hierarchy, :inferencer

    def initialize
      @errors = []
      @warnings = []
      @hierarchy = TypeHierarchy.new
      @inferencer = TypeInferencer.new
      @function_signatures = {}
      @type_aliases = {}
      @current_scope = TypeScope.new
      @flow_context = FlowContext.new
    end

    # Register a function signature
    def register_function(name, params:, return_type:)
      @function_signatures[name] = {
        params: params,
        return_type: return_type
      }
    end

    # Register a type alias
    def register_alias(name, definition)
      @type_aliases[name] = definition
    end

    # Check a function call
    def check_call(function_name, arguments, location: nil)
      signature = @function_signatures[function_name]

      unless signature
        add_warning("Unknown function: #{function_name}", location)
        return nil
      end

      params = signature[:params]

      # Check argument count
      if arguments.length != params.length
        add_error(
          message: "Wrong number of arguments for #{function_name}",
          expected: "#{params.length} arguments",
          actual: "#{arguments.length} arguments",
          location: location
        )
        return nil
      end

      # Check each argument type
      params.each_with_index do |param, idx|
        next unless param[:type]

        arg = arguments[idx]
        arg_type = infer_type(arg)

        next unless arg_type

        unless type_compatible?(arg_type, param[:type])
          add_error(
            message: "Type mismatch in argument '#{param[:name]}' of #{function_name}",
            expected: param[:type],
            actual: arg_type,
            suggestion: suggest_conversion(arg_type, param[:type]),
            location: location
          )
        end
      end

      signature[:return_type]
    end

    # Check a return statement
    def check_return(value, expected_type, location: nil)
      return true unless expected_type

      actual_type = infer_type(value)
      return true unless actual_type

      unless type_compatible?(actual_type, expected_type)
        add_error(
          message: "Return type mismatch",
          expected: expected_type,
          actual: actual_type,
          suggestion: suggest_conversion(actual_type, expected_type),
          location: location
        )
        return false
      end

      true
    end

    # Check variable assignment
    def check_assignment(variable, value, declared_type: nil, location: nil)
      value_type = infer_type(value)

      if declared_type
        unless type_compatible?(value_type, declared_type)
          add_error(
            message: "Cannot assign #{value_type} to variable of type #{declared_type}",
            expected: declared_type,
            actual: value_type,
            location: location
          )
          return false
        end
      end

      @current_scope.define(variable, declared_type || value_type)
      true
    end

    # Check property access
    def check_property_access(receiver_type, property_name, location: nil)
      # Known properties for common types
      known_properties = {
        "String" => %w[length size empty? chars bytes],
        "Array" => %w[length size first last empty? count],
        "Hash" => %w[keys values size empty? length],
        "Integer" => %w[abs to_s to_f even? odd? positive? negative?],
        "Float" => %w[abs to_s to_i ceil floor round]
      }

      properties = known_properties[receiver_type]
      return nil unless properties

      unless properties.include?(property_name)
        add_warning("Property '#{property_name}' may not exist on type #{receiver_type}", location)
      end

      # Return expected type for known properties
      infer_property_type(receiver_type, property_name)
    end

    # Check operator usage
    def check_operator(left_type, operator, right_type, location: nil)
      # Arithmetic operators
      if %w[+ - * / %].include?(operator)
        if left_type == "String" && operator == "+"
          unless right_type == "String"
            add_error(
              message: "Cannot concatenate String with #{right_type}",
              expected: "String",
              actual: right_type,
              suggestion: "Use .to_s to convert to String",
              location: location
            )
          end
          return "String"
        end

        unless numeric_type?(left_type) && numeric_type?(right_type)
          add_error(
            message: "Operator '#{operator}' requires numeric operands",
            expected: "Numeric",
            actual: "#{left_type} #{operator} #{right_type}",
            location: location
          )
          return nil
        end

        # Result type depends on operands
        return "Float" if left_type == "Float" || right_type == "Float"
        return "Integer"
      end

      # Comparison operators
      if %w[== != < > <= >=].include?(operator)
        return "Boolean"
      end

      # Logical operators
      if %w[&& ||].include?(operator)
        return right_type # Short-circuit returns right operand type
      end

      nil
    end

    # Handle conditional type narrowing
    def narrow_in_conditional(condition, then_scope, else_scope = nil)
      # Parse type guards from condition
      if condition.match?(/(\w+)\.is_a\?\((\w+)\)/)
        match = condition.match(/(\w+)\.is_a\?\((\w+)\)/)
        var = match[1]
        type = match[2]

        # In then branch, variable is narrowed to the type
        then_scope.narrow(var, type)

        # In else branch, variable is NOT that type (can't narrow further without more info)
      end

      if condition.match?(/(\w+)\.nil\?/)
        match = condition.match(/(\w+)\.nil\?/)
        var = match[1]

        then_scope.narrow(var, "nil")
        # In else branch, variable is not nil
        else_scope&.narrow(var, remove_nil_from_type(@current_scope.lookup(var) || "Object"))
      end

      if condition.match?(/!(\w+)\.nil\?/)
        match = condition.match(/!(\w+)\.nil\?/)
        var = match[1]

        # Variable is not nil in then branch
        then_scope.narrow(var, remove_nil_from_type(@current_scope.lookup(var) || "Object"))
        else_scope&.narrow(var, "nil")
      end
    end

    # Check a complete function
    def check_function(function_info, body_lines)
      @current_scope = TypeScope.new

      # Register parameters in scope
      function_info[:params].each do |param|
        @current_scope.define(param[:name], param[:type] || "Object")
      end

      # Register function signature
      register_function(
        function_info[:name],
        params: function_info[:params],
        return_type: function_info[:return_type]
      )

      # Check body (simplified - real implementation would parse AST)
      body_lines.each_with_index do |line, idx|
        check_statement(line, location: "line #{idx + 1}")
      end
    end

    # Check a statement
    def check_statement(line, location: nil)
      line = line.strip

      # Return statement
      if line.match?(/^return\s+(.+)/)
        match = line.match(/^return\s+(.+)/)
        # Would need current function context for proper checking
        return
      end

      # Assignment
      if line.match?(/^(\w+)\s*=\s*(.+)/)
        match = line.match(/^(\w+)\s*=\s*(.+)/)
        check_assignment(match[1], match[2], location: location)
        return
      end

      # Method call
      if line.match?(/(\w+)\(([^)]*)\)/)
        match = line.match(/(\w+)\(([^)]*)\)/)
        args = match[2].split(",").map(&:strip)
        check_call(match[1], args, location: location)
      end
    end

    # Resolve type alias
    def resolve_type(type_name)
      @type_aliases[type_name] || type_name
    end

    # Clear all state
    def reset
      @errors.clear
      @warnings.clear
      @function_signatures.clear
      @type_aliases.clear
      @current_scope = TypeScope.new
      @flow_context = FlowContext.new
    end

    # Get all diagnostics
    def diagnostics
      @errors.map { |e| { type: :error, message: e.to_s } } +
        @warnings.map { |w| { type: :warning, message: w } }
    end

    private

    def add_error(message:, expected: nil, actual: nil, suggestion: nil, location: nil)
      @errors << TypeCheckError.new(
        message: message,
        expected: expected,
        actual: actual,
        suggestion: suggestion,
        location: location
      )
    end

    def add_warning(message, location = nil)
      full_message = location ? "#{message} at #{location}" : message
      @warnings << full_message
    end

    def infer_type(expression)
      result = @inferencer.infer_expression_type(expression)
      result&.type
    end

    def type_compatible?(actual, expected)
      return true if actual.nil? || expected.nil?

      actual = resolve_type(actual)
      expected = resolve_type(expected)

      return true if actual == expected

      # Handle union types in expected
      if expected.include?("|")
        types = expected.split("|").map(&:strip)
        return types.any? { |t| type_compatible?(actual, t) }
      end

      # Handle union types in actual
      if actual.include?("|")
        types = actual.split("|").map(&:strip)
        return types.all? { |t| type_compatible?(t, expected) }
      end

      # Check hierarchy
      @hierarchy.subtype_of?(actual, expected)
    end

    def numeric_type?(type)
      %w[Integer Float Numeric].include?(type)
    end

    def suggest_conversion(from_type, to_type)
      conversions = {
        ["Integer", "String"] => "Use .to_s to convert to String",
        ["Float", "String"] => "Use .to_s to convert to String",
        ["String", "Integer"] => "Use .to_i to convert to Integer",
        ["String", "Float"] => "Use .to_f to convert to Float",
        ["Integer", "Float"] => "Use .to_f to convert to Float",
        ["Float", "Integer"] => "Use .to_i to convert to Integer (may lose precision)",
        ["Symbol", "String"] => "Use .to_s to convert to String",
        ["String", "Symbol"] => "Use .to_sym to convert to Symbol"
      }

      conversions[[from_type, to_type]]
    end

    def infer_property_type(receiver_type, property)
      property_types = {
        ["String", "length"] => "Integer",
        ["String", "size"] => "Integer",
        ["String", "empty?"] => "Boolean",
        ["String", "chars"] => "Array<String>",
        ["Array", "length"] => "Integer",
        ["Array", "size"] => "Integer",
        ["Array", "empty?"] => "Boolean",
        ["Array", "first"] => nil, # Depends on element type
        ["Array", "last"] => nil,
        ["Hash", "keys"] => "Array",
        ["Hash", "values"] => "Array",
        ["Hash", "size"] => "Integer",
        ["Integer", "abs"] => "Integer",
        ["Integer", "to_s"] => "String",
        ["Float", "abs"] => "Float",
        ["Float", "to_i"] => "Integer"
      }

      property_types[[receiver_type, property]]
    end

    def remove_nil_from_type(type)
      return "Object" if type == "nil"

      if type.include?("|")
        types = type.split("|").map(&:strip).reject { |t| t == "nil" }
        return types.length == 1 ? types.first : types.join(" | ")
      end

      type
    end
  end
end
