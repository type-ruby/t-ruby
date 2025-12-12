# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/shared_examples"

RSpec.describe "한글 문서: 타입 추론" do
  include_context "docs site paths"

  let(:relative_path) { "learn/basics/type-inference.md" }
  let(:doc_path) { "#{ko_docs_root}/#{relative_path}" }
  let(:doc_content) { File.read(doc_path) }
  let(:extractor) { TRuby::DocsExampleExtractor.new }
  let(:verifier) { TRuby::DocsExampleVerifier.new }
  let(:examples) { extractor.extract_from_file(doc_path) }

  before do
    skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
    skip "Document not found" unless File.exist?(doc_path)
  end

  it_behaves_like "valid documentation page", "learn/basics/type-inference.md"

  describe "코드 예제" do
    describe "예제 1: 기본 추론" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?('name = "Alice"') && e.code.include?("count = 42") } }

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

    describe "예제 2: 표현식 기반 추론" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("sum = x + y") && e.code.include?("full_name = first_name") } }

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

    describe "예제 3: 지역 변수 추론 (process_order)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def process_order") && e.code.include?("subtotal = quantity * unit_price") } }

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

    describe "예제 4: 배열과 해시 추론" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("numbers = [1, 2, 3, 4, 5]") && e.code.include?('names = ["Alice"') } }

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

    describe "예제 5: 블록 매개변수 추론 (sum_numbers)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def sum_numbers(numbers: Array<Integer>)") } }

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

    describe "예제 6: 제어 흐름과 추론 (categorize_age)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def categorize_age") } }

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

    describe "예제 7: 재귀 함수 (factorial, fibonacci)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def factorial") && e.code.include?("def fibonacci") } }

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

    describe "예제 8: 복합 이자 계산 (calculate_compound_interest)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def calculate_compound_interest") } }

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
