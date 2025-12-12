# frozen_string_literal: true

require "spec_helper"
require_relative "../support/shared_examples"

RSpec.describe "한글 문서: 프로젝트 구성" do
  include_context "docs site paths"

  let(:relative_path) { "getting-started/project-configuration.md" }
  let(:doc_path) { "#{ko_docs_root}/#{relative_path}" }
  let(:doc_content) { File.read(doc_path) }
  let(:extractor) { TRuby::DocsExampleExtractor.new }
  let(:verifier) { TRuby::DocsExampleVerifier.new }
  let(:examples) { extractor.extract_from_file(doc_path) }

  before do
    skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
    skip "Document not found" unless File.exist?(doc_path)
  end

  it_behaves_like "valid documentation page", "getting-started/project-configuration.md"

  describe "코드 예제" do
    describe "예제 1: Gemfile" do
      let(:example) { examples.find { |e| e.ruby? && e.code.include?('gem "t-ruby"') } }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    describe "예제 2: Rakefile" do
      let(:example) { examples.find { |e| e.ruby? && e.code.include?("TRuby::RakeTask") } }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    describe "예제 3: Rails 통합 - application.rb" do
      let(:example) { examples.find { |e| e.ruby? && e.code.include?("config.watchable_extensions") } }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end
  end
end
