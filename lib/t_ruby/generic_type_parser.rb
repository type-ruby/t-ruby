# frozen_string_literal: true

module TRuby
  class GenericTypeParser
    def initialize(type_string)
      @type_string = type_string.strip
    end

    def parse
      if @type_string.include?("<") && @type_string.include?(">")
        parse_generic
      else
        { type: :simple, value: @type_string }
      end
    end

    private

    def parse_generic
      # Match: BaseName<Params>
      match = @type_string.match(/^(\w+)<(.+)>$/)
      return { type: :simple, value: @type_string } unless match

      base_name = match[1]
      params_str = match[2]

      # Parse parameters, handling nested generics
      params = parse_params(params_str)

      {
        type: :generic,
        base: base_name,
        params: params
      }
    end

    def parse_params(params_str)
      # Simple comma-based splitting (doesn't handle nested generics fully)
      # For nested generics like Array<Array<String>>, we need careful parsing
      params = []
      current = ""
      depth = 0

      params_str.each_char do |char|
        case char
        when "<"
          depth += 1
          current += char
        when ">"
          depth -= 1
          current += char
        when ","
          if depth == 0
            params << current.strip
            current = ""
          else
            current += char
          end
        else
          current += char
        end
      end

      params << current.strip if current.length > 0
      params
    end
  end
end
