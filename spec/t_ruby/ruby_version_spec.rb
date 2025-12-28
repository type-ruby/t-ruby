# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::RubyVersion do
  describe ".parse" do
    it "parses major.minor version string" do
      version = described_class.parse("3.2")
      expect(version.major).to eq(3)
      expect(version.minor).to eq(2)
      expect(version.patch).to eq(0)
    end

    it "parses major.minor.patch version string" do
      version = described_class.parse("3.2.1")
      expect(version.major).to eq(3)
      expect(version.minor).to eq(2)
      expect(version.patch).to eq(1)
    end

    it "parses version with numeric input" do
      version = described_class.parse(3.2)
      expect(version.major).to eq(3)
      expect(version.minor).to eq(2)
    end

    it "raises error for invalid version format" do
      expect { described_class.parse("invalid") }.to raise_error(ArgumentError, /Invalid version/)
      expect { described_class.parse("3") }.to raise_error(ArgumentError, /Invalid version/)
      expect { described_class.parse("") }.to raise_error(ArgumentError, /Invalid version/)
    end
  end

  describe ".current" do
    it "returns the current Ruby version" do
      version = described_class.current
      expect(version).to be_a(described_class)

      parts = RUBY_VERSION.split(".")
      expect(version.major).to eq(parts[0].to_i)
      expect(version.minor).to eq(parts[1].to_i)
      expect(version.patch).to eq(parts[2].to_i)
    end
  end

  describe "comparison" do
    it "compares versions with ==" do
      expect(described_class.parse("3.2")).to eq(described_class.parse("3.2"))
      expect(described_class.parse("3.2")).to eq(described_class.parse("3.2.0"))
      expect(described_class.parse("3.2")).not_to eq(described_class.parse("3.3"))
    end

    it "compares versions with >=" do
      v32 = described_class.parse("3.2")
      v34 = described_class.parse("3.4")
      v40 = described_class.parse("4.0")

      expect(v34 >= v32).to be true
      expect(v32 >= v34).to be false
      expect(v40 >= v34).to be true
      expect(v32 == v32).to be true # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands
    end

    it "compares versions with <" do
      v30 = described_class.parse("3.0")
      v34 = described_class.parse("3.4")

      expect(v30 < v34).to be true
      expect(v34 < v30).to be false
    end

    it "sorts versions correctly" do
      versions = [
        described_class.parse("4.0"),
        described_class.parse("3.0"),
        described_class.parse("3.4"),
        described_class.parse("3.1"),
      ]

      sorted = versions.sort
      expect(sorted.map(&:to_s)).to eq(%w[3.0 3.1 3.4 4.0])
    end
  end

  describe "#to_s" do
    it "returns major.minor format" do
      expect(described_class.parse("3.2").to_s).to eq("3.2")
      expect(described_class.parse("3.2.0").to_s).to eq("3.2")
      expect(described_class.parse("4.0").to_s).to eq("4.0")
    end

    it "includes patch version when non-zero" do
      expect(described_class.parse("3.2.1").to_s).to eq("3.2.1")
    end
  end

  describe "#supported?" do
    it "returns true for supported versions (3.0 ~ 4.x)" do
      expect(described_class.parse("3.0").supported?).to be true
      expect(described_class.parse("3.1").supported?).to be true
      expect(described_class.parse("3.4").supported?).to be true
      expect(described_class.parse("4.0").supported?).to be true
      expect(described_class.parse("4.1").supported?).to be true
    end

    it "returns false for unsupported versions" do
      expect(described_class.parse("2.7").supported?).to be false
      expect(described_class.parse("2.6").supported?).to be false
      expect(described_class.parse("5.0").supported?).to be false
    end
  end

  describe "#validate!" do
    it "returns self for supported versions" do
      version = described_class.parse("3.4")
      expect(version.validate!).to eq(version)
    end

    it "raises UnsupportedRubyVersionError for unsupported versions" do
      expect do
        described_class.parse("2.7").validate!
      end.to raise_error(TRuby::UnsupportedRubyVersionError, /2\.7.*지원.*3\.0.*4\.x/i)

      expect do
        described_class.parse("5.0").validate!
      end.to raise_error(TRuby::UnsupportedRubyVersionError)
    end
  end

  describe "#supports_it_parameter?" do
    it "returns true for Ruby 3.4+" do
      expect(described_class.parse("3.4").supports_it_parameter?).to be true
      expect(described_class.parse("3.5").supports_it_parameter?).to be true
      expect(described_class.parse("4.0").supports_it_parameter?).to be true
    end

    it "returns false for Ruby < 3.4" do
      expect(described_class.parse("3.3").supports_it_parameter?).to be false
      expect(described_class.parse("3.0").supports_it_parameter?).to be false
    end
  end

  describe "#supports_anonymous_block_forwarding?" do
    it "returns true for Ruby 3.1+" do
      expect(described_class.parse("3.1").supports_anonymous_block_forwarding?).to be true
      expect(described_class.parse("3.4").supports_anonymous_block_forwarding?).to be true
      expect(described_class.parse("4.0").supports_anonymous_block_forwarding?).to be true
    end

    it "returns false for Ruby < 3.1" do
      expect(described_class.parse("3.0").supports_anonymous_block_forwarding?).to be false
    end
  end

  describe "#numbered_parameters_raise_error?" do
    it "returns true for Ruby 4.0+" do
      expect(described_class.parse("4.0").numbered_parameters_raise_error?).to be true
      expect(described_class.parse("4.1").numbered_parameters_raise_error?).to be true
    end

    it "returns false for Ruby < 4.0" do
      expect(described_class.parse("3.4").numbered_parameters_raise_error?).to be false
      expect(described_class.parse("3.0").numbered_parameters_raise_error?).to be false
    end
  end
end
