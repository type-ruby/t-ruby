# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::ConstraintChecker do
  let(:checker) { TRuby::ConstraintChecker.new }

  describe "#parse_constraint" do
    context "with bounds constraint" do
      it "parses T <: BaseType syntax" do
        result = checker.parse_constraint("PositiveInt <: Integer")
        expect(result[:name]).to eq("PositiveInt")
        expect(result[:base_type]).to eq("Integer")
        expect(result[:constraints].first).to be_a(TRuby::BoundsConstraint)
      end
    end

    context "with numeric range constraint" do
      it "parses >= comparison" do
        result = checker.parse_constraint("PositiveInt = Integer where >= 1")
        expect(result[:name]).to eq("PositiveInt")
        expect(result[:base_type]).to eq("Integer")
        expect(result[:constraints].first).to be_a(TRuby::NumericRangeConstraint)
      end

      it "parses > comparison" do
        result = checker.parse_constraint("PositiveInt = Integer where > 0")
        expect(result).not_to be_nil
        expect(result[:constraints].first.min).to eq(1)
      end

      it "parses < comparison" do
        result = checker.parse_constraint("NegativeInt = Integer where < 0")
        expect(result).not_to be_nil
        expect(result[:constraints].first.max).to eq(-1)
      end

      it "parses <= comparison" do
        result = checker.parse_constraint("NonPositive = Integer where <= 0")
        expect(result).not_to be_nil
        expect(result[:constraints].first.max).to eq(0)
      end

      it "parses range syntax" do
        result = checker.parse_constraint("Percent = Integer where 0..100")
        expect(result).not_to be_nil
        constraint = result[:constraints].first
        expect(constraint.min).to eq(0)
        expect(constraint.max).to eq(100)
      end
    end

    context "with pattern constraint" do
      it "parses regex pattern" do
        result = checker.parse_constraint("Email = String where /^[a-z]+@[a-z]+\\.[a-z]+$/")
        expect(result[:name]).to eq("Email")
        expect(result[:base_type]).to eq("String")
        expect(result[:constraints].first).to be_a(TRuby::PatternConstraint)
      end
    end

    context "with length constraint" do
      it "parses length == N" do
        result = checker.parse_constraint("ZipCode = String where length == 5")
        expect(result).not_to be_nil
        expect(result[:constraints].first).to be_a(TRuby::LengthConstraint)
        expect(result[:constraints].first.exact_length).to eq(5)
      end

      it "parses length >= N" do
        result = checker.parse_constraint("NonEmpty = String where length >= 1")
        expect(result).not_to be_nil
        expect(result[:constraints].first.min_length).to eq(1)
      end
    end

    context "with predicate constraint" do
      it "parses predicate method" do
        result = checker.parse_constraint("NonEmpty = Array where empty?")
        expect(result).not_to be_nil
        expect(result[:constraints].first).to be_a(TRuby::PredicateConstraint)
      end
    end
  end

  describe "#validate" do
    before do
      checker.register("PositiveInt", base_type: "Integer", constraints: [
        TRuby::NumericRangeConstraint.new(base_type: "Integer", min: 1)
      ])

      checker.register("Percentage", base_type: "Integer", constraints: [
        TRuby::NumericRangeConstraint.new(base_type: "Integer", min: 0, max: 100)
      ])

      checker.register("ShortString", base_type: "String", constraints: [
        TRuby::LengthConstraint.new(base_type: "String", max_length: 10)
      ])
    end

    it "validates positive integer" do
      expect(checker.validate("PositiveInt", 5)).to be true
      expect(checker.validate("PositiveInt", 1)).to be true
    end

    it "rejects zero for positive integer" do
      expect(checker.validate("PositiveInt", 0)).to be false
    end

    it "rejects negative for positive integer" do
      expect(checker.validate("PositiveInt", -1)).to be false
    end

    it "validates percentage in range" do
      expect(checker.validate("Percentage", 0)).to be true
      expect(checker.validate("Percentage", 50)).to be true
      expect(checker.validate("Percentage", 100)).to be true
    end

    it "rejects percentage out of range" do
      expect(checker.validate("Percentage", -1)).to be false
      expect(checker.validate("Percentage", 101)).to be false
    end

    it "validates short string" do
      expect(checker.validate("ShortString", "hello")).to be true
      expect(checker.validate("ShortString", "12345678")).to be true
    end

    it "rejects long string" do
      expect(checker.validate("ShortString", "this is way too long")).to be false
    end

    it "provides error messages" do
      checker.validate("PositiveInt", -5)
      expect(checker.errors).not_to be_empty
    end
  end

  describe "#generate_validation_code" do
    before do
      checker.register("PositiveInt", base_type: "Integer", constraints: [
        TRuby::NumericRangeConstraint.new(base_type: "Integer", min: 1)
      ])
    end

    it "generates validation code" do
      code = checker.generate_validation_code("PositiveInt", "value")
      expect(code).to include("value.is_a?(Integer)")
      expect(code).to include("value >= 1")
    end
  end
end

