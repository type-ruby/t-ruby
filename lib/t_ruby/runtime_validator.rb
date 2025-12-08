# frozen_string_literal: true

module TRuby
  # Configuration for runtime validation
  class ValidationConfig
    attr_accessor :validate_all, :validate_public_only, :raise_on_error
    attr_accessor :log_violations, :strict_mode

    def initialize
      @validate_all = true
      @validate_public_only = false
      @raise_on_error = true
      @log_violations = false
      @strict_mode = false
    end
  end

  # Generates runtime type validation code
  class RuntimeValidator
    attr_reader :config

    # Type mappings for runtime checks
    TYPE_CHECKS = {
      "String" => ".is_a?(String)",
      "Integer" => ".is_a?(Integer)",
      "Float" => ".is_a?(Float)",
      "Numeric" => ".is_a?(Numeric)",
      "Boolean" => " == true || %s == false",
      "Symbol" => ".is_a?(Symbol)",
      "Array" => ".is_a?(Array)",
      "Hash" => ".is_a?(Hash)",
      "nil" => ".nil?",
      "Object" => ".is_a?(Object)",
      "Class" => ".is_a?(Class)",
      "Module" => ".is_a?(Module)",
      "Proc" => ".is_a?(Proc)",
      "Regexp" => ".is_a?(Regexp)",
      "Range" => ".is_a?(Range)",
      "Time" => ".is_a?(Time)",
      "Date" => ".is_a?(Date)",
      "IO" => ".is_a?(IO)",
      "File" => ".is_a?(File)"
    }.freeze

    def initialize(config = nil)
      @config = config || ValidationConfig.new
    end

    # Generate validation code for a function
    def generate_function_validation(function_info)
      validations = []

      # Parameter validations
      function_info[:params].each do |param|
        next unless param[:type]

        validation = generate_param_validation(param[:name], param[:type])
        validations << validation if validation
      end

      # Return type validation (if specified)
      if function_info[:return_type]
        return_validation = generate_return_validation(function_info[:return_type])
        validations << return_validation if return_validation
      end

      validations
    end

    # Generate validation for a single parameter
    def generate_param_validation(param_name, type_annotation)
      check_code = generate_type_check(param_name, type_annotation)
      return nil unless check_code

      error_message = "TypeError: #{param_name} must be #{type_annotation}, got \#{#{param_name}.class}"

      if @config.raise_on_error
        "raise #{error_message.inspect.gsub('\#{', '#{')} unless #{check_code}"
      else
        "warn #{error_message.inspect.gsub('\#{', '#{')} unless #{check_code}"
      end
    end

    # Generate type check expression
    def generate_type_check(var_name, type_annotation)
      # Handle nil type
      return "#{var_name}.nil?" if type_annotation == "nil"

      # Handle union types
      if type_annotation.include?("|")
        return generate_union_check(var_name, type_annotation)
      end

      # Handle generic types
      if type_annotation.include?("<")
        return generate_generic_check(var_name, type_annotation)
      end

      # Handle intersection types
      if type_annotation.include?("&")
        return generate_intersection_check(var_name, type_annotation)
      end

      # Handle optional types (ending with ?)
      if type_annotation.end_with?("?")
        base_type = type_annotation[0..-2]
        base_check = generate_simple_type_check(var_name, base_type)
        return "(#{var_name}.nil? || #{base_check})"
      end

      # Simple type check
      generate_simple_type_check(var_name, type_annotation)
    end

    # Generate simple type check
    def generate_simple_type_check(var_name, type_name)
      if type_name == "Boolean"
        "(#{var_name} == true || #{var_name} == false)"
      elsif TYPE_CHECKS.key?(type_name)
        "#{var_name}#{TYPE_CHECKS[type_name]}"
      else
        # Custom type - use is_a? or respond_to?
        "#{var_name}.is_a?(#{type_name})"
      end
    end

    # Generate union type check
    def generate_union_check(var_name, union_type)
      types = union_type.split("|").map(&:strip)
      checks = types.map { |t| generate_type_check(var_name, t) }
      "(#{checks.join(' || ')})"
    end

    # Generate generic type check
    def generate_generic_check(var_name, generic_type)
      match = generic_type.match(/^(\w+)<(.+)>$/)
      return nil unless match

      container_type = match[1]
      element_type = match[2]

      case container_type
      when "Array"
        "#{var_name}.is_a?(Array) && #{var_name}.all? { |_e| #{generate_type_check('_e', element_type)} }"
      when "Hash"
        if element_type.include?(",")
          key_type, value_type = element_type.split(",").map(&:strip)
          "#{var_name}.is_a?(Hash) && #{var_name}.all? { |_k, _v| #{generate_type_check('_k', key_type)} && #{generate_type_check('_v', value_type)} }"
        else
          "#{var_name}.is_a?(Hash)"
        end
      when "Set"
        "#{var_name}.is_a?(Set) && #{var_name}.all? { |_e| #{generate_type_check('_e', element_type)} }"
      else
        # Generic with unknown container - just check container type
        "#{var_name}.is_a?(#{container_type})"
      end
    end

    # Generate intersection type check
    def generate_intersection_check(var_name, intersection_type)
      types = intersection_type.split("&").map(&:strip)
      checks = types.map { |t| generate_type_check(var_name, t) }
      "(#{checks.join(' && ')})"
    end

    # Generate return value validation wrapper
    def generate_return_validation(return_type)
      {
        type: :return,
        check: generate_type_check("_result", return_type),
        return_type: return_type
      }
    end

    # Transform source code to include runtime validations
    def transform(source, parse_result)
      lines = source.split("\n")
      output_lines = []
      in_function = false
      current_function = nil
      function_indent = 0

      parse_result[:functions].each do |func|
        @function_validations ||= {}
        @function_validations[func[:name]] = generate_function_validation(func)
      end

      lines.each_with_index do |line, idx|
        # Check for function definition
        if line.match?(/^\s*def\s+(\w+)/)
          match = line.match(/^(\s*)def\s+(\w+)/)
          function_indent = match[1].length
          function_name = match[2]

          # Add validation code after function definition
          output_lines << line

          if @function_validations && @function_validations[function_name]
            validations = @function_validations[function_name]
            param_validations = validations.select { |v| v.is_a?(String) }

            param_validations.each do |validation|
              output_lines << "#{' ' * (function_indent + 2)}#{validation}"
            end
          end

          in_function = true
          current_function = function_name
        elsif in_function && line.match?(/^\s*end\s*$/)
          # End of function
          in_function = false
          current_function = nil
          output_lines << line
        else
          output_lines << line
        end
      end

      output_lines.join("\n")
    end

    # Generate a validation module that can be included
    def generate_validation_module(functions)
      module_code = <<~RUBY
        # frozen_string_literal: true
        # Auto-generated runtime type validation module

        module TRubyValidation
          class TypeError < StandardError; end

          def self.validate_type(value, expected_type, param_name = "value")
      RUBY

      module_code += <<~RUBY
            case expected_type
            when "String"
              raise TypeError, "\#{param_name} must be String, got \#{value.class}" unless value.is_a?(String)
            when "Integer"
              raise TypeError, "\#{param_name} must be Integer, got \#{value.class}" unless value.is_a?(Integer)
            when "Float"
              raise TypeError, "\#{param_name} must be Float, got \#{value.class}" unless value.is_a?(Float)
            when "Boolean"
              raise TypeError, "\#{param_name} must be Boolean, got \#{value.class}" unless value == true || value == false
            when "Symbol"
              raise TypeError, "\#{param_name} must be Symbol, got \#{value.class}" unless value.is_a?(Symbol)
            when "Array"
              raise TypeError, "\#{param_name} must be Array, got \#{value.class}" unless value.is_a?(Array)
            when "Hash"
              raise TypeError, "\#{param_name} must be Hash, got \#{value.class}" unless value.is_a?(Hash)
            when "nil"
              raise TypeError, "\#{param_name} must be nil, got \#{value.class}" unless value.nil?
            else
              # Custom type check
              begin
                type_class = Object.const_get(expected_type)
                raise TypeError, "\#{param_name} must be \#{expected_type}, got \#{value.class}" unless value.is_a?(type_class)
              rescue NameError
                # Unknown type, skip validation
              end
            end
            true
          end
      RUBY

      # Generate validation methods for each function
      functions.each do |func|
        next if func[:params].empty? && !func[:return_type]

        method_name = "validate_#{func[:name]}_params"
        param_list = func[:params].map { |p| p[:name] }.join(", ")

        module_code += "\n  def self.#{method_name}(#{param_list})\n"

        func[:params].each do |param|
          next unless param[:type]
          module_code += "    validate_type(#{param[:name]}, #{param[:type].inspect}, #{param[:name].inspect})\n"
        end

        module_code += "    true\n  end\n"
      end

      module_code += "end\n"
      module_code
    end

    # Check if validation should be applied based on config
    def should_validate?(visibility)
      return true if @config.validate_all
      return visibility == :public if @config.validate_public_only
      false
    end
  end

  # Runtime type error
  class RuntimeTypeError < StandardError
    attr_reader :expected_type, :actual_type, :value, :location

    def initialize(message, expected_type: nil, actual_type: nil, value: nil, location: nil)
      super(message)
      @expected_type = expected_type
      @actual_type = actual_type
      @value = value
      @location = location
    end
  end

  # Mixin for adding runtime validation to classes
  module RuntimeTypeChecks
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def validate_types!
        @_validate_types = true
      end

      def skip_type_validation!
        @_validate_types = false
      end

      def type_validation_enabled?
        @_validate_types != false
      end
    end

    private

    def validate_param(value, expected_type, param_name)
      return true unless self.class.type_validation_enabled?

      validator = RuntimeValidator.new
      check_code = validator.generate_type_check("value", expected_type)

      # Evaluate the check
      unless eval(check_code)
        raise RuntimeTypeError.new(
          "#{param_name} must be #{expected_type}, got #{value.class}",
          expected_type: expected_type,
          actual_type: value.class.to_s,
          value: value
        )
      end

      true
    end

    def validate_return(value, expected_type)
      return value unless self.class.type_validation_enabled?

      validator = RuntimeValidator.new
      check_code = validator.generate_type_check("value", expected_type)

      unless eval(check_code)
        raise RuntimeTypeError.new(
          "Return value must be #{expected_type}, got #{value.class}",
          expected_type: expected_type,
          actual_type: value.class.to_s,
          value: value
        )
      end

      value
    end
  end
end
