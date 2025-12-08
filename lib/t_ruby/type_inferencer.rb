# frozen_string_literal: true

module TRuby
  # Represents an inferred type with confidence score
  class InferredType
    attr_reader :type, :confidence, :source, :location

    # Confidence levels
    HIGH = 1.0
    MEDIUM = 0.7
    LOW = 0.4

    def initialize(type:, confidence: HIGH, source: :unknown, location: nil)
      @type = type
      @confidence = confidence
      @source = source
      @location = location
    end

    def to_s
      @type
    end

    def high_confidence?
      @confidence >= HIGH
    end

    def medium_confidence?
      @confidence >= MEDIUM && @confidence < HIGH
    end

    def low_confidence?
      @confidence < MEDIUM
    end
  end

  # Type inference engine
  class TypeInferencer
    attr_reader :inferred_types, :warnings

    # Literal type patterns
    LITERAL_PATTERNS = {
      # String literals
      /^".*"$/ => "String",
      /^'.*'$/ => "String",
      # Integer literals
      /^-?\d+$/ => "Integer",
      /^0x[0-9a-fA-F]+$/ => "Integer",
      /^0b[01]+$/ => "Integer",
      /^0o[0-7]+$/ => "Integer",
      # Float literals
      /^-?\d+\.\d+$/ => "Float",
      /^-?\d+e[+-]?\d+$/i => "Float",
      # Boolean literals
      /^true$/ => "Boolean",
      /^false$/ => "Boolean",
      # Nil literal
      /^nil$/ => "nil",
      # Symbol literals
      /^:\w+$/ => "Symbol",
      # Array literals
      /^\[.*\]$/ => "Array",
      # Hash literals
      /^\{.*\}$/ => "Hash",
      # Regex literals
      /^\/.*\/$/ => "Regexp"
    }.freeze

    # Method return type patterns
    METHOD_RETURN_TYPES = {
      # String methods
      "to_s" => "String",
      "upcase" => "String",
      "downcase" => "String",
      "strip" => "String",
      "chomp" => "String",
      "reverse" => "String",
      "capitalize" => "String",
      "gsub" => "String",
      "sub" => "String",
      "chars" => "Array<String>",
      "split" => "Array<String>",
      "lines" => "Array<String>",
      "bytes" => "Array<Integer>",
      # Integer/Numeric methods
      "to_i" => "Integer",
      "to_int" => "Integer",
      "abs" => "Integer",
      "ceil" => "Integer",
      "floor" => "Integer",
      "round" => "Integer",
      "to_f" => "Float",
      # Array methods
      "length" => "Integer",
      "size" => "Integer",
      "count" => "Integer",
      "first" => nil, # Depends on array type
      "last" => nil,
      "empty?" => "Boolean",
      "any?" => "Boolean",
      "all?" => "Boolean",
      "none?" => "Boolean",
      "include?" => "Boolean",
      "compact" => nil,
      "flatten" => "Array",
      "uniq" => nil,
      "sort" => nil,
      "map" => "Array",
      "select" => "Array",
      "reject" => "Array",
      "reduce" => nil,
      # Hash methods
      "keys" => "Array",
      "values" => "Array",
      "merge" => "Hash",
      "key?" => "Boolean",
      "has_key?" => "Boolean",
      "value?" => "Boolean",
      "has_value?" => "Boolean",
      # Object methods
      "class" => "Class",
      "object_id" => "Integer",
      "hash" => "Integer",
      "frozen?" => "Boolean",
      "nil?" => "Boolean",
      "is_a?" => "Boolean",
      "kind_of?" => "Boolean",
      "instance_of?" => "Boolean",
      "respond_to?" => "Boolean",
      "eql?" => "Boolean",
      "equal?" => "Boolean",
      "inspect" => "String",
      "dup" => nil,
      "clone" => nil
    }.freeze

    # Operator return types
    OPERATOR_TYPES = {
      # Arithmetic
      "+" => :numeric_or_string,
      "-" => :numeric,
      "*" => :numeric_or_string,
      "/" => :numeric,
      "%" => :numeric,
      "**" => :numeric,
      # Comparison
      "==" => "Boolean",
      "!=" => "Boolean",
      "<" => "Boolean",
      ">" => "Boolean",
      "<=" => "Boolean",
      ">=" => "Boolean",
      "<=>" => "Integer",
      # Logical
      "&&" => :propagate,
      "||" => :propagate,
      "!" => "Boolean",
      # Bitwise
      "&" => "Integer",
      "|" => "Integer",
      "^" => "Integer",
      "~" => "Integer",
      "<<" => "Integer",
      ">>" => "Integer"
    }.freeze

    def initialize
      @inferred_types = {}
      @warnings = []
      @function_contexts = {}
      @variable_types = {}
    end

    # Infer type from a literal expression
    def infer_literal(expression)
      expr = expression.to_s.strip

      LITERAL_PATTERNS.each do |pattern, type|
        if expr.match?(pattern)
          return InferredType.new(
            type: type,
            confidence: InferredType::HIGH,
            source: :literal
          )
        end
      end

      nil
    end

    # Infer type from method call
    def infer_method_call(receiver_type, method_name)
      return_type = METHOD_RETURN_TYPES[method_name.to_s]

      if return_type
        return InferredType.new(
          type: return_type,
          confidence: InferredType::HIGH,
          source: :method_call
        )
      end

      # Try to infer from receiver type and method
      inferred = infer_from_receiver(receiver_type, method_name)
      return inferred if inferred

      nil
    end

    # Infer return type from function body
    def infer_return_type(function_body)
      return_statements = extract_return_statements(function_body)

      if return_statements.empty?
        # Implicit nil return
        return InferredType.new(
          type: "nil",
          confidence: InferredType::MEDIUM,
          source: :implicit_return
        )
      end

      types = return_statements.map do |stmt|
        infer_expression_type(stmt[:value])
      end.compact

      if types.empty?
        return nil
      end

      if types.uniq.length == 1
        # All returns have same type
        return InferredType.new(
          type: types.first.type,
          confidence: InferredType::HIGH,
          source: :return_analysis
        )
      end

      # Multiple return types - create union
      unique_types = types.map(&:type).uniq
      union_type = unique_types.join(" | ")

      InferredType.new(
        type: union_type,
        confidence: InferredType::MEDIUM,
        source: :return_analysis
      )
    end

    # Infer parameter types from usage patterns
    def infer_parameter_types(function_body, parameters)
      inferred_params = {}

      parameters.each do |param|
        param_name = param[:name]
        usages = find_parameter_usages(function_body, param_name)
        inferred_type = infer_from_usages(usages)

        if inferred_type
          inferred_params[param_name] = inferred_type
        end
      end

      inferred_params
    end

    # Infer generic type parameters
    def infer_generic_params(call_arguments, function_params)
      generic_bindings = {}

      function_params.each_with_index do |param, idx|
        next unless param[:type]&.include?("<")
        next unless call_arguments[idx]

        arg_type = infer_expression_type(call_arguments[idx])
        next unless arg_type

        # Extract generic parameter from function param type
        if param[:type].match?(/^(\w+)<(\w+)>$/)
          match = param[:type].match(/^(\w+)<(\w+)>$/)
          generic_name = match[2]

          # If arg type is concrete, bind it
          if arg_type.type.match?(/^(\w+)<(\w+)>$/)
            arg_match = arg_type.type.match(/^(\w+)<(\w+)>$/)
            generic_bindings[generic_name] = arg_match[2]
          end
        end
      end

      generic_bindings
    end

    # Infer type narrowing in conditionals
    def infer_narrowed_type(variable, condition)
      # Type guard patterns
      if condition.match?(/#{variable}\.is_a\?\((\w+)\)/)
        match = condition.match(/#{variable}\.is_a\?\((\w+)\)/)
        return InferredType.new(
          type: match[1],
          confidence: InferredType::HIGH,
          source: :type_guard
        )
      end

      if condition.match?(/#{variable}\.nil\?/)
        return InferredType.new(
          type: "nil",
          confidence: InferredType::HIGH,
          source: :nil_check
        )
      end

      if condition.match?(/#{variable}\.respond_to\?\(:(\w+)\)/)
        # Can't determine exact type, but know it has the method
        return nil
      end

      nil
    end

    # Infer type of an expression
    def infer_expression_type(expression)
      expr = expression.to_s.strip

      # Try literal inference first
      literal_type = infer_literal(expr)
      return literal_type if literal_type

      # Method call inference
      if expr.match?(/\.(\w+)(?:\(.*\))?$/)
        match = expr.match(/(.+)\.(\w+)(?:\(.*\))?$/)
        if match
          receiver = match[1]
          method = match[2]
          receiver_type = infer_expression_type(receiver)
          return infer_method_call(receiver_type&.type, method)
        end
      end

      # Variable reference - check recorded types
      if @variable_types[expr]
        return @variable_types[expr]
      end

      # Operator inference
      OPERATOR_TYPES.each do |op, result_type|
        if expr.include?(" #{op} ")
          return infer_operator_result(expr, op, result_type)
        end
      end

      # Array construction
      if expr.start_with?("[") && expr.end_with?("]")
        return infer_array_type(expr)
      end

      # Hash construction
      if expr.start_with?("{") && expr.end_with?("}")
        return InferredType.new(
          type: "Hash",
          confidence: InferredType::HIGH,
          source: :literal
        )
      end

      nil
    end

    # Record a variable's type for later inference
    def record_variable_type(name, type)
      @variable_types[name] = type
    end

    # Get recorded variable type
    def get_variable_type(name)
      @variable_types[name]
    end

    # Add a warning about ambiguous inference
    def add_warning(message, location: nil)
      @warnings << { message: message, location: location }
    end

    # Clear all state
    def reset
      @inferred_types.clear
      @warnings.clear
      @function_contexts.clear
      @variable_types.clear
    end

    private

    def extract_return_statements(body)
      statements = []
      lines = body.split("\n")

      lines.each_with_index do |line, idx|
        # Explicit return
        if line.match?(/^\s*return\s+(.+)/)
          match = line.match(/^\s*return\s+(.+)/)
          statements << { type: :explicit, value: match[1].strip, line: idx + 1 }
        end

        # Last expression (implicit return)
        # This is simplified - real implementation would need full parsing
      end

      statements
    end

    def find_parameter_usages(body, param_name)
      usages = []
      lines = body.split("\n")

      lines.each_with_index do |line, idx|
        # Method call on parameter
        if line.match?(/#{param_name}\.(\w+)/)
          matches = line.scan(/#{param_name}\.(\w+)/)
          matches.each do |match|
            usages << { type: :method_call, method: match[0], line: idx + 1 }
          end
        end

        # Arithmetic operation
        if line.match?(/#{param_name}\s*[+\-*\/%]/)
          usages << { type: :arithmetic, line: idx + 1 }
        end

        # Comparison
        if line.match?(/#{param_name}\s*[<>=!]=?/)
          usages << { type: :comparison, line: idx + 1 }
        end

        # String interpolation
        if line.match?(/#\{#{param_name}\}/)
          usages << { type: :string_interpolation, line: idx + 1 }
        end
      end

      usages
    end

    def infer_from_usages(usages)
      return nil if usages.empty?

      type_hints = []

      usages.each do |usage|
        case usage[:type]
        when :arithmetic
          type_hints << "Numeric"
        when :method_call
          method_type = infer_type_from_method(usage[:method])
          type_hints << method_type if method_type
        when :string_interpolation
          # Could be any type (calls to_s)
        when :comparison
          # Most types support comparison
        end
      end

      return nil if type_hints.empty?

      # Find most specific type
      most_common = type_hints.group_by(&:itself)
                              .max_by { |_, v| v.length }
                              &.first

      if most_common
        InferredType.new(
          type: most_common,
          confidence: InferredType::MEDIUM,
          source: :usage_analysis
        )
      else
        nil
      end
    end

    def infer_type_from_method(method_name)
      # Methods that suggest String type
      string_methods = %w[upcase downcase strip chomp split chars]
      return "String" if string_methods.include?(method_name)

      # Methods that suggest Array type
      array_methods = %w[each map select reject push pop shift unshift first last]
      return "Array" if array_methods.include?(method_name)

      # Methods that suggest Hash type
      hash_methods = %w[keys values merge fetch]
      return "Hash" if hash_methods.include?(method_name)

      # Methods that suggest Numeric type
      numeric_methods = %w[abs ceil floor round to_i to_f times upto downto]
      return "Numeric" if numeric_methods.include?(method_name)

      nil
    end

    def infer_from_receiver(receiver_type, method_name)
      return nil unless receiver_type

      case receiver_type
      when "String"
        case method_name.to_s
        when "length", "size" then "Integer"
        when "chars", "split", "lines" then "Array<String>"
        when /^[a-z]/ then "String" # Most String methods return String
        end
      when "Array"
        case method_name.to_s
        when "length", "size", "count" then "Integer"
        when "first", "last" then nil # Depends on element type
        when "join" then "String"
        end
      when "Integer", "Float", "Numeric"
        case method_name.to_s
        when "to_s" then "String"
        when "to_i" then "Integer"
        when "to_f" then "Float"
        when "abs", "ceil", "floor" then receiver_type
        end
      end
    end

    def infer_operator_result(expr, operator, result_type)
      case result_type
      when "Boolean"
        InferredType.new(type: "Boolean", confidence: InferredType::HIGH, source: :operator)
      when "Integer"
        InferredType.new(type: "Integer", confidence: InferredType::HIGH, source: :operator)
      when :numeric
        # Check operand types
        InferredType.new(type: "Numeric", confidence: InferredType::MEDIUM, source: :operator)
      when :numeric_or_string
        # Could be numeric or string concatenation
        InferredType.new(type: "Numeric | String", confidence: InferredType::LOW, source: :operator)
      when :propagate
        # Type propagates from operands
        nil
      else
        nil
      end
    end

    def infer_array_type(expr)
      # Remove brackets
      content = expr[1..-2].strip
      return InferredType.new(type: "Array", confidence: InferredType::HIGH, source: :literal) if content.empty?

      # Try to infer element types
      elements = split_array_elements(content)
      element_types = elements.map { |e| infer_expression_type(e)&.type }.compact.uniq

      if element_types.length == 1
        InferredType.new(
          type: "Array<#{element_types.first}>",
          confidence: InferredType::HIGH,
          source: :literal
        )
      elsif element_types.length > 1
        InferredType.new(
          type: "Array<#{element_types.join(' | ')}>",
          confidence: InferredType::MEDIUM,
          source: :literal
        )
      else
        InferredType.new(type: "Array", confidence: InferredType::HIGH, source: :literal)
      end
    end

    def split_array_elements(content)
      # Simple split by comma (doesn't handle nested structures well)
      content.split(",").map(&:strip)
    end
  end
end
