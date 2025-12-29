# frozen_string_literal: true

require "spec_helper"

describe TRuby::UnionTypeParser do
  describe "#parse" do
    it "parses simple type" do
      parser = described_class.new("String")
      result = parser.parse
      expect(result[:type]).to eq(:simple)
      expect(result[:value]).to eq("String")
    end

    it "parses union with two types" do
      parser = described_class.new("String | Integer")
      result = parser.parse
      expect(result[:type]).to eq(:union)
      expect(result[:members]).to eq(%w[String Integer])
    end

    it "parses union with multiple types" do
      parser = described_class.new("String | Integer | Boolean | nil")
      result = parser.parse
      expect(result[:type]).to eq(:union)
      expect(result[:members]).to eq(%w[String Integer Boolean nil])
    end

    it "detects duplicates" do
      parser = described_class.new("String | Integer | String")
      result = parser.parse
      expect(result[:has_duplicates]).to be true
      expect(result[:unique_members]).to eq(%w[String Integer])
    end

    it "reports no duplicates when none exist" do
      parser = described_class.new("String | Integer")
      result = parser.parse
      expect(result[:has_duplicates]).to be false
    end

    it "strips whitespace" do
      parser = described_class.new("  String  |  Integer  ")
      result = parser.parse
      expect(result[:members]).to eq(%w[String Integer])
    end

    it "handles nil type" do
      parser = described_class.new("String | nil")
      result = parser.parse
      expect(result[:members]).to include("nil")
    end
  end
end
