# frozen_string_literal: true

require "spec_helper"
require_relative "../support/shared_examples"

RSpec.describe "한글 문서: T Ruby Vs Others" do
  include_context "docs site paths"

  let(:relative_path) { "introduction/t-ruby-vs-others.md" }
  let(:doc_path) { "#{ko_docs_root}/#{relative_path}" }
  let(:doc_content) { File.read(doc_path) }
  let(:extractor) { TRuby::DocsExampleExtractor.new }
  let(:verifier) { TRuby::DocsExampleVerifier.new }
  let(:examples) { extractor.extract_from_file(doc_path) }

  before do
    skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
    skip "Document not found" unless File.exist?(doc_path)
  end

  it_behaves_like "valid documentation page", "introduction/t-ruby-vs-others.md"

  describe "코드 예제" do
    # 예제 1: Ruby (라인 36)
    describe "예제 1: Ruby 코드" do
      let(:example) { examples[0] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 2: RBS (라인 49)
    describe "예제 2: RBS 코드" do
      let(:example) { examples[1] }

      it "RBS 형식이다" do
        skip "예제를 찾을 수 없음" unless example
        expect(example.code).to match(/\b(def|class|module|interface|type)\b/)
      end
    end

    # 예제 3: T-Ruby (라인 65)
    describe "예제 3: T-Ruby 코드" do
      let(:example) { examples[2] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 4: Ruby (라인 110)
    describe "예제 4: Ruby 코드" do
      let(:example) { examples[3] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 5: T-Ruby (라인 133)
    describe "예제 5: T-Ruby 코드" do
      let(:example) { examples[4] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 6: Ruby (라인 159)
    describe "예제 6: Ruby 코드" do
      let(:example) { examples[5] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 7: T-Ruby (라인 173)
    describe "예제 7: T-Ruby 코드" do
      let(:example) { examples[6] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 8: T-Ruby (라인 215)
    describe "예제 8: T-Ruby 코드" do
      let(:example) { examples[7] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end
  end
end
