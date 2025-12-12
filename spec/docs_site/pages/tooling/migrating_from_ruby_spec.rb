# frozen_string_literal: true

require "spec_helper"
require_relative "../support/shared_examples"

RSpec.describe "한글 문서: Ruby에서 마이그레이션" do
  include_context "docs site paths"

  let(:relative_path) { "tooling/migrating-from-ruby.md" }
  let(:doc_path) { "#{ko_docs_root}/#{relative_path}" }
  let(:doc_content) { File.read(doc_path) }
  let(:extractor) { TRuby::DocsExampleExtractor.new }
  let(:verifier) { TRuby::DocsExampleVerifier.new }
  let(:examples) { extractor.extract_from_file(doc_path) }

  before do
    skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
    skip "Document not found" unless File.exist?(doc_path)
  end

  it_behaves_like "valid documentation page", "tooling/migrating-from-ruby.md"
end
