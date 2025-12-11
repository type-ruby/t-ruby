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
  end
end
