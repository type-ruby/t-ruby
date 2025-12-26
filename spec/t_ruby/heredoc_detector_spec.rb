# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::HeredocDetector do
  describe ".detect" do
    it "detects simple heredoc" do
      lines = [
        "text = <<EOT",
        "Hello world",
        "EOT",
        "other_code",
      ]
      ranges = described_class.detect(lines)

      expect(ranges).to eq([1..2])
    end

    it "detects heredoc with dash" do
      lines = [
        "text = <<-SQL",
        "  SELECT * FROM users",
        "SQL",
        "puts text",
      ]
      ranges = described_class.detect(lines)

      expect(ranges).to eq([1..2])
    end

    it "detects squiggly heredoc" do
      lines = [
        "html = <<~HTML",
        "  <div>",
        "    <p>Hello</p>",
        "  </div>",
        "HTML",
        "render html",
      ]
      ranges = described_class.detect(lines)

      expect(ranges).to eq([1..4])
    end

    it "detects multiple heredocs" do
      lines = [
        "a = <<A",
        "content a",
        "A",
        "b = <<B",
        "content b",
        "B",
      ]
      ranges = described_class.detect(lines)

      expect(ranges).to eq([1..2, 4..5])
    end

    it "handles quoted delimiters" do
      lines = [
        "text = <<'EOF'",
        "literal content",
        "EOF",
      ]
      ranges = described_class.detect(lines)

      expect(ranges).to eq([1..2])
    end

    it "detects =begin/=end block comments" do
      lines = [
        "=begin",
        "This is a comment",
        "def fake(x: String): Integer",
        "=end",
        "def real(): String",
      ]
      ranges = described_class.detect(lines)

      expect(ranges).to eq([0..3])
    end

    it "detects multiple block comments" do
      lines = [
        "=begin",
        "first comment",
        "=end",
        "code_here",
        "=begin",
        "second comment",
        "=end",
      ]
      ranges = described_class.detect(lines)

      expect(ranges).to eq([0..2, 4..6])
    end

    it "handles mixed heredocs and block comments" do
      lines = [
        "=begin",
        "comment",
        "=end",
        "text = <<EOT",
        "heredoc content",
        "EOT",
      ]
      ranges = described_class.detect(lines)

      expect(ranges).to eq([0..2, 4..5])
    end
  end

  describe ".inside_heredoc?" do
    let(:ranges) { [1..3, 5..7] }

    it "returns false for heredoc start line" do
      expect(described_class.inside_heredoc?(0, ranges)).to be false
    end

    it "returns true for lines inside heredoc" do
      expect(described_class.inside_heredoc?(1, ranges)).to be true
      expect(described_class.inside_heredoc?(2, ranges)).to be true
      expect(described_class.inside_heredoc?(3, ranges)).to be true
    end

    it "returns false for lines between heredocs" do
      expect(described_class.inside_heredoc?(4, ranges)).to be false
    end

    it "returns true for second heredoc content" do
      expect(described_class.inside_heredoc?(5, ranges)).to be true
      expect(described_class.inside_heredoc?(6, ranges)).to be true
    end

    it "returns false for lines after all heredocs" do
      expect(described_class.inside_heredoc?(8, ranges)).to be false
    end
  end
end
