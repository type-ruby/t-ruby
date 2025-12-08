# frozen_string_literal: true

require "spec_helper"

describe TRuby::UnionTypeParser do
  describe "parsing union types" do
    it "parses simple union types with pipe separator" do
      parser = TRuby::UnionTypeParser.new("String | Integer")
      result = parser.parse

      expect(result[:type]).to eq(:union)
      expect(result[:members]).to eq(["String", "Integer"])
    end

    it "parses union with three or more types" do
      parser = TRuby::UnionTypeParser.new("String | Integer | Boolean")
      result = parser.parse

      expect(result[:members].length).to eq(3)
      expect(result[:members]).to include("String", "Integer", "Boolean")
    end

    it "parses union with nil" do
      parser = TRuby::UnionTypeParser.new("String | nil")
      result = parser.parse

      expect(result[:members]).to include("String", "nil")
    end

    it "handles whitespace around pipes" do
      parser = TRuby::UnionTypeParser.new("String  |  Integer  |  Boolean")
      result = parser.parse

      expect(result[:members]).to eq(["String", "Integer", "Boolean"])
    end

    it "identifies single types as non-union" do
      parser = TRuby::UnionTypeParser.new("String")
      result = parser.parse

      expect(result[:type]).to eq(:simple)
      expect(result[:value]).to eq("String")
    end
  end

  describe "union type validation" do
    it "detects duplicate types in union" do
      parser = TRuby::UnionTypeParser.new("String | String | Integer")
      result = parser.parse

      expect(result[:has_duplicates]).to be true
    end

    it "normalizes duplicate types" do
      parser = TRuby::UnionTypeParser.new("String | Integer | String")
      result = parser.parse

      expect(result[:unique_members]).to eq(["String", "Integer"])
    end
  end
end

describe TRuby::Parser do
  describe "parsing function with union type parameters" do
    it "parses function with union parameter type" do
      source = "def process(value: String | Integer): Boolean\nend"
      parser = TRuby::Parser.new(source)

      result = parser.parse
      expect(result[:functions][0][:params][0][:type]).to eq("String | Integer")
    end

    it "parses function with union return type" do
      source = "def get_value(): String | nil\nend"
      parser = TRuby::Parser.new(source)

      result = parser.parse
      expect(result[:functions][0][:return_type]).to eq("String | nil")
    end
  end
end

describe TRuby::ErrorHandler do
  describe "union type validation" do
    it "accepts valid union types" do
      source = "def test(x: String | Integer): Boolean\nend"
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end

    it "validates that union members are recognized types" do
      source = "def test(): String | Integer\nend"
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors).to be_empty
    end
  end
end
