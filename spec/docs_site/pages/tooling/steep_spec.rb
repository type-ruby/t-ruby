# frozen_string_literal: true

require "spec_helper"
require_relative "../support/shared_examples"

RSpec.describe "한글 문서: Steep" do
  include_context "docs site paths"

  let(:relative_path) { "tooling/steep.md" }
  let(:doc_path) { "#{ko_docs_root}/#{relative_path}" }
  let(:doc_content) { File.read(doc_path) }
  let(:extractor) { TRuby::DocsExampleExtractor.new }
  let(:verifier) { TRuby::DocsExampleVerifier.new }
  let(:examples) { extractor.extract_from_file(doc_path) }

  before do
    skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
    skip "Document not found" unless File.exist?(doc_path)
  end

  it_behaves_like "valid documentation page", "tooling/steep.md"

  describe "코드 예제" do
    # 예제 1: Ruby (라인 36)
    describe "예제 1: Ruby 코드" do
      let(:example) { examples[0] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 2: Ruby (라인 71)
    describe "예제 2: Ruby 코드" do
      let(:example) { examples[1] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 3: T-Ruby (라인 100)
    describe "예제 3: T-Ruby 코드" do
      let(:example) { examples[2] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 4: Ruby (라인 140)
    describe "예제 4: Ruby 코드" do
      let(:example) { examples[3] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 5: Ruby (라인 170)
    describe "예제 5: Ruby 코드" do
      let(:example) { examples[4] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 6: Ruby (라인 183)
    describe "예제 6: Ruby 코드" do
      let(:example) { examples[5] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 7: Ruby (라인 207)
    describe "예제 7: Ruby 코드" do
      let(:example) { examples[6] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 8: Ruby (라인 229)
    describe "예제 8: Ruby 코드" do
      let(:example) { examples[7] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 9: Ruby (라인 309)
    describe "예제 9: Ruby 코드" do
      let(:example) { examples[8] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 10: Ruby (라인 330)
    describe "예제 10: Ruby 코드" do
      let(:example) { examples[9] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 11: Ruby (라인 351)
    describe "예제 11: Ruby 코드" do
      let(:example) { examples[10] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 12: Ruby (라인 384)
    describe "예제 12: Ruby 코드" do
      let(:example) { examples[11] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 13: Ruby (라인 402)
    describe "예제 13: Ruby 코드" do
      let(:example) { examples[12] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 14: RBS (라인 436)
    describe "예제 14: RBS 코드" do
      let(:example) { examples[13] }

      it "RBS 형식이다" do
        skip "예제를 찾을 수 없음" unless example
        expect(example.code).to match(/\b(def|class|module|interface|type)\b/)
      end
    end

    # 예제 15: Ruby (라인 453)
    describe "예제 15: Ruby 코드" do
      let(:example) { examples[14] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 16: T-Ruby (라인 465)
    describe "예제 16: T-Ruby 코드" do
      let(:example) { examples[15] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 17: Ruby (라인 648)
    describe "예제 17: Ruby 코드" do
      let(:example) { examples[16] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 18: Ruby (라인 710)
    describe "예제 18: Ruby 코드" do
      let(:example) { examples[17] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 19: Ruby (라인 760)
    describe "예제 19: Ruby 코드" do
      let(:example) { examples[18] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end
  end
end
