# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::TypeResolution::SlotResolver do
  let(:resolver) { described_class.new }

  describe "#collect_unresolved_slots" do
    it "collects parameter type slots needing inference" do
      slot1 = TRuby::IR::TypeSlot.new(kind: :parameter, location: { line: 1, column: 1 })
      slot2 = TRuby::IR::TypeSlot.new(kind: :parameter, location: { line: 2, column: 1 })
      slot2.explicit_type = TRuby::IR::SimpleType.new(name: "String")

      param1 = TRuby::IR::Parameter.new(name: "a", type_slot: slot1)
      param2 = TRuby::IR::Parameter.new(name: "b", type_slot: slot2)

      method_def = TRuby::IR::MethodDef.new(
        name: "test",
        params: [param1, param2],
        body: TRuby::IR::Block.new(statements: [])
      )

      program = TRuby::IR::Program.new(declarations: [method_def])

      unresolved = resolver.collect_unresolved_slots(program)

      expect(unresolved).to include(slot1)
      expect(unresolved).not_to include(slot2)
    end

    it "collects return type slots needing inference" do
      return_slot = TRuby::IR::TypeSlot.new(kind: :return, location: { line: 1, column: 1 })

      method_def = TRuby::IR::MethodDef.new(
        name: "test",
        params: [],
        body: TRuby::IR::Block.new(statements: []),
        return_type_slot: return_slot
      )

      program = TRuby::IR::Program.new(declarations: [method_def])

      unresolved = resolver.collect_unresolved_slots(program)

      expect(unresolved).to include(return_slot)
    end

    it "excludes return type slots with explicit types" do
      return_slot = TRuby::IR::TypeSlot.new(kind: :return, location: { line: 1, column: 1 })
      return_slot.explicit_type = TRuby::IR::SimpleType.new(name: "Integer")

      method_def = TRuby::IR::MethodDef.new(
        name: "test",
        params: [],
        body: TRuby::IR::Block.new(statements: []),
        return_type_slot: return_slot
      )

      program = TRuby::IR::Program.new(declarations: [method_def])

      unresolved = resolver.collect_unresolved_slots(program)

      expect(unresolved).not_to include(return_slot)
    end
  end

  describe "#resolve_to_untyped" do
    it "sets resolved_type to untyped for parameter slots" do
      slot = TRuby::IR::TypeSlot.new(
        kind: :parameter,
        location: { line: 1, column: 1 },
        context: { param_name: "x", method_name: "test" }
      )

      resolver.resolve_to_untyped(slot)

      expect(slot.resolved_type).to be_a(TRuby::IR::SimpleType)
      expect(slot.resolved_type.name).to eq("untyped")
    end
  end

  describe "#resolve_all_untyped" do
    it "resolves all unresolved parameter slots to untyped" do
      slot1 = TRuby::IR::TypeSlot.new(kind: :parameter, location: { line: 1, column: 1 })
      slot2 = TRuby::IR::TypeSlot.new(kind: :parameter, location: { line: 2, column: 1 })
      slot2.explicit_type = TRuby::IR::SimpleType.new(name: "String")

      param1 = TRuby::IR::Parameter.new(name: "a", type_slot: slot1)
      param2 = TRuby::IR::Parameter.new(name: "b", type_slot: slot2)

      method_def = TRuby::IR::MethodDef.new(
        name: "test",
        params: [param1, param2],
        body: TRuby::IR::Block.new(statements: [])
      )

      program = TRuby::IR::Program.new(declarations: [method_def])

      resolver.resolve_all_untyped(program)

      expect(slot1.resolved_type.name).to eq("untyped")
      expect(slot2.resolved_type).to be_nil # explicit type, no resolution needed
    end
  end

  describe "#slot_summary" do
    it "returns summary of slot states" do
      slot1 = TRuby::IR::TypeSlot.new(kind: :parameter, location: { line: 1, column: 1 })
      slot2 = TRuby::IR::TypeSlot.new(kind: :parameter, location: { line: 2, column: 1 })
      slot2.explicit_type = TRuby::IR::SimpleType.new(name: "String")

      return_slot = TRuby::IR::TypeSlot.new(kind: :return, location: { line: 1, column: 1 })

      param1 = TRuby::IR::Parameter.new(name: "a", type_slot: slot1)
      param2 = TRuby::IR::Parameter.new(name: "b", type_slot: slot2)

      method_def = TRuby::IR::MethodDef.new(
        name: "test",
        params: [param1, param2],
        body: TRuby::IR::Block.new(statements: []),
        return_type_slot: return_slot
      )

      program = TRuby::IR::Program.new(declarations: [method_def])

      summary = resolver.slot_summary(program)

      expect(summary[:total]).to eq(3)
      expect(summary[:explicit]).to eq(1)
      expect(summary[:needs_inference]).to eq(2)
    end
  end
end
