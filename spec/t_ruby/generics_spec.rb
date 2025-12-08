# frozen_string_literal: true

require "spec_helper"

describe TRuby::GenericTypeParser do
  describe "parsing generic types" do
    it "parses simple generic type" do
      parser = TRuby::GenericTypeParser.new("Array<String>")
      result = parser.parse

      expect(result[:type]).to eq(:generic)
      expect(result[:base]).to eq("Array")
      expect(result[:params]).to eq(["String"])
    end

    it "parses generic with multiple type parameters" do
      parser = TRuby::GenericTypeParser.new("Map<String, Integer>")
      result = parser.parse

      expect(result[:base]).to eq("Map")
      expect(result[:params].length).to eq(2)
      expect(result[:params]).to include("String", "Integer")
    end

    it "parses nested generics" do
      parser = TRuby::GenericTypeParser.new("Array<Array<String>>")
      result = parser.parse

      expect(result[:base]).to eq("Array")
      expect(result[:params][0]).to eq("Array<String>")
    end

    it "identifies non-generic types" do
      parser = TRuby::GenericTypeParser.new("String")
      result = parser.parse

      expect(result[:type]).to eq(:simple)
    end
  end
end

describe TRuby::Parser do
  describe "parsing functions with generic types" do
    it "parses function with generic parameter" do
      source = "def process(items: Array<String>): String\nend"
      parser = TRuby::Parser.new(source)

      result = parser.parse
      expect(result[:functions][0][:params][0][:type]).to eq("Array<String>")
    end

    it "parses function with generic return type" do
      source = "def get_map(): Map<String, Integer>\nend"
      parser = TRuby::Parser.new(source)

      result = parser.parse
      expect(result[:functions][0][:return_type]).to eq("Map<String, Integer>")
    end
  end
end
