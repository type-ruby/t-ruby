# frozen_string_literal: true

module TRuby
  # Custom exceptions for type alias errors
  class DuplicateTypeAliasError < StandardError; end
  class CircularTypeAliasError < StandardError; end
  class UndefinedTypeError < StandardError; end

  class TypeAliasRegistry
    BUILT_IN_TYPES = %w[String Integer Boolean Array Hash Symbol void nil].freeze

    def initialize
      @aliases = {}
    end

    def register(name, definition)
      if @aliases.key?(name)
        raise DuplicateTypeAliasError, "Type alias '#{name}' is already defined"
      end

      # Check for self-reference
      if name == definition
        raise CircularTypeAliasError, "Type alias '#{name}' cannot reference itself"
      end

      # Check for circular references (including longer chains)
      if would_create_cycle?(name, definition)
        raise CircularTypeAliasError, "Circular type alias detected involving '#{name}'"
      end

      @aliases[name] = definition
    end

    def resolve(name)
      @aliases[name]
    end

    def all
      @aliases.dup
    end

    def clear
      @aliases.clear
    end

    def valid_type?(name)
      return true if BUILT_IN_TYPES.include?(name)
      @aliases.key?(name)
    end

    def validate_all
      @aliases.each do |name, definition|
        check_circular_references(name)
        check_undefined_types(definition)
      end
    end

    private

    def would_create_cycle?(name, definition)
      # Follow the chain of definitions from 'definition' to see if it leads back to 'name'
      visited = Set.new
      current = definition

      # Check each step in the chain
      until visited.include?(current)
        return true if current == name
        return false unless @aliases.key?(current)

        visited.add(current)
        current = @aliases[current]
      end

      false
    end

    def check_circular_references(name, visited = Set.new)
      return if visited.include?(name)

      visited.add(name)
      definition = @aliases[name]

      return unless @aliases.key?(definition)

      if visited.include?(definition)
        raise CircularTypeAliasError, "Circular type alias detected involving '#{name}'"
      end

      check_circular_references(definition, visited)
    end

    def check_undefined_types(type_name)
      return if BUILT_IN_TYPES.include?(type_name)
      return if @aliases.key?(type_name)

      # Ignore generic types for now (e.g., Array<String>, Result<T, E>)
      return if type_name.include?("<")

      raise UndefinedTypeError, "Type '#{type_name}' is not defined"
    end
  end
end
