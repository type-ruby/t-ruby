# frozen_string_literal: true

require "spec_helper"

describe TRuby::Parser do
  describe "type alias parsing" do
    context "simple type aliases" do
      it "parses simple type alias definitions" do
        source = "type UserId = String"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type_aliases]).to be_a(Array)
        expect(result[:type_aliases][0][:name]).to eq("UserId")
        expect(result[:type_aliases][0][:definition]).to eq("String")
      end

      it "parses multiple type alias definitions" do
        source = "type UserId = String\ntype Age = Integer\ntype Active = Boolean"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type_aliases].length).to eq(3)
        expect(result[:type_aliases][0][:name]).to eq("UserId")
        expect(result[:type_aliases][1][:name]).to eq("Age")
        expect(result[:type_aliases][2][:name]).to eq("Active")
      end
    end

    context "type alias with different basic types" do
      it "handles Integer type" do
        source = "type Count = Integer"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type_aliases][0][:definition]).to eq("Integer")
      end

      it "handles Boolean type" do
        source = "type IsActive = Boolean"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type_aliases][0][:definition]).to eq("Boolean")
      end

      it "handles Array type" do
        source = "type Items = Array"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type_aliases][0][:definition]).to eq("Array")
      end

      it "handles Hash type" do
        source = "type Data = Hash"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type_aliases][0][:definition]).to eq("Hash")
      end
    end

    context "type alias with references to other aliases" do
      it "parses reference to another type alias" do
        source = "type UserId = String\ntype AdminId = UserId"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type_aliases][1][:definition]).to eq("UserId")
      end
    end

    context "mixed functions and type aliases" do
      it "parses both functions and type aliases" do
        source = "type UserId = String\ndef greet(id: UserId): String\n  'hello'\nend"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type_aliases].length).to eq(1)
        expect(result[:functions].length).to eq(1)
      end

      it "preserves order of definitions" do
        source = "type UserId = String\ndef create(id: UserId): Boolean\n  true\nend\ntype Result = Boolean"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type_aliases][0][:name]).to eq("UserId")
        expect(result[:functions][0][:name]).to eq("create")
        expect(result[:type_aliases][1][:name]).to eq("Result")
      end
    end

    context "type alias with spaces" do
      it "handles spaces around equals sign" do
        source = "type UserId  =  String"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type_aliases][0][:name]).to eq("UserId")
        expect(result[:type_aliases][0][:definition]).to eq("String")
      end

      it "handles leading spaces" do
        source = "  type UserId = String"
        parser = TRuby::Parser.new(source)

        result = parser.parse
        expect(result[:type_aliases][0][:name]).to eq("UserId")
      end
    end
  end
end
