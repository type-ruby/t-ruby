# frozen_string_literal: true

require "spec_helper"
require_relative "../support/shared_examples"

RSpec.describe "한글 문서: 첫 번째 .trb 파일" do
  include_context "docs site paths"

  let(:relative_path) { "getting-started/first-trb-file.md" }
  let(:doc_path) { "#{ko_docs_root}/#{relative_path}" }
  let(:doc_content) { File.read(doc_path) }
  let(:extractor) { TRuby::DocsExampleExtractor.new }
  let(:verifier) { TRuby::DocsExampleVerifier.new }
  let(:examples) { extractor.extract_from_file(doc_path) }

  before do
    skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
    skip "Document not found" unless File.exist?(doc_path)
  end

  it_behaves_like "valid documentation page", "getting-started/first-trb-file.md"

  describe "코드 예제" do
    describe "예제 1: 기본 계산기 (calculator.trb)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def add(a: Integer, b: Integer)") && e.code.include?("def subtract") } }

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

    describe "예제 2: 타입 별칭과 Number 타입" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("type Number = Integer | Float") && e.code.include?("def safe_divide") } }

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

    describe "예제 3: Union 타입 이해하기" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("type Number = Integer | Float") && !e.code.include?("def add") } }

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

    describe "예제 4: 제네릭 이해하기 (max 함수)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def max<T: Comparable>") } }

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

    describe "예제 5: Calculator 클래스" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("class Calculator") && e.code.include?("@history: Array<String>") } }

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

    describe "예제 6: 컴파일 출력 - Ruby" do
      let(:example) { examples.find { |e| e.ruby? && e.code.include?("class Calculator") && e.code.include?("def initialize") } }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    describe "예제 7: 컴파일 출력 - RBS" do
      let(:example) { examples.find { |e| e.rbs? && e.code.include?("class Calculator") } }

      it "RBS 키워드가 포함되어 있다" do
        skip "예제를 찾을 수 없음" unless example
        expect(example.code).to match(/\b(class|def|type)\b/)
      end
    end

    describe "예제 8: 옵셔널 매개변수 (greet)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?('def greet(name: String, greeting: String = "Hello")') } }

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

    describe "예제 9: Nullable 타입 (find)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def find(id: Integer): User | nil") } }

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

    describe "예제 10: 블록 매개변수 (each_item)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def each_item") && e.code.include?("&block") } }

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
