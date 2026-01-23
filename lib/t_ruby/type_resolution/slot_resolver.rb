# frozen_string_literal: true

module TRuby
  module TypeResolution
    # SlotResolver - Identifies and resolves TypeSlots that need type inference
    #
    # This class is responsible for:
    # 1. Collecting all TypeSlots from an IR program
    # 2. Identifying which slots need type inference (no explicit type)
    # 3. Resolving slots to appropriate types (untyped for parameters, inferred for others)
    class SlotResolver
      # Collect all TypeSlots that need inference from a program
      # @param program [IR::Program] the parsed program
      # @return [Array<IR::TypeSlot>] slots needing inference
      def collect_unresolved_slots(program)
        slots = []

        program.declarations.each do |decl|
          collect_from_declaration(decl, slots)
        end

        slots.select(&:needs_inference?)
      end

      # Resolve a single slot to untyped
      # Used for parameters where we can't infer the type
      # @param slot [IR::TypeSlot] the slot to resolve
      def resolve_to_untyped(slot)
        slot.resolved_type = IR::SimpleType.new(name: "untyped")
      end

      # Resolve all unresolved slots in a program to untyped
      # This is a fallback strategy for gradual typing
      # @param program [IR::Program] the parsed program
      def resolve_all_untyped(program)
        collect_unresolved_slots(program).each do |slot|
          resolve_to_untyped(slot)
        end
      end

      # Get summary statistics about slots in a program
      # @param program [IR::Program] the parsed program
      # @return [Hash] summary with :total, :explicit, :needs_inference counts
      def slot_summary(program)
        all_slots = []

        program.declarations.each do |decl|
          collect_from_declaration(decl, all_slots)
        end

        {
          total: all_slots.size,
          explicit: all_slots.count { |s| !s.needs_inference? },
          needs_inference: all_slots.count(&:needs_inference?),
        }
      end

      private

      # Collect TypeSlots from a single declaration
      def collect_from_declaration(decl, slots)
        case decl
        when IR::MethodDef
          collect_from_method(decl, slots)
        when IR::ClassDef
          decl.body&.each { |d| collect_from_declaration(d, slots) }
        when IR::ModuleDef
          decl.body&.each { |d| collect_from_declaration(d, slots) }
        end
      end

      # Collect TypeSlots from a method definition
      def collect_from_method(method_def, slots)
        # Collect parameter slots
        method_def.params.each do |param|
          slots << param.type_slot if param.type_slot
        end

        # Collect return type slot
        slots << method_def.return_type_slot if method_def.return_type_slot
      end
    end
  end
end
