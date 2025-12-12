# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/shared_examples"

RSpec.describe "한글 문서: 기본 타입" do
  include_context "docs site paths"

  let(:relative_path) { "learn/basics/basic-types.md" }
  let(:doc_path) { "#{ko_docs_root}/#{relative_path}" }
  let(:doc_content) { File.read(doc_path) }
  let(:extractor) { TRuby::DocsExampleExtractor.new }
  let(:verifier) { TRuby::DocsExampleVerifier.new }
  let(:examples) { extractor.extract_from_file(doc_path) }

  before do
    skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
    skip "Document not found" unless File.exist?(doc_path)
  end

  it_behaves_like "valid documentation page", "learn/basics/basic-types.md"

  describe "코드 예제" do
    describe "예제 1: 기본 String 사용" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?('name: String = "Alice"') && e.code.include?("여러 줄 문자열") } }

      it "파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    describe "예제 2: String 메서드" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def format_name") } }

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

    describe "예제 3: Integer 산술" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def calculate_total(price: Integer") } }

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

    describe "예제 4: Float 산술 (calculate_average)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def calculate_average") } }

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

    describe "예제 5: Boolean 논리" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def can_access") } }

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

    describe "예제 6: Symbol 기본 사용" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("status: Symbol = :active") } }

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

    describe "예제 7: nil 검사 (greet)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def greet(name: String | nil)") } }

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

    describe "예제 8: 온도 변환기" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def celsius_to_fahrenheit") } }

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
