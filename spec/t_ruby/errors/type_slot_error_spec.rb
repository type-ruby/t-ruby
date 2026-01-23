# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::Errors::TypeSlotError do
  let(:type_slot) do
    TRuby::IR::TypeSlot.new(
      kind: :parameter,
      location: { line: 10, column: 5 },
      context: { method_name: "greet", param_name: "name" }
    )
  end

  describe "initialization" do
    it "creates error with message and type_slot" do
      error = described_class.new(
        message: "Expected type annotation",
        type_slot: type_slot
      )

      expect(error.message).to include("Expected type annotation")
      expect(error.type_slot).to eq(type_slot)
    end

    it "creates error without type_slot" do
      error = described_class.new(message: "Generic error")

      expect(error.message).to include("Generic error")
      expect(error.type_slot).to be_nil
    end
  end

  describe "#line" do
    it "returns line from type_slot location" do
      error = described_class.new(message: "Error", type_slot: type_slot)

      expect(error.line).to eq(10)
    end

    it "returns nil when no type_slot" do
      error = described_class.new(message: "Error")

      expect(error.line).to be_nil
    end
  end

  describe "#column" do
    it "returns column from type_slot location" do
      error = described_class.new(message: "Error", type_slot: type_slot)

      expect(error.column).to eq(5)
    end
  end

  describe "#kind" do
    it "returns kind from type_slot" do
      error = described_class.new(message: "Error", type_slot: type_slot)

      expect(error.kind).to eq(:parameter)
    end
  end

  describe "#formatted_message" do
    it "includes location information" do
      error = described_class.new(
        message: "Expected type annotation",
        type_slot: type_slot
      )

      formatted = error.formatted_message

      expect(formatted).to include("Line 10")
      expect(formatted).to include("Column 5")
    end

    it "includes context information for parameter" do
      error = described_class.new(
        message: "Expected type annotation",
        type_slot: type_slot
      )

      formatted = error.formatted_message

      expect(formatted).to include("parameter")
      expect(formatted).to include("name")
      expect(formatted).to include("greet")
    end

    it "includes context information for return type" do
      return_slot = TRuby::IR::TypeSlot.new(
        kind: :return,
        location: { line: 5, column: 20 },
        context: { method_name: "calculate" }
      )
      error = described_class.new(
        message: "Missing return type",
        type_slot: return_slot
      )

      formatted = error.formatted_message

      expect(formatted).to include("return")
      expect(formatted).to include("calculate")
    end
  end

  describe "#suggestion" do
    it "allows setting suggestion" do
      error = described_class.new(message: "Error", type_slot: type_slot)
      error.suggestion = "Add type annotation like 'name: String'"

      expect(error.suggestion).to eq("Add type annotation like 'name: String'")
    end

    it "includes suggestion in formatted_message" do
      error = described_class.new(message: "Error", type_slot: type_slot)
      error.suggestion = "Add type annotation"

      formatted = error.formatted_message

      expect(formatted).to include("Suggestion:")
      expect(formatted).to include("Add type annotation")
    end
  end

  describe "#to_lsp_diagnostic" do
    it "returns LSP-compatible diagnostic hash" do
      error = described_class.new(
        message: "Type mismatch",
        type_slot: type_slot
      )

      diagnostic = error.to_lsp_diagnostic

      expect(diagnostic).to be_a(Hash)
      expect(diagnostic[:range][:start][:line]).to eq(9) # 0-indexed
      expect(diagnostic[:range][:start][:character]).to eq(5)
      expect(diagnostic[:message]).to include("Type mismatch")
      expect(diagnostic[:severity]).to eq(1) # Error
    end

    it "sets source to 't-ruby'" do
      error = described_class.new(message: "Error", type_slot: type_slot)

      diagnostic = error.to_lsp_diagnostic

      expect(diagnostic[:source]).to eq("t-ruby")
    end
  end

  describe "#to_s" do
    it "returns formatted message" do
      error = described_class.new(
        message: "Expected type annotation",
        type_slot: type_slot
      )

      expect(error.to_s).to eq(error.formatted_message)
    end
  end
end
