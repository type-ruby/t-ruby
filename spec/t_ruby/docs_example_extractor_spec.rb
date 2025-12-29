# frozen_string_literal: true

require "spec_helper"
require "fileutils"

describe TRuby::DocsExampleExtractor do
  let(:extractor) { described_class.new }

  describe TRuby::DocsExampleExtractor::CodeExample do
    let(:example) do
      described_class.new(
        code: "def test: void; end",
        language: "trb",
        file_path: "docs/test.md",
        line_number: 10,
        metadata: nil
      )
    end

    describe "#trb?" do
      it "returns true for trb language" do
        expect(example.trb?).to be true
      end

      it "returns true for t-ruby language" do
        ex = described_class.new(code: "", language: "t-ruby", file_path: "", line_number: 1, metadata: nil)
        expect(ex.trb?).to be true
      end

      it "returns false for other languages" do
        ex = described_class.new(code: "", language: "ruby", file_path: "", line_number: 1, metadata: nil)
        expect(ex.trb?).to be false
      end
    end

    describe "#ruby?" do
      it "returns true for ruby language" do
        ex = described_class.new(code: "", language: "ruby", file_path: "", line_number: 1, metadata: nil)
        expect(ex.ruby?).to be true
      end

      it "returns false for other languages" do
        expect(example.ruby?).to be false
      end
    end

    describe "#rbs?" do
      it "returns true for rbs language" do
        ex = described_class.new(code: "", language: "rbs", file_path: "", line_number: 1, metadata: nil)
        expect(ex.rbs?).to be true
      end

      it "returns false for other languages" do
        expect(example.rbs?).to be false
      end
    end

    describe "#should_verify?" do
      it "returns true by default" do
        expect(example.should_verify?).to be true
      end

      it "returns false with skip-verify metadata" do
        ex = described_class.new(code: "", language: "trb", file_path: "", line_number: 1, metadata: "skip-verify")
        expect(ex.should_verify?).to be false
      end
    end

    describe "#should_compile?" do
      it "returns true by default" do
        expect(example.should_compile?).to be true
      end

      it "returns false with no-compile metadata" do
        ex = described_class.new(code: "", language: "trb", file_path: "", line_number: 1, metadata: "no-compile")
        expect(ex.should_compile?).to be false
      end
    end

    describe "#should_typecheck?" do
      it "returns true by default" do
        expect(example.should_typecheck?).to be true
      end

      it "returns false with no-typecheck metadata" do
        ex = described_class.new(code: "", language: "trb", file_path: "", line_number: 1, metadata: "no-typecheck")
        expect(ex.should_typecheck?).to be false
      end
    end
  end

  describe "#extract_from_file" do
    it "extracts trb code blocks" do
      Dir.mktmpdir do |tmpdir|
        md_file = File.join(tmpdir, "test.md")
        File.write(md_file, <<~MD)
          # Test

          ```trb
          def hello: void
          end
          ```
        MD

        examples = extractor.extract_from_file(md_file)
        expect(examples.length).to eq(1)
        expect(examples.first.language).to eq("trb")
        expect(examples.first.code).to include("def hello")
      end
    end

    it "extracts ruby code blocks" do
      Dir.mktmpdir do |tmpdir|
        md_file = File.join(tmpdir, "test.md")
        File.write(md_file, <<~MD)
          ```ruby
          def hello
            puts "hello"
          end
          ```
        MD

        examples = extractor.extract_from_file(md_file)
        expect(examples.length).to eq(1)
        expect(examples.first.language).to eq("ruby")
      end
    end

    it "extracts rbs code blocks" do
      Dir.mktmpdir do |tmpdir|
        md_file = File.join(tmpdir, "test.md")
        File.write(md_file, <<~MD)
          ```rbs
          def hello: (String) -> void
          ```
        MD

        examples = extractor.extract_from_file(md_file)
        expect(examples.length).to eq(1)
        expect(examples.first.language).to eq("rbs")
      end
    end

    it "ignores non-relevant languages" do
      Dir.mktmpdir do |tmpdir|
        md_file = File.join(tmpdir, "test.md")
        File.write(md_file, <<~MD)
          ```python
          print("hello")
          ```

          ```javascript
          console.log("hello");
          ```
        MD

        examples = extractor.extract_from_file(md_file)
        expect(examples).to be_empty
      end
    end

    it "captures line numbers correctly" do
      Dir.mktmpdir do |tmpdir|
        md_file = File.join(tmpdir, "test.md")
        File.write(md_file, <<~MD)
          # Header

          Some text

          ```trb
          def test: void
          end
          ```
        MD

        examples = extractor.extract_from_file(md_file)
        expect(examples.first.line_number).to eq(5)
      end
    end

    it "captures metadata from code fence" do
      Dir.mktmpdir do |tmpdir|
        md_file = File.join(tmpdir, "test.md")
        File.write(md_file, <<~MD)
          ```trb {skip-verify}
          def test: void
          end
          ```
        MD

        examples = extractor.extract_from_file(md_file)
        expect(examples.first.metadata).to eq("skip-verify")
      end
    end

    it "handles Docusaurus title attribute" do
      Dir.mktmpdir do |tmpdir|
        md_file = File.join(tmpdir, "test.md")
        File.write(md_file, <<~MD)
          ```ruby title="example.trb"
          def test: void
          end
          ```
        MD

        examples = extractor.extract_from_file(md_file)
        expect(examples.first.language).to eq("trb")
      end
    end
  end

  describe "#extract_from_content" do
    it "extracts from content string" do
      content = <<~MD
        ```trb
        def test: void; end
        ```
      MD

      examples = extractor.extract_from_content(content)
      expect(examples.length).to eq(1)
    end

    it "uses default file_path" do
      content = "```trb\ntest\n```"
      examples = extractor.extract_from_content(content)
      expect(examples.first.file_path).to eq("<string>")
    end

    it "uses provided file_path" do
      content = "```trb\ntest\n```"
      examples = extractor.extract_from_content(content, "custom.md")
      expect(examples.first.file_path).to eq("custom.md")
    end
  end

  describe "#extract_from_glob" do
    it "extracts from multiple files" do
      Dir.mktmpdir do |tmpdir|
        File.write(File.join(tmpdir, "a.md"), "```trb\ndef a: void; end\n```")
        File.write(File.join(tmpdir, "b.md"), "```trb\ndef b: void; end\n```")

        examples = extractor.extract_from_glob(File.join(tmpdir, "*.md"))
        expect(examples.length).to eq(2)
      end
    end
  end

  describe "#statistics" do
    it "calculates statistics correctly" do
      examples = [
        TRuby::DocsExampleExtractor::CodeExample.new(
          code: "", language: "trb", file_path: "a.md", line_number: 1, metadata: nil
        ),
        TRuby::DocsExampleExtractor::CodeExample.new(
          code: "", language: "ruby", file_path: "a.md", line_number: 5, metadata: nil
        ),
        TRuby::DocsExampleExtractor::CodeExample.new(
          code: "", language: "rbs", file_path: "b.md", line_number: 1, metadata: nil
        ),
        TRuby::DocsExampleExtractor::CodeExample.new(
          code: "", language: "trb", file_path: "b.md", line_number: 5, metadata: "skip-verify"
        ),
      ]

      stats = extractor.statistics(examples)

      expect(stats[:total]).to eq(4)
      expect(stats[:trb]).to eq(2)
      expect(stats[:ruby]).to eq(1)
      expect(stats[:rbs]).to eq(1)
      expect(stats[:verifiable]).to eq(3)
      expect(stats[:files]).to eq(2)
    end
  end

  describe "CODE_FENCE_PATTERN" do
    it "matches basic code fence" do
      expect("```trb").to match(described_class::CODE_FENCE_PATTERN)
    end

    it "matches code fence with title" do
      match = '```ruby title="example.trb"'.match(described_class::CODE_FENCE_PATTERN)
      expect(match[1]).to eq("ruby")
      expect(match[2]).to eq("example.trb")
    end

    it "matches code fence with metadata" do
      match = "```trb {skip-verify}".match(described_class::CODE_FENCE_PATTERN)
      expect(match[1]).to eq("trb")
      expect(match[3]).to eq("skip-verify")
    end
  end
end
