# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :docs do
  desc "Verify documentation examples compile and type-check correctly"
  task :verify do
    require_relative "lib/t_ruby"

    verifier = TRuby::DocsExampleVerifier.new

    # Default patterns to check
    # Includes both local docs and t-ruby.github.io documentation site
    docs_site_path = "../t-ruby.github.io"
    patterns = [
      "docs/**/*.md",
      "README.md",
      "README.ja.md",
      "README.ko.md",
    ]

    # Add t-ruby.github.io documentation if directory exists
    if Dir.exist?(docs_site_path)
      patterns += [
        "#{docs_site_path}/docs/**/*.md",
        "#{docs_site_path}/i18n/ko/docusaurus-plugin-content-docs/current/**/*.md",
        "#{docs_site_path}/i18n/ja/docusaurus-plugin-content-docs/current/**/*.md",
      ]
    end

    puts "Verifying documentation examples..."
    puts

    all_results = []

    patterns.each do |pattern|
      files = Dir.glob(pattern)
      next if files.empty?

      files.each do |file|
        results = verifier.verify_file(file)
        all_results.concat(results)
      end
    end

    if all_results.empty?
      puts "No examples found to verify."
      exit 0
    end

    verifier.print_results(all_results, verbose: ENV["VERBOSE"] == "true")

    summary = verifier.summary(all_results)
    exit 1 if summary[:failed] > 0
  end

  desc "Generate documentation coverage badge and report"
  task :badge do
    require_relative "lib/t_ruby"

    verifier = TRuby::DocsExampleVerifier.new
    generator = TRuby::DocsBadgeGenerator.new

    docs_site_path = "../t-ruby.github.io"
    patterns = [
      "docs/**/*.md",
      "README.md",
      "README.ja.md",
      "README.ko.md",
    ]

    if Dir.exist?(docs_site_path)
      patterns += [
        "#{docs_site_path}/docs/**/*.md",
        "#{docs_site_path}/i18n/ko/docusaurus-plugin-content-docs/current/**/*.md",
        "#{docs_site_path}/i18n/ja/docusaurus-plugin-content-docs/current/**/*.md",
      ]
    end

    puts "Generating documentation coverage badge..."

    all_results = []
    patterns.each do |pattern|
      Dir.glob(pattern).each do |file|
        results = verifier.verify_file(file)
        all_results.concat(results)
      end
    end

    output_dir = ENV["OUTPUT_DIR"] || "coverage"
    generator.generate_all(all_results, output_dir)

    summary = verifier.summary(all_results)
    puts "Badge generated: #{output_dir}/docs_badge.svg"
    puts "Report generated: #{output_dir}/docs_report.md"
    puts "Pass rate: #{summary[:pass_rate]}%"
  end

  desc "Extract and list all code examples from documentation"
  task :list do
    require_relative "lib/t_ruby"

    extractor = TRuby::DocsExampleExtractor.new

    docs_site_path = "../t-ruby.github.io"
    patterns = [
      "docs/**/*.md",
      "README.md",
      "README.ja.md",
      "README.ko.md",
    ]

    if Dir.exist?(docs_site_path)
      patterns += [
        "#{docs_site_path}/docs/**/*.md",
        "#{docs_site_path}/i18n/ko/docusaurus-plugin-content-docs/current/**/*.md",
        "#{docs_site_path}/i18n/ja/docusaurus-plugin-content-docs/current/**/*.md",
      ]
    end

    all_examples = []
    patterns.each do |pattern|
      examples = extractor.extract_from_glob(pattern)
      all_examples.concat(examples)
    end

    puts "Found #{all_examples.size} code examples:"
    puts

    stats = extractor.statistics(all_examples)
    puts "Statistics:"
    puts "  Total: #{stats[:total]}"
    puts "  T-Ruby (.trb): #{stats[:trb]}"
    puts "  Ruby (.rb): #{stats[:ruby]}"
    puts "  RBS (.rbs): #{stats[:rbs]}"
    puts "  Verifiable: #{stats[:verifiable]}"
    puts "  Files: #{stats[:files]}"
    puts

    if ENV["VERBOSE"] == "true"
      all_examples.each do |example|
        puts "#{example.file_path}:#{example.line_number} [#{example.language}]"
        puts "  #{example.code.lines.first&.strip}"
        puts
      end
    end
  end
end

namespace :lint do
  desc "Run RuboCop"
  task :rubocop do
    sh "bundle exec rubocop"
  end

  desc "Run RuboCop with auto-correct"
  task :rubocop_fix do
    sh "bundle exec rubocop -A"
  end
end

desc "Run all checks (tests + lint)"
task check: [:spec, "lint:rubocop"]
