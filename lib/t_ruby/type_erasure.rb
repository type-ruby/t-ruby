# frozen_string_literal: true

module TRuby
  class TypeErasure
    def initialize(source)
      @source = source
    end

    def erase
      result = @source.dup

      # Remove parameter type annotations: (name: Type) -> (name)
      # Matches: parameter_name: TypeName
      result = result.gsub(/\b(\w+)\s*:\s*\w+/, '\1')

      # Remove return type annotations: ): TypeName -> )
      # Matches: ): TypeName or ): TypeName (with spaces/EOF)
      result = result.gsub(/\)\s*:\s*\w+(\s|$)/, ')\1')

      result
    end
  end
end
