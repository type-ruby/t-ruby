# frozen_string_literal: true

module TRuby
  class ErrorHandler
    VALID_TYPES = %w[String Integer Boolean Array Hash Symbol void nil].freeze

    def initialize(source)
      @source = source
      @lines = source.split("\n")
      @errors = []
      @functions = {}
    end

    def check
      @errors = []
      @functions = {}

      check_syntax_errors
      check_type_validation
      check_duplicate_definitions

      @errors
    end

    private

    def check_syntax_errors
      @lines.each_with_index do |line, idx|
        next unless line.match?(/^\s*def\s+/)

        # Check for unclosed parenthesis
        if line.match?(/def\s+\w+\([^)]*$/) && !@lines[idx + 1..].any? { |l| l.match?(/\)/) }
          @errors << "Line #{idx + 1}: Potential unclosed parenthesis in function definition"
        end

        # Check for invalid parameter syntax (e.g., "def test(: String)")
        if line.match?(/def\s+\w+\(\s*:\s*\w+/)
          @errors << "Line #{idx + 1}: Invalid parameter syntax - parameter name missing"
        end
      end
    end

    def check_type_validation
      @lines.each_with_index do |line, idx|
        next unless line.match?(/^\s*def\s+/)

        # Extract types from function definition
        match = line.match(/def\s+\w+\s*\((.*?)\)\s*(?::\s*(\w+))?/)
        next unless match

        params_str = match[1]
        return_type = match[2]

        # Check return type
        if return_type && !VALID_TYPES.include?(return_type)
          @errors << "Line #{idx + 1}: Unknown return type '#{return_type}'"
        end

        # Check parameter types
        check_parameter_types(params_str, idx)
      end
    end

    def check_parameter_types(params_str, line_idx)
      return if params_str.empty?

      param_list = params_str.split(",").map(&:strip)
      param_list.each do |param|
        match = param.match(/^(\w+)(?::\s*(\w+))?$/)
        next unless match

        param_type = match[2]
        next unless param_type
        next if VALID_TYPES.include?(param_type)

        @errors << "Line #{line_idx + 1}: Unknown parameter type '#{param_type}'"
      end
    end

    def check_duplicate_definitions
      @lines.each_with_index do |line, idx|
        next unless line.match?(/^\s*def\s+(\w+)/)

        func_name = line.match(/def\s+(\w+)/)[1]

        if @functions[func_name]
          @errors << "Line #{idx + 1}: Function '#{func_name}' is already defined at line #{@functions[func_name]}"
        else
          @functions[func_name] = idx + 1
        end
      end
    end
  end
end
