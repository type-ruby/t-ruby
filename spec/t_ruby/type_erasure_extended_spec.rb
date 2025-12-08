# frozen_string_literal: true

require "spec_helper"

describe TRuby::TypeErasure do
  describe "type alias erasure" do
    context "simple type alias removal" do
      it "removes type alias definitions" do
        source = "type UserId = String"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).not_to include("type UserId")
        expect(result.strip).to be_empty
      end

      it "removes multiple type alias definitions" do
        source = "type UserId = String\ntype Age = Integer"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).not_to include("type UserId")
        expect(result).not_to include("type Age")
      end

      it "preserves code after type aliases" do
        source = "type UserId = String\ndef greet(id: UserId): String\n  'hello'\nend"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).to include("def greet(id)")
        expect(result).not_to include("type UserId")
      end
    end

    context "mixed content" do
      it "handles type alias followed by function" do
        source = 'type UserId = String' + "\n" +
                 'def create(id: UserId): Boolean' + "\n" +
                 '  true' + "\n" +
                 'end'
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).not_to include("type UserId")
        expect(result).to include("def create(id)")
      end

      it "preserves function with type alias reference" do
        source = 'type Result = Boolean' + "\n" +
                 'def success(): Result' + "\n" +
                 '  true' + "\n" +
                 'end'
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result).not_to include("type Result")
        expect(result).to include("def success()")
      end
    end

    context "type alias with complex definitions" do
      it "removes type alias with reference to another type" do
        source = "type AdminId = UserId"
        eraser = TRuby::TypeErasure.new(source)

        result = eraser.erase
        expect(result.strip).to be_empty
      end
    end
  end
end
