# frozen_string_literal: true

require "spec_helper"
require_relative "../support/shared_examples"

RSpec.describe "한글 문서: Type Inference" do
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

    # 예제 1: T-Ruby (라인 22)
    describe "예제 1: T-Ruby 코드" do
      let(:example) { examples[0] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 2: Ruby (라인 40)
    describe "예제 2: Ruby 코드" do
      let(:example) { examples[1] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 3: T-Ruby (라인 55)
    describe "예제 3: T-Ruby 코드" do
      let(:example) { examples[2] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 4: T-Ruby (라인 81)
    describe "예제 4: T-Ruby 코드" do
      let(:example) { examples[3] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 5: T-Ruby (라인 103)
    describe "예제 5: T-Ruby 코드" do
      let(:example) { examples[4] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 6: T-Ruby (라인 127)
    describe "예제 6: T-Ruby 코드" do
      let(:example) { examples[5] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 7: T-Ruby (라인 155)
    describe "예제 7: T-Ruby 코드" do
      let(:example) { examples[6] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 8: T-Ruby (라인 181)
    describe "예제 8: T-Ruby 코드" do
      let(:example) { examples[7] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 9: T-Ruby (라인 211)
    describe "예제 9: T-Ruby 코드" do
      let(:example) { examples[8] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 10: T-Ruby (라인 229)
    describe "예제 10: T-Ruby 코드" do
      let(:example) { examples[9] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 11: T-Ruby (라인 249)
    describe "예제 11: T-Ruby 코드" do
      let(:example) { examples[10] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 12: T-Ruby (라인 266)
    describe "예제 12: T-Ruby 코드" do
      let(:example) { examples[11] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 13: T-Ruby (라인 283)
    describe "예제 13: T-Ruby 코드" do
      let(:example) { examples[12] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 14: T-Ruby (라인 306)
    describe "예제 14: T-Ruby 코드" do
      let(:example) { examples[13] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 15: T-Ruby (라인 325)
    describe "예제 15: T-Ruby 코드" do
      let(:example) { examples[14] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 16: T-Ruby (라인 347)
    describe "예제 16: T-Ruby 코드" do
      let(:example) { examples[15] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 17: T-Ruby (라인 363)
    describe "예제 17: T-Ruby 코드" do
      let(:example) { examples[16] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 18: T-Ruby (라인 380)
    describe "예제 18: T-Ruby 코드" do
      let(:example) { examples[17] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 19: T-Ruby (라인 403)
    describe "예제 19: T-Ruby 코드" do
      let(:example) { examples[18] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 20: T-Ruby (라인 418)
    describe "예제 20: T-Ruby 코드" do
      let(:example) { examples[19] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 21: T-Ruby (라인 442)
    describe "예제 21: T-Ruby 코드" do
      let(:example) { examples[20] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 22: T-Ruby (라인 461)
    describe "예제 22: T-Ruby 코드" do
      let(:example) { examples[21] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 23: T-Ruby (라인 475)
    describe "예제 23: T-Ruby 코드" do
      let(:example) { examples[22] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 24: T-Ruby (라인 498)
    describe "예제 24: T-Ruby 코드" do
      let(:example) { examples[23] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 25: T-Ruby (라인 518)
    describe "예제 25: T-Ruby 코드" do
      let(:example) { examples[24] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end
  end
end
