# frozen_string_literal: true

require "spec_helper"

describe TRuby::IntersectionTypeParser do
  describe "#parse" do
    it "parses simple type" do
      parser = described_class.new("String")
      result = parser.parse
      expect(result[:type]).to eq(:simple)
      expect(result[:value]).to eq("String")
    end

    it "parses intersection with two types" do
      parser = described_class.new("Readable & Writable")
      result = parser.parse
      expect(result[:type]).to eq(:intersection)
      expect(result[:members]).to eq(%w[Readable Writable])
    end

    it "parses intersection with multiple types" do
      parser = described_class.new("A & B & C & D")
      result = parser.parse
      expect(result[:type]).to eq(:intersection)
      expect(result[:members]).to eq(%w[A B C D])
    end

    it "detects duplicates" do
      parser = described_class.new("A & B & A")
      result = parser.parse
      expect(result[:has_duplicates]).to be true
      expect(result[:unique_members]).to eq(%w[A B])
    end

    it "reports no duplicates when none exist" do
      parser = described_class.new("A & B")
      result = parser.parse
      expect(result[:has_duplicates]).to be false
    end

    it "strips whitespace" do
      parser = described_class.new("  A  &  B  ")
      result = parser.parse
      expect(result[:members]).to eq(%w[A B])
    end
  end
end
