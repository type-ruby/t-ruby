# frozen_string_literal: true

require "spec_helper"

describe TRuby::GenericTypeParser do
  describe "#parse" do
    it "parses simple type" do
      parser = described_class.new("String")
      result = parser.parse
      expect(result[:type]).to eq(:simple)
      expect(result[:value]).to eq("String")
    end

    it "parses generic type with single parameter" do
      parser = described_class.new("Array<String>")
      result = parser.parse
      expect(result[:type]).to eq(:generic)
      expect(result[:base]).to eq("Array")
      expect(result[:params]).to eq(["String"])
    end

    it "parses generic type with multiple parameters" do
      parser = described_class.new("Hash<String, Integer>")
      result = parser.parse
      expect(result[:type]).to eq(:generic)
      expect(result[:base]).to eq("Hash")
      expect(result[:params]).to eq(%w[String Integer])
    end

    it "parses nested generic types" do
      parser = described_class.new("Array<Array<String>>")
      result = parser.parse
      expect(result[:type]).to eq(:generic)
      expect(result[:base]).to eq("Array")
      expect(result[:params]).to eq(["Array<String>"])
    end

    it "parses deeply nested generic types" do
      parser = described_class.new("Hash<String, Array<Hash<Symbol, Integer>>>")
      result = parser.parse
      expect(result[:type]).to eq(:generic)
      expect(result[:base]).to eq("Hash")
      expect(result[:params]).to eq(["String", "Array<Hash<Symbol, Integer>>"])
    end

    it "handles whitespace" do
      parser = described_class.new("  Array< String >  ")
      result = parser.parse
      # NOTE: internal whitespace handling may vary
      expect(result[:type]).to eq(:generic)
      expect(result[:base]).to eq("Array")
    end

    it "treats malformed generic as simple type" do
      parser = described_class.new("Array<String")
      result = parser.parse
      expect(result[:type]).to eq(:simple)
    end

    it "parses generic with complex nested parameters" do
      parser = described_class.new("Result<Success<Data>, Error<String>>")
      result = parser.parse
      expect(result[:type]).to eq(:generic)
      expect(result[:base]).to eq("Result")
      expect(result[:params]).to eq(["Success<Data>", "Error<String>"])
    end
  end
end
