# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::DiagnosticFormatter do
  let(:formatter) { described_class.new(use_colors: false) }
  let(:colored_formatter) { described_class.new(use_colors: true) }

  let(:simple_diagnostic) do
    TRuby::Diagnostic.new(
      code: "TR2001",
      message: "Type mismatch",
      file: "test.trb",
      line: 7,
      column: 5
    )
  end

  let(:full_diagnostic) do
    TRuby::Diagnostic.new(
      code: "TR2001",
      message: "Type mismatch in argument 'name'",
      file: "src/hello.trb",
      line: 7,
      column: 7,
      end_column: 10,
      severity: :error,
      expected: "String",
      actual: "Integer",
      suggestion: "Use .to_s to convert",
      source_line: "greet(123)"
    )
  end

  let(:warning_diagnostic) do
    TRuby::Diagnostic.new(
      code: "TR2010",
      message: "Unused variable",
      file: "test.trb",
      line: 5,
      column: 1,
      severity: :warning
    )
  end

  describe "#format" do
    context "with simple diagnostic" do
      it "formats header with file:line:col - error CODE: message" do
        result = formatter.format(simple_diagnostic)

        expect(result).to include("test.trb:7:5")
        expect(result).to include("error")
        expect(result).to include("TR2001")
        expect(result).to include("Type mismatch")
      end
    end

    context "with full diagnostic" do
      it "includes source code snippet" do
        result = formatter.format(full_diagnostic)

        expect(result).to include("7 |")
        expect(result).to include("greet(123)")
      end

      it "includes error marker (~~~)" do
        result = formatter.format(full_diagnostic)

        # Marker should be under the error position (column 7, width 3)
        expect(result).to include("~~~")
      end

      it "includes expected/actual context" do
        result = formatter.format(full_diagnostic)

        expect(result).to include("Expected:")
        expect(result).to include("String")
        expect(result).to include("Actual:")
        expect(result).to include("Integer")
      end

      it "includes suggestion" do
        result = formatter.format(full_diagnostic)

        expect(result).to include("Suggestion:")
        expect(result).to include("Use .to_s to convert")
      end
    end

    context "with warning severity" do
      it "shows 'warning' instead of 'error'" do
        result = formatter.format(warning_diagnostic)

        expect(result).to include("warning")
        expect(result).not_to include("error")
      end
    end

    context "without source line" do
      it "only shows header without code snippet" do
        diagnostic = TRuby::Diagnostic.new(
          code: "TR2001",
          message: "Type mismatch",
          file: "test.trb",
          line: 7,
          column: 5
        )

        result = formatter.format(diagnostic)

        expect(result).to include("test.trb:7:5")
        expect(result).not_to include(" | ")
      end
    end

    context "without file info" do
      it "shows <unknown> for file" do
        diagnostic = TRuby::Diagnostic.new(
          code: "TR2001",
          message: "Type mismatch"
        )

        result = formatter.format(diagnostic)

        expect(result).to include("<unknown>")
      end
    end
  end

  describe "#format_all" do
    it "formats multiple diagnostics with blank lines between" do
      diagnostics = [simple_diagnostic, full_diagnostic]

      result = formatter.format_all(diagnostics)

      expect(result).to include("test.trb:7:5")
      expect(result).to include("src/hello.trb:7:7")
    end

    it "includes summary line" do
      diagnostics = [simple_diagnostic, full_diagnostic]

      result = formatter.format_all(diagnostics)

      expect(result).to include("Found 2 errors.")
    end

    it "shows singular 'error' for one error" do
      diagnostics = [simple_diagnostic]

      result = formatter.format_all(diagnostics)

      expect(result).to include("Found 1 error.")
    end

    it "shows warnings and errors separately in summary" do
      diagnostics = [simple_diagnostic, warning_diagnostic]

      result = formatter.format_all(diagnostics)

      expect(result).to include("1 error")
      expect(result).to include("1 warning")
    end

    it "returns empty string for empty array" do
      result = formatter.format_all([])

      expect(result).to eq("")
    end
  end

  describe "color support" do
    it "adds ANSI color codes when use_colors is true" do
      result = colored_formatter.format(simple_diagnostic)

      # Should contain ANSI escape codes
      expect(result).to include("\e[")
    end

    it "does not add color codes when use_colors is false" do
      result = formatter.format(simple_diagnostic)

      expect(result).not_to include("\e[")
    end
  end

  describe "marker width calculation" do
    it "uses end_column - column for width when available" do
      diagnostic = TRuby::Diagnostic.new(
        code: "TR2001",
        message: "Error",
        file: "test.trb",
        line: 1,
        column: 5,
        end_column: 10,
        source_line: "hello world"
      )

      result = formatter.format(diagnostic)

      # Width should be 5 (10 - 5)
      expect(result).to include("~~~~~")
    end

    it "guesses width from identifier in source when end_column not available" do
      diagnostic = TRuby::Diagnostic.new(
        code: "TR2001",
        message: "Error",
        file: "test.trb",
        line: 1,
        column: 1,
        source_line: "hello world"
      )

      result = formatter.format(diagnostic)

      # Should guess width from "hello" (5 chars)
      expect(result).to include("~~~~~")
    end
  end
end
