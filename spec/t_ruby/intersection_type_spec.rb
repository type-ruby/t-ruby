# frozen_string_literal: true

require "spec_helper"

describe TRuby::IntersectionTypeParser do
  describe "parsing intersection types" do
    it "parses simple intersection type" do
      parser = TRuby::IntersectionTypeParser.new("Readable & Writable")
      result = parser.parse

      expect(result[:type]).to eq(:intersection)
      expect(result[:members]).to eq(["Readable", "Writable"])
    end

    it "parses intersection with three or more types" do
      parser = TRuby::IntersectionTypeParser.new("Readable & Writable & Closeable")
      result = parser.parse

      expect(result[:members].length).to eq(3)
      expect(result[:members]).to include("Readable", "Writable", "Closeable")
    end

    it "handles whitespace around ampersands" do
      parser = TRuby::IntersectionTypeParser.new("Readable  &  Writable  &  Closeable")
      result = parser.parse

      expect(result[:members]).to eq(["Readable", "Writable", "Closeable"])
    end

    it "identifies non-intersection types" do
      parser = TRuby::IntersectionTypeParser.new("Reader")
      result = parser.parse

      expect(result[:type]).to eq(:simple)
    end

    it "detects duplicate types in intersection" do
      parser = TRuby::IntersectionTypeParser.new("Readable & Readable & Writable")
      result = parser.parse

      expect(result[:has_duplicates]).to be true
    end
  end
end

describe TRuby::Parser do
  describe "parsing functions with intersection types" do
    it "parses function with intersection parameter" do
      source = "def process(obj: Readable & Writable): Boolean\nend"
      parser = TRuby::Parser.new(source)

      result = parser.parse
      expect(result[:functions][0][:params][0][:type]).to eq("Readable & Writable")
    end

    it "parses function with intersection return type" do
      source = "def get_stream(): Readable & Writable\nend"
      parser = TRuby::Parser.new(source)

      result = parser.parse
      expect(result[:functions][0][:return_type]).to eq("Readable & Writable")
    end
  end
end
