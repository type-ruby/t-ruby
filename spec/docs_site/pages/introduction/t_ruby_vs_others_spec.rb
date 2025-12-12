# frozen_string_literal: true

require "spec_helper"
require_relative "../support/shared_examples"

RSpec.describe "한글 문서: T-Ruby vs 다른 도구들" do
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
    describe "예제 1: RBS 접근 방식 - Ruby 코드 (User)" do
      let(:example) { examples.find { |e| e.ruby? && e.code.include?("class User") && e.code.include?("def initialize") } }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    describe "예제 2: RBS 접근 방식 - RBS 정의 (User)" do
      let(:example) { examples.find { |e| e.rbs? && e.code.include?("class User") } }

      it "RBS 키워드가 포함되어 있다" do
        skip "예제를 찾을 수 없음" unless example
        expect(example.code).to match(/\b(class|def)\b/)
      end
    end

    describe "예제 3: T-Ruby 접근 방식 (User 클래스)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("class User") } }

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

    describe "예제 4: Sorbet 접근 방식 (Calculator)" do
      let(:example) { examples.find { |e| e.ruby? && e.code.include?("class Calculator") && e.code.include?("extend T::Sig") } }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    describe "예제 5: T-Ruby 접근 방식 (Calculator 클래스)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("class Calculator") } }

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

    describe "예제 6: Sorbet 런타임 검사 예제" do
      let(:example) { examples.find { |e| e.ruby? && e.code.include?("sig { params(name: String)") } }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    describe "예제 7: T-Ruby 컴파일 타임 검사 예제" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def greet(name: String)") } }

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

    describe "예제 8: T-Ruby vs TypeScript 비교 (T-Ruby)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("interface User") } }

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
