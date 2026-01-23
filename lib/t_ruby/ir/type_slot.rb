# frozen_string_literal: true

module TRuby
  module IR
    # TypeSlot represents a position where a type annotation is expected.
    # It tracks explicit, inferred, and resolved types for that position.
    #
    # @example Parameter type slot
    #   slot = TypeSlot.new(
    #     kind: :parameter,
    #     location: { line: 5, column: 10 },
    #     context: { method_name: "greet", param_name: "name" }
    #   )
    #   slot.explicit_type = SimpleType.new(name: "String")
    #
    class TypeSlot
      KINDS = %i[parameter return variable instance_var generic_arg].freeze

      attr_reader :kind, :location, :context
      attr_accessor :explicit_type, :inferred_type, :resolved_type

      # @param kind [Symbol] One of KINDS - the type of slot
      # @param location [Hash] Location information (line, column)
      # @param context [Hash] Additional context for error messages
      def initialize(kind:, location:, context: {})
        @kind = kind
        @location = location
        @context = context
        @explicit_type = nil
        @inferred_type = nil
        @resolved_type = nil
      end

      # @return [Boolean] true if this slot needs type inference
      def needs_inference?
        @explicit_type.nil?
      end

      # @return [Hash] Context information for error messages
      def error_context
        {
          kind: @kind,
          location: @location,
          context: @context,
        }
      end

      # Returns the best available type, falling back to untyped
      # Priority: resolved_type > explicit_type > inferred_type > untyped
      #
      # @return [TypeNode] The resolved type or untyped
      def resolved_type_or_untyped
        @resolved_type || @explicit_type || @inferred_type || SimpleType.new(name: "untyped")
      end
    end
  end
end
