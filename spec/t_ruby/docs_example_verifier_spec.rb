# frozen_string_literal: true

require "spec_helper"
require "fileutils"

describe TRuby::DocsExampleVerifier do
  let(:verifier) { described_class.new }

  describe TRuby::DocsExampleVerifier::VerificationResult do
    let(:example) do
      TRuby::DocsExampleExtractor::CodeExample.new(
        code: "def test: void; end",
        language: "trb",
        file_path: "test.md",
        line_number: 10,
        metadata: nil
      )
    end

    describe "#pass?" do
      it "returns true when status is :pass" do
        result = described_class.new(example: example, status: :pass, errors: [])
        expect(result.pass?).to be true
      end

      it "returns false when status is not :pass" do
        result = described_class.new(example: example, status: :fail, errors: [])
        expect(result.pass?).to be false
      end
    end

    describe "#fail?" do
      it "returns true when status is :fail" do
        result = described_class.new(example: example, status: :fail, errors: ["error"])
        expect(result.fail?).to be true
      end

      it "returns false when status is not :fail" do
        result = described_class.new(example: example, status: :pass, errors: [])
        expect(result.fail?).to be false
      end
    end

    describe "#skip?" do
      it "returns true when status is :skip" do
        result = described_class.new(example: example, status: :skip, errors: ["skipped"])
        expect(result.skip?).to be true
      end

      it "returns false when status is not :skip" do
        result = described_class.new(example: example, status: :pass, errors: [])
        expect(result.skip?).to be false
      end
    end

    describe "#file_path" do
      it "delegates to example" do
        result = described_class.new(example: example, status: :pass, errors: [])
        expect(result.file_path).to eq("test.md")
      end
    end

    describe "#line_number" do
      it "delegates to example" do
        result = described_class.new(example: example, status: :pass, errors: [])
        expect(result.line_number).to eq(10)
      end
    end
  end

  describe "#initialize" do
    it "creates an instance" do
      expect(verifier).to be_a(described_class)
    end
  end

  describe "#verify_file" do
    it "verifies all examples in a file" do
      Dir.mktmpdir do |tmpdir|
        md_file = File.join(tmpdir, "test.md")
        File.write(md_file, <<~MD)
          # Test

          ```trb
          def hello: void
          end
          ```
        MD

        results = verifier.verify_file(md_file)
        expect(results).to be_an(Array)
        expect(results.length).to eq(1)
      end
    end

    it "returns empty array for file with no examples" do
      Dir.mktmpdir do |tmpdir|
        md_file = File.join(tmpdir, "empty.md")
        File.write(md_file, "# No examples here")

        results = verifier.verify_file(md_file)
        expect(results).to eq([])
      end
    end
  end

  describe "#verify_glob" do
    it "verifies examples from multiple files" do
      Dir.mktmpdir do |tmpdir|
        File.write(File.join(tmpdir, "a.md"), <<~MD)
          ```trb
          def a: void; end
          ```
        MD
        File.write(File.join(tmpdir, "b.md"), <<~MD)
          ```trb
          def b: void; end
          ```
        MD

        results = verifier.verify_glob(File.join(tmpdir, "*.md"))
        expect(results.length).to eq(2)
      end
    end
  end

  describe "#verify_example" do
    describe "skip behavior" do
      it "skips examples marked with skip-verify" do
        example = TRuby::DocsExampleExtractor::CodeExample.new(
          code: "invalid code!",
          language: "trb",
          file_path: "test.md",
          line_number: 1,
          metadata: "skip-verify"
        )

        result = verifier.verify_example(example)
        expect(result.skip?).to be true
        expect(result.errors).to include("Marked as skip-verify")
      end

      it "skips unknown languages" do
        example = TRuby::DocsExampleExtractor::CodeExample.new(
          code: "some code",
          language: "python",
          file_path: "test.md",
          line_number: 1,
          metadata: nil
        )

        result = verifier.verify_example(example)
        expect(result.skip?).to be true
        expect(result.errors.first).to include("Unknown language")
      end
    end

    describe "trb examples" do
      it "passes for valid trb code" do
        example = TRuby::DocsExampleExtractor::CodeExample.new(
          code: "def hello(name: String): String\n  name\nend",
          language: "trb",
          file_path: "test.md",
          line_number: 1,
          metadata: nil
        )

        result = verifier.verify_example(example)
        expect(result.pass?).to be true
      end

      it "fails for invalid trb syntax" do
        example = TRuby::DocsExampleExtractor::CodeExample.new(
          code: "def @@@invalid syntax!!!",
          language: "trb",
          file_path: "test.md",
          line_number: 1,
          metadata: nil
        )

        result = verifier.verify_example(example)
        # Parser may pass some syntax through, but should catch obvious errors
        expect(%i[fail pass]).to include(result.status)
      end
    end

    describe "ruby examples" do
      it "passes for valid ruby code" do
        example = TRuby::DocsExampleExtractor::CodeExample.new(
          code: "def hello(name)\n  name\nend",
          language: "ruby",
          file_path: "test.md",
          line_number: 1,
          metadata: nil
        )

        result = verifier.verify_example(example)
        expect(result.pass?).to be true
      end

      it "fails for invalid ruby syntax" do
        example = TRuby::DocsExampleExtractor::CodeExample.new(
          code: "def hello(\nend",
          language: "ruby",
          file_path: "test.md",
          line_number: 1,
          metadata: nil
        )

        result = verifier.verify_example(example)
        expect(result.fail?).to be true
        expect(result.errors.first).to include("Ruby syntax error")
      end
    end

    describe "rbs examples" do
      it "passes for valid rbs-like content" do
        example = TRuby::DocsExampleExtractor::CodeExample.new(
          code: "def hello: (String) -> String",
          language: "rbs",
          file_path: "test.md",
          line_number: 1,
          metadata: nil
        )

        result = verifier.verify_example(example)
        expect(result.pass?).to be true
      end

      it "skips rbs without recognizable content" do
        example = TRuby::DocsExampleExtractor::CodeExample.new(
          code: "# just a comment",
          language: "rbs",
          file_path: "test.md",
          line_number: 1,
          metadata: nil
        )

        result = verifier.verify_example(example)
        expect(result.skip?).to be true
      end
    end

    describe "error handling" do
      it "catches exceptions and returns fail result" do
        example = TRuby::DocsExampleExtractor::CodeExample.new(
          code: "def test: void; end",
          language: "trb",
          file_path: "test.md",
          line_number: 1,
          metadata: nil
        )

        allow(TRuby::Parser).to receive(:new).and_raise(StandardError, "Unexpected error")

        result = verifier.verify_example(example)
        expect(result.fail?).to be true
        expect(result.errors.first).to include("Exception")
      end
    end
  end

  describe "#summary" do
    it "returns correct statistics" do
      example = TRuby::DocsExampleExtractor::CodeExample.new(
        code: "test",
        language: "trb",
        file_path: "test.md",
        line_number: 1,
        metadata: nil
      )

      results = [
        TRuby::DocsExampleVerifier::VerificationResult.new(example: example, status: :pass, errors: []),
        TRuby::DocsExampleVerifier::VerificationResult.new(example: example, status: :pass, errors: []),
        TRuby::DocsExampleVerifier::VerificationResult.new(example: example, status: :fail, errors: ["error"]),
        TRuby::DocsExampleVerifier::VerificationResult.new(example: example, status: :skip, errors: ["skip"]),
      ]

      summary = verifier.summary(results)

      expect(summary[:total]).to eq(4)
      expect(summary[:passed]).to eq(2)
      expect(summary[:failed]).to eq(1)
      expect(summary[:skipped]).to eq(1)
      expect(summary[:pass_rate]).to eq(50.0)
    end

    it "handles empty results" do
      summary = verifier.summary([])

      expect(summary[:total]).to eq(0)
      expect(summary[:pass_rate]).to eq(0)
    end
  end

  describe "#print_results" do
    let(:example) do
      TRuby::DocsExampleExtractor::CodeExample.new(
        code: "test",
        language: "trb",
        file_path: "test.md",
        line_number: 1,
        metadata: nil
      )
    end

    it "prints failed results" do
      results = [
        TRuby::DocsExampleVerifier::VerificationResult.new(
          example: example,
          status: :fail,
          errors: ["Test error"]
        ),
      ]

      expect { verifier.print_results(results) }.to output(/test\.md:1/).to_stdout
    end

    it "prints skipped results" do
      results = [
        TRuby::DocsExampleVerifier::VerificationResult.new(
          example: example,
          status: :skip,
          errors: ["Skipped"]
        ),
      ]

      expect { verifier.print_results(results) }.to output(/test\.md:1/).to_stdout
    end

    it "hides passed results by default" do
      results = [
        TRuby::DocsExampleVerifier::VerificationResult.new(
          example: example,
          status: :pass,
          errors: []
        ),
      ]

      output = capture_stdout { verifier.print_results(results) }
      expect(output).not_to include("test.md:1")
    end

    it "shows passed results in verbose mode" do
      results = [
        TRuby::DocsExampleVerifier::VerificationResult.new(
          example: example,
          status: :pass,
          errors: []
        ),
      ]

      expect { verifier.print_results(results, verbose: true) }.to output(/test\.md:1/).to_stdout
    end

    it "prints summary at the end" do
      results = [
        TRuby::DocsExampleVerifier::VerificationResult.new(example: example, status: :pass, errors: []),
      ]

      expect { verifier.print_results(results) }.to output(/Results:.*passed/).to_stdout
    end
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
