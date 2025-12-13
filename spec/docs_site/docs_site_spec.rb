# frozen_string_literal: true

require "spec_helper"

RSpec.describe "t-ruby.github.io Documentation Site" do
  let(:docs_site_path) { File.expand_path("../../../t-ruby.github.io", __dir__) }
  let(:extractor) { TRuby::DocsExampleExtractor.new }
  let(:verifier) { TRuby::DocsExampleVerifier.new }

  before(:all) do
    @docs_site_path = File.expand_path("../../../t-ruby.github.io", __dir__)
    skip "t-ruby.github.io not found at #{@docs_site_path}" unless Dir.exist?(@docs_site_path)
  end

  describe "English documentation (docs/)" do
    let(:docs_path) { "#{docs_site_path}/docs" }

    it "exists" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)
      expect(Dir.exist?(docs_path)).to be true
    end

    it "has all code examples passing verification" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)

      results = []
      Dir.glob("#{docs_path}/**/*.md").each do |file|
        results.concat(verifier.verify_file(file))
      end

      failed = results.select(&:fail?)
      if failed.any?
        failure_messages = failed.map do |r|
          "#{r.file_path}:#{r.line_number}\n  #{r.errors.join("\n  ")}"
        end
        raise "#{failed.size} examples failed:\n#{failure_messages.join("\n\n")}"
      end

      expect(failed).to be_empty
    end

    it "extracts examples from all markdown files" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)

      examples = extractor.extract_from_glob("#{docs_path}/**/*.md")
      expect(examples).not_to be_empty
    end
  end

  describe "Korean documentation (i18n/ko/)" do
    let(:docs_path) { "#{docs_site_path}/i18n/ko/docusaurus-plugin-content-docs/current" }

    it "exists" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)
      expect(Dir.exist?(docs_path)).to be true
    end

    it "has all code examples passing verification" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)

      results = []
      Dir.glob("#{docs_path}/**/*.md").each do |file|
        results.concat(verifier.verify_file(file))
      end

      failed = results.select(&:fail?)
      if failed.any?
        failure_messages = failed.map do |r|
          "#{r.file_path}:#{r.line_number}\n  #{r.errors.join("\n  ")}"
        end
        raise "#{failed.size} examples failed:\n#{failure_messages.join("\n\n")}"
      end

      expect(failed).to be_empty
    end

    it "has the same number of documents as English" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)

      en_docs = Dir.glob("#{docs_site_path}/docs/**/*.md").size
      ko_docs = Dir.glob("#{docs_path}/**/*.md").size

      expect(ko_docs).to eq(en_docs)
    end
  end

  describe "Japanese documentation (i18n/ja/)" do
    let(:docs_path) { "#{docs_site_path}/i18n/ja/docusaurus-plugin-content-docs/current" }

    it "exists" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)
      expect(Dir.exist?(docs_path)).to be true
    end

    it "has all code examples passing verification" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)

      results = []
      Dir.glob("#{docs_path}/**/*.md").each do |file|
        results.concat(verifier.verify_file(file))
      end

      failed = results.select(&:fail?)
      if failed.any?
        failure_messages = failed.map do |r|
          "#{r.file_path}:#{r.line_number}\n  #{r.errors.join("\n  ")}"
        end
        raise "#{failed.size} examples failed:\n#{failure_messages.join("\n\n")}"
      end

      expect(failed).to be_empty
    end

    it "has the same number of documents as English" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)

      en_docs = Dir.glob("#{docs_site_path}/docs/**/*.md").size
      ja_docs = Dir.glob("#{docs_path}/**/*.md").size

      expect(ja_docs).to eq(en_docs)
    end
  end

  describe "Cross-language consistency" do
    it "all languages have matching document structure" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)

      en_structure = Dir.glob("#{docs_site_path}/docs/**/*.md").map do |f|
        f.sub("#{docs_site_path}/docs/", "")
      end.sort

      ko_structure = Dir.glob("#{docs_site_path}/i18n/ko/docusaurus-plugin-content-docs/current/**/*.md").map do |f|
        f.sub("#{docs_site_path}/i18n/ko/docusaurus-plugin-content-docs/current/", "")
      end.sort

      ja_structure = Dir.glob("#{docs_site_path}/i18n/ja/docusaurus-plugin-content-docs/current/**/*.md").map do |f|
        f.sub("#{docs_site_path}/i18n/ja/docusaurus-plugin-content-docs/current/", "")
      end.sort

      expect(ko_structure).to eq(en_structure), "Korean docs structure differs from English"
      expect(ja_structure).to eq(en_structure), "Japanese docs structure differs from English"
    end
  end
end
