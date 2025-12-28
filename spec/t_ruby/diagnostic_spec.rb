# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::Diagnostic do
  describe "#initialize" do
    it "creates a diagnostic with required attributes" do
      diagnostic = described_class.new(
        code: "TR2001",
        message: "Type mismatch"
      )

      expect(diagnostic.code).to eq("TR2001")
      expect(diagnostic.message).to eq("Type mismatch")
      expect(diagnostic.severity).to eq(:error)
    end

    it "creates a diagnostic with all attributes" do
      diagnostic = described_class.new(
        code: "TR2001",
        message: "Type mismatch",
        file: "test.trb",
        line: 7,
        column: 5,
        end_column: 8,
        severity: :error,
        expected: "String",
        actual: "Integer",
        suggestion: "Use .to_s",
        source_line: "greet(123)"
      )

      expect(diagnostic.code).to eq("TR2001")
      expect(diagnostic.message).to eq("Type mismatch")
      expect(diagnostic.file).to eq("test.trb")
      expect(diagnostic.line).to eq(7)
      expect(diagnostic.column).to eq(5)
      expect(diagnostic.end_column).to eq(8)
      expect(diagnostic.severity).to eq(:error)
      expect(diagnostic.expected).to eq("String")
      expect(diagnostic.actual).to eq("Integer")
      expect(diagnostic.suggestion).to eq("Use .to_s")
      expect(diagnostic.source_line).to eq("greet(123)")
    end

    it "defaults column to 1 when not specified" do
      diagnostic = described_class.new(code: "TR2001", message: "error", line: 5)
      expect(diagnostic.column).to eq(1)
    end

    it "defaults end_column to column + 1 when not specified" do
      diagnostic = described_class.new(code: "TR2001", message: "error", line: 5, column: 3)
      expect(diagnostic.end_column).to eq(4)
    end
  end

  describe ".from_type_check_error" do
    it "converts TypeCheckError to Diagnostic" do
      error = TRuby::TypeCheckError.new(
        message: "Type mismatch",
        location: "test.trb:7:5",
        expected: "String",
        actual: "Integer",
        suggestion: "Use .to_s"
      )
      source = "line1\nline2\nline3\nline4\nline5\nline6\ngreet(123)\nline8"

      diagnostic = described_class.from_type_check_error(error, file: "test.trb", source: source)

      expect(diagnostic.code).to eq("TR2001")
      expect(diagnostic.message).to eq("Type mismatch")
      expect(diagnostic.file).to eq("test.trb")
      expect(diagnostic.line).to eq(7)
      expect(diagnostic.column).to eq(5)
      expect(diagnostic.expected).to eq("String")
      expect(diagnostic.actual).to eq("Integer")
      expect(diagnostic.suggestion).to eq("Use .to_s")
      expect(diagnostic.source_line).to eq("greet(123)")
    end

    it "handles location with only line number" do
      error = TRuby::TypeCheckError.new(
        message: "Type mismatch",
        location: "line 7"
      )

      diagnostic = described_class.from_type_check_error(error, file: "test.trb")

      expect(diagnostic.line).to eq(7)
      expect(diagnostic.column).to eq(1)
    end

    it "handles location with file:line format" do
      error = TRuby::TypeCheckError.new(
        message: "Type mismatch",
        location: "test.trb:10"
      )

      diagnostic = described_class.from_type_check_error(error, file: "test.trb")

      expect(diagnostic.line).to eq(10)
      expect(diagnostic.column).to eq(1)
    end

    it "handles nil location" do
      error = TRuby::TypeCheckError.new(message: "Type mismatch")

      diagnostic = described_class.from_type_check_error(error, file: "test.trb")

      expect(diagnostic.line).to be_nil
      expect(diagnostic.column).to eq(1)
    end
  end

  describe ".from_parse_error" do
    it "converts ParseError to Diagnostic" do
      error = TRuby::ParseError.new(
        "Unexpected token",
        line: 5,
        column: 10,
        source: "def foo(: String)"
      )

      diagnostic = described_class.from_parse_error(error, file: "test.trb")

      expect(diagnostic.code).to eq("TR1001")
      expect(diagnostic.message).to eq("Unexpected token")
      expect(diagnostic.file).to eq("test.trb")
      expect(diagnostic.line).to eq(5)
      expect(diagnostic.column).to eq(10)
    end

    it "extracts source_line from source parameter" do
      source = "line1\nline2\nline3\nline4\ndef foo(: String)\nline6"
      error = TRuby::ParseError.new("Unexpected token", line: 5, column: 10)

      diagnostic = described_class.from_parse_error(error, file: "test.trb", source: source)

      expect(diagnostic.source_line).to eq("def foo(: String)")
    end
  end

  describe ".from_scan_error" do
    it "converts ScanError to Diagnostic" do
      error = TRuby::Scanner::ScanError.new("Unterminated string", line: 3, column: 15, position: 50)

      diagnostic = described_class.from_scan_error(error, file: "test.trb")

      expect(diagnostic.code).to eq("TR1001")
      expect(diagnostic.message).to eq("Unterminated string")
      expect(diagnostic.file).to eq("test.trb")
      expect(diagnostic.line).to eq(3)
      expect(diagnostic.column).to eq(15)
    end

    it "strips location info from message (added by ScanError constructor)" do
      # ScanError constructor automatically appends " at line X, column Y" to message
      # So "Unterminated string" becomes "Unterminated string at line 3, column 15"
      error = TRuby::Scanner::ScanError.new(
        "Unterminated string",
        line: 3,
        column: 15,
        position: 50
      )

      diagnostic = described_class.from_scan_error(error, file: "test.trb")

      # from_scan_error should strip the auto-added location suffix
      expect(diagnostic.message).to eq("Unterminated string")
    end
  end

  describe "#error?" do
    it "returns true for error severity" do
      diagnostic = described_class.new(code: "TR2001", message: "error", severity: :error)
      expect(diagnostic.error?).to be true
    end

    it "returns false for warning severity" do
      diagnostic = described_class.new(code: "TR2001", message: "warning", severity: :warning)
      expect(diagnostic.error?).to be false
    end
  end
end
