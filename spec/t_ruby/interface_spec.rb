# frozen_string_literal: true

require "spec_helper"

describe TRuby::Parser do
  describe "parsing interface definitions" do
    it "parses simple interface with single member" do
      source = 'interface User' + "\n" +
               '  name: String' + "\n" +
               'end'
      parser = TRuby::Parser.new(source)

      result = parser.parse
      expect(result[:interfaces]).to be_a(Array)
      expect(result[:interfaces][0][:name]).to eq("User")
    end

    it "parses interface with multiple members" do
      source = 'interface User' + "\n" +
               '  name: String' + "\n" +
               '  age: Integer' + "\n" +
               'end'
      parser = TRuby::Parser.new(source)

      result = parser.parse
      interface = result[:interfaces][0]
      expect(interface[:members].length).to eq(2)
    end

    it "parses interface member types correctly" do
      source = 'interface User' + "\n" +
               '  name: String' + "\n" +
               '  active: Boolean' + "\n" +
               'end'
      parser = TRuby::Parser.new(source)

      result = parser.parse
      interface = result[:interfaces][0]
      expect(interface[:members][0][:name]).to eq("name")
      expect(interface[:members][0][:type]).to eq("String")
    end

    it "handles empty interface" do
      source = 'interface Empty' + "\n" +
               'end'
      parser = TRuby::Parser.new(source)

      result = parser.parse
      expect(result[:interfaces][0][:name]).to eq("Empty")
      expect(result[:interfaces][0][:members]).to be_a(Array)
    end
  end
end

describe TRuby::ErrorHandler do
  describe "interface validation" do
    it "detects duplicate interface definitions" do
      source = 'interface User' + "\n" +
               '  name: String' + "\n" +
               'end' + "\n" +
               'interface User' + "\n" +
               '  age: Integer' + "\n" +
               'end'
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors.any? { |e| e.include?("duplicate") || e.include?("User") }).to be true
    end

    it "accepts valid interface definitions" do
      source = 'interface User' + "\n" +
               '  name: String' + "\n" +
               '  age: Integer' + "\n" +
               'end'
      handler = TRuby::ErrorHandler.new(source)

      errors = handler.check
      expect(errors.to_s).not_to include("interface")
    end
  end
end
