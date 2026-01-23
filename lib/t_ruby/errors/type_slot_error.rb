# frozen_string_literal: true

module TRuby
  module Errors
    # TypeSlotError - Error with context-aware messaging based on TypeSlot
    #
    # Provides rich error messages with location info, context, and suggestions.
    # Supports LSP diagnostic format for IDE integration.
    class TypeSlotError < StandardError
      attr_reader :type_slot, :original_message
      attr_accessor :suggestion

      def initialize(message:, type_slot: nil)
        @type_slot = type_slot
        @original_message = message
        @suggestion = nil
        super(message)
      end

      # Line number from type_slot location (1-indexed)
      def line
        type_slot&.location&.[](:line)
      end

      # Column number from type_slot location
      def column
        type_slot&.location&.[](:column)
      end

      # Kind of type slot (parameter, return, variable, etc.)
      def kind
        type_slot&.kind
      end

      # Format error message with location and context
      def formatted_message
        parts = []

        # Location header
        if line && column
          parts << "Line #{line}, Column #{column}:"
        elsif line
          parts << "Line #{line}:"
        end

        # Context description
        parts << context_description if type_slot

        # Main error message (use original_message to avoid recursion)
        parts << @original_message

        # Suggestion if provided
        parts << "  Suggestion: #{suggestion}" if suggestion

        parts.join("\n")
      end

      # Convert to LSP diagnostic format
      # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#diagnostic
      def to_lsp_diagnostic
        start_line = line ? line - 1 : 0 # LSP uses 0-indexed lines
        start_char = column || 0

        {
          range: {
            start: { line: start_line, character: start_char },
            end: { line: start_line, character: start_char + 1 },
          },
          message: message,
          severity: 1, # 1 = Error
          source: "t-ruby",
        }
      end

      def to_s
        formatted_message
      end

      private

      def context_description
        return nil unless type_slot

        ctx = type_slot.context || {}

        case kind
        when :parameter
          param_name = ctx[:param_name] || "unknown"
          method_name = ctx[:method_name] || "unknown"
          "in parameter '#{param_name}' of method '#{method_name}'"
        when :return
          method_name = ctx[:method_name] || "unknown"
          "in return type of method '#{method_name}'"
        when :variable
          var_name = ctx[:var_name] || "unknown"
          "in variable '#{var_name}'"
        when :instance_var
          var_name = ctx[:var_name] || "unknown"
          "in instance variable '#{var_name}'"
        when :generic_arg
          type_name = ctx[:type_name] || "unknown"
          "in generic argument of '#{type_name}'"
        end
      end
    end
  end
end
