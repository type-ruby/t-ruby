# frozen_string_literal: true

require "spec_helper"

describe TRuby::TypeAliasRegistry do
  let(:registry) { TRuby::TypeAliasRegistry.new }

  describe "basic type alias registration" do
    it "registers a simple type alias" do
      registry.register("UserId", "String")
      expect(registry.resolve("UserId")).to eq("String")
    end

    it "handles multiple type aliases" do
      registry.register("UserId", "String")
      registry.register("Age", "Integer")

      expect(registry.resolve("UserId")).to eq("String")
      expect(registry.resolve("Age")).to eq("Integer")
    end

    it "returns nil for undefined aliases" do
      expect(registry.resolve("NonExistent")).to be_nil
    end
  end

  describe "alias validation" do
    it "detects duplicate type alias definitions" do
      registry.register("UserId", "String")

      expect {
        registry.register("UserId", "Integer")
      }.to raise_error(TRuby::DuplicateTypeAliasError)
    end

    it "detects immediate circular references (A -> B -> A)" do
      registry.register("A", "B")

      expect {
        registry.register("B", "A")
      }.to raise_error(TRuby::CircularTypeAliasError)
    end

    it "detects longer circular references (A -> B -> C -> A)" do
      registry.register("A", "B")
      registry.register("B", "C")

      expect {
        registry.register("C", "A")
      }.to raise_error(TRuby::CircularTypeAliasError)
    end

    it "detects self-referencing alias" do
      expect {
        registry.register("A", "A")
      }.to raise_error(TRuby::CircularTypeAliasError)
    end

    it "detects reference to undefined type" do
      registry.register("UserId", "UndefinedType")

      expect {
        registry.validate_all
      }.to raise_error(TRuby::UndefinedTypeError)
    end
  end

  describe "alias resolution" do
    it "resolves transitive aliases" do
      registry.register("UserId", "Id")
      registry.register("Id", "String")

      # Should resolve to actual type
      expect(registry.resolve("UserId")).to eq("Id") # Direct resolution
    end

    it "lists all registered aliases" do
      registry.register("UserId", "String")
      registry.register("Age", "Integer")

      aliases = registry.all
      expect(aliases.count).to eq(2)
      expect(aliases["UserId"]).to eq("String")
      expect(aliases["Age"]).to eq("Integer")
    end
  end

  describe "type system integration" do
    it "recognizes basic types as valid even without registration" do
      expect(registry.valid_type?("String")).to be true
      expect(registry.valid_type?("Integer")).to be true
      expect(registry.valid_type?("Boolean")).to be true
    end

    it "recognizes registered aliases as valid" do
      registry.register("UserId", "String")
      expect(registry.valid_type?("UserId")).to be true
    end

    it "recognizes undefined custom types as invalid" do
      expect(registry.valid_type?("CustomUndefinedType")).to be false
    end
  end

  describe "clearing and reset" do
    it "can clear all aliases" do
      registry.register("UserId", "String")
      registry.clear

      expect(registry.resolve("UserId")).to be_nil
    end
  end
end
