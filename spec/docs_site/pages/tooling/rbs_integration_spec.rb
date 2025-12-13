# frozen_string_literal: true

require "spec_helper"
require_relative "../support/shared_examples"

RSpec.describe "한글 문서: Rbs Integration" do
  include_context "docs site paths"

  let(:relative_path) { "tooling/rbs-integration.md" }
  let(:doc_path) { "#{ko_docs_root}/#{relative_path}" }
  let(:doc_content) { File.read(doc_path) }
  let(:extractor) { TRuby::DocsExampleExtractor.new }
  let(:verifier) { TRuby::DocsExampleVerifier.new }
  let(:examples) { extractor.extract_from_file(doc_path) }

  before do
    skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
    skip "Document not found" unless File.exist?(doc_path)
  end

  it_behaves_like "valid documentation page", "tooling/rbs-integration.md"

  describe "코드 예제" do
    # 예제 1: T-Ruby (라인 33)
    describe "예제 1: T-Ruby 코드" do
      let(:example) { examples[0] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 2: RBS (라인 59)
    describe "예제 2: RBS 코드" do
      let(:example) { examples[1] }

      it "RBS 형식이다" do
        skip "예제를 찾을 수 없음" unless example
        expect(example.code).to match(/\b(def|class|module|interface|type)\b/)
      end
    end

    # 예제 3: Ruby (라인 75)
    describe "예제 3: Ruby 코드" do
      let(:example) { examples[2] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 4: T-Ruby (라인 135)
    describe "예제 4: T-Ruby 코드" do
      let(:example) { examples[3] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 5: RBS (라인 148)
    describe "예제 5: RBS 코드" do
      let(:example) { examples[4] }

      it "RBS 형식이다" do
        skip "예제를 찾을 수 없음" unless example
        expect(example.code).to match(/\b(def|class|module|interface|type)\b/)
      end
    end

    # 예제 6: T-Ruby (라인 157)
    describe "예제 6: T-Ruby 코드" do
      let(:example) { examples[5] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 7: RBS (라인 170)
    describe "예제 7: RBS 코드" do
      let(:example) { examples[6] }

      it "RBS 형식이다" do
        skip "예제를 찾을 수 없음" unless example
        expect(example.code).to match(/\b(def|class|module|interface|type)\b/)
      end
    end

    # 예제 8: T-Ruby (라인 182)
    describe "예제 8: T-Ruby 코드" do
      let(:example) { examples[7] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 9: RBS (라인 190)
    describe "예제 9: RBS 코드" do
      let(:example) { examples[8] }

      it "RBS 형식이다" do
        skip "예제를 찾을 수 없음" unless example
        expect(example.code).to match(/\b(def|class|module|interface|type)\b/)
      end
    end

    # 예제 10: T-Ruby (라인 200)
    describe "예제 10: T-Ruby 코드" do
      let(:example) { examples[9] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 11: RBS (라인 220)
    describe "예제 11: RBS 코드" do
      let(:example) { examples[10] }

      it "RBS 형식이다" do
        skip "예제를 찾을 수 없음" unless example
        expect(example.code).to match(/\b(def|class|module|interface|type)\b/)
      end
    end

    # 예제 12: T-Ruby (라인 234)
    describe "예제 12: T-Ruby 코드" do
      let(:example) { examples[11] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 13: RBS (라인 248)
    describe "예제 13: RBS 코드" do
      let(:example) { examples[12] }

      it "RBS 형식이다" do
        skip "예제를 찾을 수 없음" unless example
        expect(example.code).to match(/\b(def|class|module|interface|type)\b/)
      end
    end

    # 예제 14: T-Ruby (라인 256)
    describe "예제 14: T-Ruby 코드" do
      let(:example) { examples[13] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 15: RBS (라인 278)
    describe "예제 15: RBS 코드" do
      let(:example) { examples[14] }

      it "RBS 형식이다" do
        skip "예제를 찾을 수 없음" unless example
        expect(example.code).to match(/\b(def|class|module|interface|type)\b/)
      end
    end

    # 예제 16: T-Ruby (라인 295)
    describe "예제 16: T-Ruby 코드" do
      let(:example) { examples[15] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 17: RBS (라인 306)
    describe "예제 17: RBS 코드" do
      let(:example) { examples[16] }

      it "RBS 형식이다" do
        skip "예제를 찾을 수 없음" unless example
        expect(example.code).to match(/\b(def|class|module|interface|type)\b/)
      end
    end

    # 예제 18: T-Ruby (라인 319)
    describe "예제 18: T-Ruby 코드" do
      let(:example) { examples[17] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 19: RBS (라인 340)
    describe "예제 19: RBS 코드" do
      let(:example) { examples[18] }

      it "RBS 형식이다" do
        skip "예제를 찾을 수 없음" unless example
        expect(example.code).to match(/\b(def|class|module|interface|type)\b/)
      end
    end

    # 예제 20: Ruby (라인 404)
    describe "예제 20: Ruby 코드" do
      let(:example) { examples[19] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 21: T-Ruby (라인 420)
    describe "예제 21: T-Ruby 코드" do
      let(:example) { examples[20] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 22: T-Ruby (라인 530)
    describe "예제 22: T-Ruby 코드" do
      let(:example) { examples[21] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 23: Ruby (라인 571)
    describe "예제 23: Ruby 코드" do
      let(:example) { examples[22] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 24: T-Ruby (라인 586)
    describe "예제 24: T-Ruby 코드" do
      let(:example) { examples[23] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 25: Ruby (라인 639)
    describe "예제 25: Ruby 코드" do
      let(:example) { examples[24] }

      it "유효한 Ruby 문법이다" do
        skip "예제를 찾을 수 없음" unless example
        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error
      end
    end

    # 예제 26: T-Ruby (라인 727)
    describe "예제 26: T-Ruby 코드" do
      let(:example) { examples[25] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 27: T-Ruby (라인 746)
    describe "예제 27: T-Ruby 코드" do
      let(:example) { examples[26] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end
  end
end
