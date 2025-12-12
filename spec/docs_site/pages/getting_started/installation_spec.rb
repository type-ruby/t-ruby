# frozen_string_literal: true

require "spec_helper"
require_relative "../support/shared_examples"

RSpec.describe "한글 문서: 설치하기" do
  include_context "docs site paths"

  let(:relative_path) { "getting-started/installation.md" }
  let(:doc_path) { "#{ko_docs_root}/#{relative_path}" }
  let(:doc_content) { File.read(doc_path) }
  let(:extractor) { TRuby::DocsExampleExtractor.new }
  let(:verifier) { TRuby::DocsExampleVerifier.new }
  let(:examples) { extractor.extract_from_file(doc_path) }

  before do
    skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
    skip "Document not found" unless File.exist?(doc_path)
  end

  it_behaves_like "valid documentation page", "getting-started/installation.md"

  describe "코드 예제" do
    describe "예제: package.json 스크립트" do
      let(:example) { examples.find { |e| e.code.include?('"build": "trc') } }

      it "JSON 형식이 유효하다" do
        skip "예제를 찾을 수 없음" unless example
        expect { JSON.parse(example.code) }.not_to raise_error
      end
    end
  end
end