RSpec.describe TRuby::NumericRangeConstraint do
  describe "#satisfied?" do
    it "checks minimum" do
      constraint = TRuby::NumericRangeConstraint.new(base_type: "Integer", min: 0)
      expect(constraint.satisfied?(0)).to be true
      expect(constraint.satisfied?(1)).to be true
      expect(constraint.satisfied?(-1)).to be false
    end

    it "checks maximum" do
      constraint = TRuby::NumericRangeConstraint.new(base_type: "Integer", max: 100)
      expect(constraint.satisfied?(100)).to be true
      expect(constraint.satisfied?(99)).to be true
      expect(constraint.satisfied?(101)).to be false
    end

    it "checks range" do
      constraint = TRuby::NumericRangeConstraint.new(base_type: "Integer", min: 1, max: 10)
      expect(constraint.satisfied?(1)).to be true
      expect(constraint.satisfied?(5)).to be true
      expect(constraint.satisfied?(10)).to be true
      expect(constraint.satisfied?(0)).to be false
      expect(constraint.satisfied?(11)).to be false
    end
  end
end

RSpec.describe TRuby::PatternConstraint do
  describe "#satisfied?" do
    it "matches pattern" do
      constraint = TRuby::PatternConstraint.new(base_type: "String", pattern: /^\d+$/)
      expect(constraint.satisfied?("123")).to be true
      expect(constraint.satisfied?("abc")).to be false
    end

    it "accepts string pattern" do
      constraint = TRuby::PatternConstraint.new(base_type: "String", pattern: "^hello")
      expect(constraint.satisfied?("hello world")).to be true
      expect(constraint.satisfied?("world hello")).to be false
    end
  end
end

RSpec.describe TRuby::LengthConstraint do
  describe "#satisfied?" do
    it "checks exact length" do
      constraint = TRuby::LengthConstraint.new(base_type: "String", exact_length: 5)
      expect(constraint.satisfied?("hello")).to be true
      expect(constraint.satisfied?("hi")).to be false
    end

    it "checks min length" do
      constraint = TRuby::LengthConstraint.new(base_type: "String", min_length: 3)
      expect(constraint.satisfied?("abc")).to be true
      expect(constraint.satisfied?("ab")).to be false
    end

    it "checks max length" do
      constraint = TRuby::LengthConstraint.new(base_type: "String", max_length: 5)
      expect(constraint.satisfied?("abc")).to be true
      expect(constraint.satisfied?("abcdef")).to be false
    end

    it "works with arrays" do
      constraint = TRuby::LengthConstraint.new(base_type: "Array", min_length: 1)
      expect(constraint.satisfied?([1])).to be true
      expect(constraint.satisfied?([])).to be false
    end
  end
end

RSpec.describe TRuby::PredicateConstraint do
  describe "#satisfied?" do
    it "checks predicate method" do
      constraint = TRuby::PredicateConstraint.new(base_type: "Integer", predicate: :positive?)
      expect(constraint.satisfied?(5)).to be true
      expect(constraint.satisfied?(-5)).to be false
    end

    it "checks empty? predicate" do
      constraint = TRuby::PredicateConstraint.new(base_type: "String", predicate: :empty?)
      expect(constraint.satisfied?("")).to be true
      expect(constraint.satisfied?("hello")).to be false
    end
  end
end

RSpec.describe TRuby::ConstrainedTypeRegistry do
  let(:registry) { TRuby::ConstrainedTypeRegistry.new }

  describe "#register" do
    it "registers a constrained type" do
      registry.register("PositiveInt", base_type: "Integer", constraints: [])
      expect(registry.registered?("PositiveInt")).to be true
    end
  end

  describe "#register_from_source" do
    it "parses and registers from source" do
      result = registry.register_from_source("PositiveInt = Integer where > 0")
      expect(result).to be true
      expect(registry.registered?("PositiveInt")).to be true
    end
  end

  describe "#validate" do
    before do
      registry.register("PositiveInt", base_type: "Integer", constraints: [
        TRuby::NumericRangeConstraint.new(base_type: "Integer", min: 1)
      ])
    end

    it "validates against registered type" do
      expect(registry.validate("PositiveInt", 5)).to be true
      expect(registry.validate("PositiveInt", 0)).to be false
    end
  end

  describe "#validation_code" do
    before do
      registry.register("PositiveInt", base_type: "Integer", constraints: [
        TRuby::NumericRangeConstraint.new(base_type: "Integer", min: 1)
      ])
    end

    it "generates validation code" do
      code = registry.validation_code("PositiveInt", "n")
      expect(code).to include("n.is_a?(Integer)")
      expect(code).to include("n >= 1")
    end
  end

  describe "#list" do
    it "lists all registered types" do
      registry.register("TypeA", base_type: "Integer", constraints: [])
      registry.register("TypeB", base_type: "String", constraints: [])
      expect(registry.list).to contain_exactly("TypeA", "TypeB")
    end
  end

  describe "#clear" do
    it "clears all registrations" do
      registry.register("TypeA", base_type: "Integer", constraints: [])
      registry.clear
      expect(registry.list).to be_empty
    end
  end
end
