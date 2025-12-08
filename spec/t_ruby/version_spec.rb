# frozen_string_literal: true

require "spec_helper"

describe TRuby do
  describe "VERSION" do
    it "is defined" do
      expect(TRuby::VERSION).to be_a(String)
    end

    it "is in semantic versioning format" do
      expect(TRuby::VERSION).to match(/^\d+\.\d+\.\d+$/)
    end

    it "is set to 0.0.1" do
      expect(TRuby::VERSION).to eq("0.0.1")
    end
  end
end
