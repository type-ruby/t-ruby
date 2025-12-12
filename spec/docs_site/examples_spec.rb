# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Documentation Examples" do
  let(:docs_site_path) { File.expand_path("../../../t-ruby.github.io", __dir__) }
  let(:extractor) { TRuby::DocsExampleExtractor.new }
  let(:verifier) { TRuby::DocsExampleVerifier.new }

  before(:all) do
    @docs_site_path = File.expand_path("../../../t-ruby.github.io", __dir__)
    skip "t-ruby.github.io not found at #{@docs_site_path}" unless Dir.exist?(@docs_site_path)
  end

  describe "T-Ruby (.trb) examples" do
    it "all parse successfully" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)

      all_examples = collect_all_examples
      trb_examples = all_examples.select(&:trb?).select(&:should_verify?)

      parse_failures = []
      trb_examples.each do |example|
        begin
          parser = TRuby::Parser.new(example.code)
          parser.parse
        rescue TRuby::ParseError => e
          parse_failures << {
            file: example.file_path,
            line: example.line_number,
            error: e.message,
          }
        end
      end

      if parse_failures.any?
        messages = parse_failures.map { |f| "#{f[:file]}:#{f[:line]} - #{f[:error]}" }
        fail "#{parse_failures.size} T-Ruby examples failed to parse:\n#{messages.join("\n")}"
      end

      expect(parse_failures).to be_empty
    end

    it "all compile successfully" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)

      all_examples = collect_all_examples
      trb_examples = all_examples.select(&:trb?).select(&:should_verify?).select(&:should_compile?)

      compile_failures = []
      compiler = TRuby::Compiler.new

      trb_examples.each do |example|
        begin
          compiler.compile_string(example.code)
        rescue StandardError => e
          compile_failures << {
            file: example.file_path,
            line: example.line_number,
            error: e.message,
          }
        end
      end

      if compile_failures.any?
        messages = compile_failures.map { |f| "#{f[:file]}:#{f[:line]} - #{f[:error]}" }
        fail "#{compile_failures.size} T-Ruby examples failed to compile:\n#{messages.join("\n")}"
      end

      expect(compile_failures).to be_empty
    end
  end

  describe "Ruby examples" do
    it "all have valid syntax" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)

      all_examples = collect_all_examples
      ruby_examples = all_examples.select(&:ruby?).select(&:should_verify?)

      syntax_failures = []
      ruby_examples.each do |example|
        begin
          RubyVM::InstructionSequence.compile(example.code)
        rescue SyntaxError => e
          syntax_failures << {
            file: example.file_path,
            line: example.line_number,
            error: e.message,
          }
        end
      end

      if syntax_failures.any?
        messages = syntax_failures.map { |f| "#{f[:file]}:#{f[:line]} - #{f[:error]}" }
        fail "#{syntax_failures.size} Ruby examples have syntax errors:\n#{messages.join("\n")}"
      end

      expect(syntax_failures).to be_empty
    end
  end

  describe "Example statistics" do
    it "reports coverage statistics" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)

      all_examples = collect_all_examples
      stats = extractor.statistics(all_examples)

      puts "\n=== Documentation Example Statistics ==="
      puts "Total examples: #{stats[:total]}"
      puts "T-Ruby (.trb): #{stats[:trb]}"
      puts "Ruby (.rb): #{stats[:ruby]}"
      puts "RBS (.rbs): #{stats[:rbs]}"
      puts "Verifiable: #{stats[:verifiable]}"
      puts "Files: #{stats[:files]}"
      puts "========================================\n"

      expect(stats[:total]).to be > 0
    end

    it "has high pass rate (>99%)" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)

      all_examples = collect_all_examples
      results = all_examples.map { |ex| verifier.verify_example(ex) }
      summary = verifier.summary(results)

      puts "\n=== Verification Results ==="
      puts "Passed: #{summary[:passed]}"
      puts "Failed: #{summary[:failed]}"
      puts "Skipped: #{summary[:skipped]}"
      puts "Pass rate: #{summary[:pass_rate]}%"
      puts "============================\n"

      expect(summary[:pass_rate]).to be >= 99.0
    end
  end

  private

  def collect_all_examples
    patterns = [
      "#{docs_site_path}/docs/**/*.md",
      "#{docs_site_path}/i18n/ko/docusaurus-plugin-content-docs/current/**/*.md",
      "#{docs_site_path}/i18n/ja/docusaurus-plugin-content-docs/current/**/*.md",
    ]

    patterns.flat_map { |pattern| extractor.extract_from_glob(pattern) }
  end
end
