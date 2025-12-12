# frozen_string_literal: true

require "spec_helper"
require_relative "../support/shared_examples"

RSpec.describe "한글 문서: T-Ruby란?" do
  include_context "docs site paths"

  let(:relative_path) { "introduction/what-is-t-ruby.md" }
  let(:doc_path) { "#{ko_docs_root}/#{relative_path}" }
  let(:doc_content) { File.read(doc_path) }
  let(:extractor) { TRuby::DocsExampleExtractor.new }
  let(:verifier) { TRuby::DocsExampleVerifier.new }
  let(:examples) { extractor.extract_from_file(doc_path) }

  before do
    skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
    skip "Document not found" unless File.exist?(doc_path)
  end

  it_behaves_like "valid documentation page", "introduction/what-is-t-ruby.md"

  describe "코드 예제" do
    describe "예제 1: 기본 T-Ruby 문법 (hello.trb)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def greet") } }

      it "파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end

      it "컴파일에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        compiler = TRuby::Compiler.new
        expect { compiler.compile_string(example.code) }.not_to raise_error
      end
    end

    describe "예제 2: 컴파일된 Ruby 출력 (hello.rb)" do
      let(:example) { examples.find { |e| e.ruby? && e.code.include?("def greet") } }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    describe "예제 3: RBS 타입 정의 (hello.rbs)" do
      let(:example) { examples.find { |e| e.rbs? && e.code.include?("def greet") } }

      it "RBS 키워드가 포함되어 있다" do
        skip "예제를 찾을 수 없음" unless example
        expect(example.code).to match(/\bdef\b/)
      end
    end

    describe "예제 4: 친숙한 문법 예제" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("interface Printable") } }

      it "파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end

      it "컴파일에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        compiler = TRuby::Compiler.new
        expect { compiler.compile_string(example.code) }.not_to raise_error
      end
    end
  end
end
