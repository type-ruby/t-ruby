# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::IR::TypeSlot do
  describe "initialization" do
    it "creates a type slot with kind and location" do
      slot = described_class.new(
        kind: :parameter,
        location: { line: 5, column: 10 }
      )

      expect(slot.kind).to eq(:parameter)
      expect(slot.location).to eq({ line: 5, column: 10 })
    end

    it "accepts context information" do
      slot = described_class.new(
        kind: :parameter,
        location: { line: 1, column: 0 },
        context: { method_name: "greet", param_name: "name" }
      )

      expect(slot.context[:method_name]).to eq("greet")
      expect(slot.context[:param_name]).to eq("name")
    end

    it "validates kind is one of KINDS" do
      expect(TRuby::IR::TypeSlot::KINDS).to include(:parameter)
      expect(TRuby::IR::TypeSlot::KINDS).to include(:return)
      expect(TRuby::IR::TypeSlot::KINDS).to include(:variable)
      expect(TRuby::IR::TypeSlot::KINDS).to include(:instance_var)
      expect(TRuby::IR::TypeSlot::KINDS).to include(:generic_arg)
    end
  end

  describe "#explicit_type" do
    it "stores explicit type annotation" do
      slot = described_class.new(kind: :parameter, location: {})
      type = TRuby::IR::SimpleType.new(name: "String")

      slot.explicit_type = type

      expect(slot.explicit_type).to eq(type)
    end
  end

  describe "#inferred_type" do
    it "stores inferred type" do
      slot = described_class.new(kind: :variable, location: {})
      type = TRuby::IR::SimpleType.new(name: "Integer")

      slot.inferred_type = type

      expect(slot.inferred_type).to eq(type)
    end
  end

  describe "#resolved_type" do
    it "stores final resolved type" do
      slot = described_class.new(kind: :return, location: {})
      type = TRuby::IR::SimpleType.new(name: "Boolean")

      slot.resolved_type = type

      expect(slot.resolved_type).to eq(type)
    end
  end

  describe "#needs_inference?" do
    it "returns true when explicit_type is nil" do
      slot = described_class.new(kind: :parameter, location: {})

      expect(slot.needs_inference?).to be true
    end

    it "returns false when explicit_type is set" do
      slot = described_class.new(kind: :parameter, location: {})
      slot.explicit_type = TRuby::IR::SimpleType.new(name: "String")

      expect(slot.needs_inference?).to be false
    end
  end

  describe "#error_context" do
    it "returns context information for error messages" do
      slot = described_class.new(
        kind: :parameter,
        location: { line: 10, column: 5 },
        context: { method_name: "process", param_name: "data" }
      )

      error_ctx = slot.error_context

      expect(error_ctx[:kind]).to eq(:parameter)
      expect(error_ctx[:location]).to eq({ line: 10, column: 5 })
      expect(error_ctx[:context][:method_name]).to eq("process")
    end
  end

  describe "#resolved_type_or_untyped" do
    it "returns resolved_type when set" do
      slot = described_class.new(kind: :parameter, location: {})
      type = TRuby::IR::SimpleType.new(name: "String")
      slot.resolved_type = type

      expect(slot.resolved_type_or_untyped).to eq(type)
    end

    it "returns explicit_type when resolved_type is nil" do
      slot = described_class.new(kind: :parameter, location: {})
      type = TRuby::IR::SimpleType.new(name: "Integer")
      slot.explicit_type = type

      expect(slot.resolved_type_or_untyped).to eq(type)
    end

    it "returns inferred_type when explicit and resolved are nil" do
      slot = described_class.new(kind: :variable, location: {})
      type = TRuby::IR::SimpleType.new(name: "Float")
      slot.inferred_type = type

      expect(slot.resolved_type_or_untyped).to eq(type)
    end

    it "returns untyped SimpleType when all types are nil" do
      slot = described_class.new(kind: :parameter, location: {})

      result = slot.resolved_type_or_untyped

      expect(result).to be_a(TRuby::IR::SimpleType)
      expect(result.name).to eq("untyped")
    end
  end
end
