# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Parser facade for TokenDeclarationParser" do
  describe "use_token_parser option" do
    let(:source) do
      <<~RUBY
        def greet(name: String): String
          name
        end
      RUBY
    end

    context "when use_token_parser is true" do
      it "uses TokenDeclarationParser" do
        parser = TRuby::Parser.new(source, use_token_parser: true)
        result = parser.parse

        expect(result[:type]).to eq(:success)
        expect(result[:functions]).not_to be_empty
      end

      it "generates TypeSlots for parameters" do
        parser = TRuby::Parser.new(source, use_token_parser: true)
        parser.parse
        ir = parser.ir_program

        method_def = ir.declarations.first
        expect(method_def.params.first.type_slot).to be_a(TRuby::IR::TypeSlot)
      end

      it "generates return_type_slot for methods" do
        parser = TRuby::Parser.new(source, use_token_parser: true)
        parser.parse
        ir = parser.ir_program

        method_def = ir.declarations.first
        expect(method_def.return_type_slot).to be_a(TRuby::IR::TypeSlot)
      end
    end

    context "when use_token_parser is false (default)" do
      it "uses legacy regex-based parser" do
        parser = TRuby::Parser.new(source)
        result = parser.parse

        expect(result[:type]).to eq(:success)
        expect(result[:functions]).not_to be_empty
      end
    end
  end

  describe "TRUBY_NEW_PARSER environment variable" do
    let(:source) do
      <<~RUBY
        def test: Integer
          42
        end
      RUBY
    end

    it "respects environment variable when set to '1'" do
      allow(ENV).to receive(:[]).with("TRUBY_NEW_PARSER").and_return("1")

      parser = TRuby::Parser.new(source)
      # Should use token parser when env var is set
      expect(parser.send(:use_token_parser?)).to be true
    end

    it "defaults to false when env var not set" do
      allow(ENV).to receive(:[]).with("TRUBY_NEW_PARSER").and_return(nil)

      parser = TRuby::Parser.new(source)
      expect(parser.send(:use_token_parser?)).to be false
    end
  end

  describe "backward compatibility" do
    let(:source) do
      <<~RUBY
        class Greeter
          def greet(name: String): String
            name
          end
        end
      RUBY
    end

    it "produces equivalent results from both parsers" do
      legacy_parser = TRuby::Parser.new(source, use_token_parser: false)
      token_parser = TRuby::Parser.new(source, use_token_parser: true)

      legacy_result = legacy_parser.parse
      token_result = token_parser.parse

      expect(legacy_result[:type]).to eq(token_result[:type])
      expect(legacy_result[:classes].length).to eq(token_result[:classes].length)
    end
  end
end
