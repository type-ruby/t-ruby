# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::ErrorReporter do
  let(:reporter) { described_class.new }

  describe "#add" do
    it "adds a diagnostic to the collection" do
      diagnostic = TRuby::Diagnostic.new(code: "TR2001", message: "Error")

      reporter.add(diagnostic)

      expect(reporter.diagnostics).to include(diagnostic)
    end
  end

  describe "#add_type_check_error" do
    it "converts and adds TypeCheckError" do
      error = TRuby::TypeCheckError.new(
        message: "Type mismatch",
        location: "test.trb:5:10",
        expected: "String",
        actual: "Integer"
      )
      source = "line1\nline2\nline3\nline4\ngreet(123)\nline6"

      reporter.add_type_check_error(error, file: "test.trb", source: source)

      expect(reporter.diagnostics.size).to eq(1)
      diagnostic = reporter.diagnostics.first
      expect(diagnostic.code).to eq("TR2001")
      expect(diagnostic.message).to eq("Type mismatch")
      expect(diagnostic.line).to eq(5)
      expect(diagnostic.source_line).to eq("greet(123)")
    end
  end

  describe "#add_parse_error" do
    it "converts and adds ParseError" do
      error = TRuby::ParseError.new("Unexpected token", line: 3, column: 5)
      source = "line1\nline2\ndef foo(: String)\nline4"

      reporter.add_parse_error(error, file: "test.trb", source: source)

      expect(reporter.diagnostics.size).to eq(1)
      diagnostic = reporter.diagnostics.first
      expect(diagnostic.code).to eq("TR1001")
      expect(diagnostic.message).to eq("Unexpected token")
      expect(diagnostic.line).to eq(3)
      expect(diagnostic.source_line).to eq("def foo(: String)")
    end
  end

  describe "#add_scan_error" do
    it "converts and adds ScanError" do
      error = TRuby::Scanner::ScanError.new("Unterminated string", line: 2, column: 10, position: 20)
      source = "line1\n\"unclosed string\nline3"

      reporter.add_scan_error(error, file: "test.trb", source: source)

      expect(reporter.diagnostics.size).to eq(1)
      diagnostic = reporter.diagnostics.first
      expect(diagnostic.code).to eq("TR1001")
      expect(diagnostic.message).to eq("Unterminated string")
    end
  end

  describe "#has_errors?" do
    it "returns false when no diagnostics" do
      expect(reporter.has_errors?).to be false
    end

    it "returns true when there are error-severity diagnostics" do
      reporter.add(TRuby::Diagnostic.new(code: "TR2001", message: "Error", severity: :error))

      expect(reporter.has_errors?).to be true
    end

    it "returns false when only warnings exist" do
      reporter.add(TRuby::Diagnostic.new(code: "TR2001", message: "Warning", severity: :warning))

      expect(reporter.has_errors?).to be false
    end
  end

  describe "#error_count" do
    it "returns 0 when no diagnostics" do
      expect(reporter.error_count).to eq(0)
    end

    it "counts only error-severity diagnostics" do
      reporter.add(TRuby::Diagnostic.new(code: "TR2001", message: "Error 1", severity: :error))
      reporter.add(TRuby::Diagnostic.new(code: "TR2001", message: "Warning", severity: :warning))
      reporter.add(TRuby::Diagnostic.new(code: "TR2001", message: "Error 2", severity: :error))

      expect(reporter.error_count).to eq(2)
    end
  end

  describe "#report" do
    it "returns formatted output using DiagnosticFormatter" do
      reporter.add(
        TRuby::Diagnostic.new(
          code: "TR2001",
          message: "Type mismatch",
          file: "test.trb",
          line: 7,
          column: 5
        )
      )

      result = reporter.report

      expect(result).to include("test.trb:7:5")
      expect(result).to include("TR2001")
      expect(result).to include("Type mismatch")
      expect(result).to include("Found 1 error")
    end

    it "returns empty string when no diagnostics" do
      expect(reporter.report).to eq("")
    end
  end

  describe "#clear" do
    it "removes all diagnostics" do
      reporter.add(TRuby::Diagnostic.new(code: "TR2001", message: "Error"))
      reporter.add(TRuby::Diagnostic.new(code: "TR2002", message: "Error 2"))

      reporter.clear

      expect(reporter.diagnostics).to be_empty
    end
  end

  describe "file source loading" do
    it "loads source from file when not provided" do
      # Create a temp file for testing
      require "tempfile"
      tempfile = Tempfile.new(["test", ".trb"])
      tempfile.write("line1\nline2\nerror_line\nline4")
      tempfile.close

      begin
        error = TRuby::TypeCheckError.new(message: "Error", location: "#{tempfile.path}:3")

        reporter.add_type_check_error(error, file: tempfile.path)

        diagnostic = reporter.diagnostics.first
        expect(diagnostic.source_line).to eq("error_line")
      ensure
        tempfile.unlink
      end
    end
  end
end
