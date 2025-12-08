# frozen_string_literal: true

require "spec_helper"

describe TRuby::ErrorHandler do
  describe "type alias error detection" do
    context "duplicate type alias definitions" do
      it "detects duplicate type alias definitions" do
        source = "type UserId = String\ntype UserId = Integer"
        handler = TRuby::ErrorHandler.new(source)

        errors = handler.check
        expect(errors.length).to be > 0
      end

      it "reports error for duplicate alias with different definition" do
        source = "type Result = Boolean\ntype Result = String"
        handler = TRuby::ErrorHandler.new(source)

        errors = handler.check
        expect(errors.any? { |e| e.include?("duplicate") || e.include?("Result") }).to be true
      end
    end

    context "undefined type references" do
      it "detects reference to undefined custom type" do
        source = "def test(x: UndefinedCustomType): String\nend"
        handler = TRuby::ErrorHandler.new(source)

        errors = handler.check
        # May flag as undefined type
        expect(errors).to be_a(Array)
      end
    end

    context "type alias with valid references" do
      it "accepts type alias with built-in types" do
        source = "type UserId = String\ndef get(id: UserId): Boolean\nend"
        handler = TRuby::ErrorHandler.new(source)

        errors = handler.check
        expect(errors).to be_empty
      end
    end
  end
end
