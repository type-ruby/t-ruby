# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/shared_examples"

RSpec.describe "한글 문서: 타입 어노테이션" do
  include_context "docs site paths"

  let(:relative_path) { "learn/basics/type-annotations.md" }
  let(:doc_path) { "#{ko_docs_root}/#{relative_path}" }
  let(:doc_content) { File.read(doc_path) }
  let(:extractor) { TRuby::DocsExampleExtractor.new }
  let(:verifier) { TRuby::DocsExampleVerifier.new }
  let(:examples) { extractor.extract_from_file(doc_path) }

  before do
    skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
    skip "Document not found" unless File.exist?(doc_path)
  end

  it_behaves_like "valid documentation page", "learn/basics/type-annotations.md"

  describe "코드 예제" do
    describe "예제 1: 기본 타입 어노테이션 (hello.trb)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?('name: String = "Alice"') && e.code.include?("def greet(person: String)") } }

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

    describe "예제 2: 트랜스파일된 Ruby 출력" do
      let(:example) { examples.find { |e| e.ruby? && e.code.include?('name = "Alice"') && e.code.include?("def greet(person)") } }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    describe "예제 3: 여러 매개변수 (create_user)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def create_user(name: String, age: Integer, email: String)") } }

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

    describe "예제 4: 완전한 예제 (calculate_discount)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def calculate_discount") && e.code.include?("is_member: Bool = false") } }

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

    describe "예제 5: 블록 매개변수 어노테이션" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("def process_numbers") && e.code.include?("|n: Integer|") } }

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

    describe "예제 6: 인스턴스 변수 (Person 클래스)" do
      let(:example) { examples.find { |e| e.trb? && e.code.include?("class Person") && e.code.include?("@name: String = name") } }

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
