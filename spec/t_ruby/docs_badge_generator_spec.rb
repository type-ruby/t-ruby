# frozen_string_literal: true

require "spec_helper"
require "fileutils"

describe TRuby::DocsBadgeGenerator do
  let(:generator) { described_class.new }

  let(:example) do
    TRuby::DocsExampleExtractor::CodeExample.new(
      code: "test",
      language: "trb",
      file_path: "docs/test.md",
      line_number: 10,
      metadata: nil
    )
  end

  let(:pass_result) do
    TRuby::DocsExampleVerifier::VerificationResult.new(
      example: example,
      status: :pass,
      errors: []
    )
  end

  let(:fail_result) do
    TRuby::DocsExampleVerifier::VerificationResult.new(
      example: example,
      status: :fail,
      errors: ["Test error"]
    )
  end

  let(:skip_result) do
    TRuby::DocsExampleVerifier::VerificationResult.new(
      example: example,
      status: :skip,
      errors: ["Skipped"]
    )
  end

  describe "COLORS" do
    it "defines color constants" do
      expect(described_class::COLORS).to be_a(Hash)
      expect(described_class::COLORS[:excellent]).to eq("brightgreen")
      expect(described_class::COLORS[:good]).to eq("green")
      expect(described_class::COLORS[:fair]).to eq("yellow")
      expect(described_class::COLORS[:poor]).to eq("orange")
      expect(described_class::COLORS[:critical]).to eq("red")
    end
  end

  describe "#initialize" do
    it "creates an instance" do
      expect(generator).to be_a(described_class)
    end
  end

  describe "#generate_all" do
    it "generates all output files" do
      results = [pass_result, pass_result, fail_result]

      Dir.mktmpdir do |tmpdir|
        generator.generate_all(results, tmpdir)

        expect(File.exist?(File.join(tmpdir, "docs_badge.json"))).to be true
        expect(File.exist?(File.join(tmpdir, "docs_badge.svg"))).to be true
        expect(File.exist?(File.join(tmpdir, "docs_report.json"))).to be true
        expect(File.exist?(File.join(tmpdir, "docs_report.md"))).to be true
      end
    end

    it "creates output directory if not exists" do
      results = [pass_result]

      Dir.mktmpdir do |tmpdir|
        output_dir = File.join(tmpdir, "nested", "output")
        generator.generate_all(results, output_dir)

        expect(Dir.exist?(output_dir)).to be true
      end
    end
  end

  describe "#generate_badge_json" do
    it "generates Shields.io compatible JSON" do
      results = [pass_result, pass_result, fail_result, skip_result]

      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "badge.json")
        generator.generate_badge_json(results, path)

        badge = JSON.parse(File.read(path))
        expect(badge["schemaVersion"]).to eq(1)
        expect(badge["label"]).to eq("docs examples")
        expect(badge["message"]).to include("%")
        expect(badge["color"]).to be_a(String)
      end
    end

    it "shows correct pass rate" do
      results = [pass_result, pass_result, pass_result, fail_result] # 75%

      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "badge.json")
        generator.generate_badge_json(results, path)

        badge = JSON.parse(File.read(path))
        expect(badge["message"]).to eq("75.0%")
      end
    end

    it "uses correct color based on rate" do
      # Test excellent (100%)
      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "badge.json")
        generator.generate_badge_json([pass_result], path)

        badge = JSON.parse(File.read(path))
        expect(badge["color"]).to eq("brightgreen")
      end
    end
  end

  describe "#generate_badge_svg" do
    it "generates valid SVG" do
      results = [pass_result, fail_result]

      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "badge.svg")
        generator.generate_badge_svg(results, path)

        svg = File.read(path)
        expect(svg).to include("<svg")
        expect(svg).to include("xmlns")
        expect(svg).to include("docs examples")
        expect(svg).to include("%")
      end
    end

    it "uses correct color in SVG" do
      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "badge.svg")
        generator.generate_badge_svg([pass_result], path)

        svg = File.read(path)
        expect(svg).to include("#4c1") # bright green for 100%
      end
    end
  end

  describe "#generate_report_json" do
    it "generates JSON report with summary" do
      results = [pass_result, fail_result]

      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "report.json")
        generator.generate_report_json(results, path)

        report = JSON.parse(File.read(path))
        expect(report).to have_key("generated_at")
        expect(report).to have_key("summary")
        expect(report).to have_key("files")
      end
    end

    it "includes summary statistics" do
      results = [pass_result, pass_result, fail_result, skip_result]

      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "report.json")
        generator.generate_report_json(results, path)

        report = JSON.parse(File.read(path))
        summary = report["summary"]
        expect(summary["total"]).to eq(4)
        expect(summary["passed"]).to eq(2)
        expect(summary["failed"]).to eq(1)
        expect(summary["skipped"]).to eq(1)
      end
    end

    it "groups results by file" do
      ex1 = TRuby::DocsExampleExtractor::CodeExample.new(
        code: "test", language: "trb", file_path: "a.md", line_number: 1, metadata: nil
      )
      ex2 = TRuby::DocsExampleExtractor::CodeExample.new(
        code: "test", language: "trb", file_path: "b.md", line_number: 1, metadata: nil
      )

      results = [
        TRuby::DocsExampleVerifier::VerificationResult.new(example: ex1, status: :pass, errors: []),
        TRuby::DocsExampleVerifier::VerificationResult.new(example: ex2, status: :pass, errors: []),
      ]

      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "report.json")
        generator.generate_report_json(results, path)

        report = JSON.parse(File.read(path))
        expect(report["files"].keys).to include("a.md", "b.md")
      end
    end
  end

  describe "#generate_report_markdown" do
    it "generates Markdown report" do
      results = [pass_result, fail_result]

      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "report.md")
        generator.generate_report_markdown(results, path)

        markdown = File.read(path)
        expect(markdown).to include("# Documentation Examples Verification Report")
        expect(markdown).to include("## Summary")
        expect(markdown).to include("## Results by File")
      end
    end

    it "includes summary table" do
      results = [pass_result, fail_result]

      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "report.md")
        generator.generate_report_markdown(results, path)

        markdown = File.read(path)
        expect(markdown).to include("| Total Examples |")
        expect(markdown).to include("| Passed |")
        expect(markdown).to include("| Failed |")
        expect(markdown).to include("| **Pass Rate** |")
      end
    end

    it "shows failed examples with details" do
      results = [fail_result]

      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "report.md")
        generator.generate_report_markdown(results, path)

        markdown = File.read(path)
        expect(markdown).to include("**Failed examples:**")
        expect(markdown).to include("Line 10")
        expect(markdown).to include("Test error")
      end
    end

    it "uses checkmark for files with no failures" do
      results = [pass_result]

      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "report.md")
        generator.generate_report_markdown(results, path)

        markdown = File.read(path)
        expect(markdown).to include("✅")
      end
    end

    it "uses X for files with failures" do
      results = [fail_result]

      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "report.md")
        generator.generate_report_markdown(results, path)

        markdown = File.read(path)
        expect(markdown).to include("❌")
      end
    end
  end

  describe "private methods" do
    describe "#color_for_rate" do
      it "returns brightgreen for excellent rate (95-100)" do
        expect(generator.send(:color_for_rate, 100)).to eq("brightgreen")
        expect(generator.send(:color_for_rate, 95)).to eq("brightgreen")
      end

      it "returns green for good rate (80-94)" do
        expect(generator.send(:color_for_rate, 94)).to eq("green")
        expect(generator.send(:color_for_rate, 80)).to eq("green")
      end

      it "returns yellow for fair rate (60-79)" do
        expect(generator.send(:color_for_rate, 79)).to eq("yellow")
        expect(generator.send(:color_for_rate, 60)).to eq("yellow")
      end

      it "returns orange for poor rate (40-59)" do
        expect(generator.send(:color_for_rate, 59)).to eq("orange")
        expect(generator.send(:color_for_rate, 40)).to eq("orange")
      end

      it "returns red for critical rate (0-39)" do
        expect(generator.send(:color_for_rate, 39)).to eq("red")
        expect(generator.send(:color_for_rate, 0)).to eq("red")
      end
    end

    describe "#svg_color_for_rate" do
      it "returns hex color codes" do
        expect(generator.send(:svg_color_for_rate, 100)).to eq("#4c1")
        expect(generator.send(:svg_color_for_rate, 85)).to eq("#97ca00")
        expect(generator.send(:svg_color_for_rate, 70)).to eq("#dfb317")
        expect(generator.send(:svg_color_for_rate, 50)).to eq("#fe7d37")
        expect(generator.send(:svg_color_for_rate, 20)).to eq("#e05d44")
      end
    end

    describe "#group_results_by_file" do
      it "groups results by file_path" do
        ex1 = TRuby::DocsExampleExtractor::CodeExample.new(
          code: "test", language: "trb", file_path: "a.md", line_number: 1, metadata: nil
        )
        ex2 = TRuby::DocsExampleExtractor::CodeExample.new(
          code: "test", language: "trb", file_path: "a.md", line_number: 5, metadata: nil
        )
        ex3 = TRuby::DocsExampleExtractor::CodeExample.new(
          code: "test", language: "trb", file_path: "b.md", line_number: 1, metadata: nil
        )

        results = [
          TRuby::DocsExampleVerifier::VerificationResult.new(example: ex1, status: :pass, errors: []),
          TRuby::DocsExampleVerifier::VerificationResult.new(example: ex2, status: :pass, errors: []),
          TRuby::DocsExampleVerifier::VerificationResult.new(example: ex3, status: :pass, errors: []),
        ]

        grouped = generator.send(:group_results_by_file, results)
        expect(grouped.keys).to eq(["a.md", "b.md"])
        expect(grouped["a.md"].length).to eq(2)
        expect(grouped["b.md"].length).to eq(1)
      end
    end
  end
end
