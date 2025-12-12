# frozen_string_literal: true

require "spec_helper"
require_relative "../support/shared_examples"

RSpec.describe "한글 문서: Built In Generics" do
  include_context "docs site paths"

  let(:relative_path) { "learn/generics/built-in-generics.md" }
  let(:doc_path) { "#{ko_docs_root}/#{relative_path}" }
  let(:doc_content) { File.read(doc_path) }
  let(:extractor) { TRuby::DocsExampleExtractor.new }
  let(:verifier) { TRuby::DocsExampleVerifier.new }
  let(:examples) { extractor.extract_from_file(doc_path) }

  before do
    skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
    skip "Document not found" unless File.exist?(doc_path)
  end

  it_behaves_like "valid documentation page", "learn/generics/built-in-generics.md"

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

    # 예제 2: T-Ruby (라인 43)
    describe "예제 2: T-Ruby 코드" do
      let(:example) { examples[1] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 3: T-Ruby (라인 71)
    describe "예제 3: T-Ruby 코드" do
      let(:example) { examples[2] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 4: T-Ruby (라인 107)
    describe "예제 4: T-Ruby 코드" do
      let(:example) { examples[3] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 5: T-Ruby (라인 134)
    describe "예제 5: T-Ruby 코드" do
      let(:example) { examples[4] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 6: T-Ruby (라인 164)
    describe "예제 6: T-Ruby 코드" do
      let(:example) { examples[5] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 7: T-Ruby (라인 196)
    describe "예제 7: T-Ruby 코드" do
      let(:example) { examples[6] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 8: T-Ruby (라인 223)
    describe "예제 8: T-Ruby 코드" do
      let(:example) { examples[7] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 9: T-Ruby (라인 253)
    describe "예제 9: T-Ruby 코드" do
      let(:example) { examples[8] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 10: T-Ruby (라인 283)
    describe "예제 10: T-Ruby 코드" do
      let(:example) { examples[9] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 11: T-Ruby (라인 326)
    describe "예제 11: T-Ruby 코드" do
      let(:example) { examples[10] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 12: T-Ruby (라인 360)
    describe "예제 12: T-Ruby 코드" do
      let(:example) { examples[11] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 13: T-Ruby (라인 387)
    describe "예제 13: T-Ruby 코드" do
      let(:example) { examples[12] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 14: T-Ruby (라인 424)
    describe "예제 14: T-Ruby 코드" do
      let(:example) { examples[13] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 15: T-Ruby (라인 458)
    describe "예제 15: T-Ruby 코드" do
      let(:example) { examples[14] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 16: T-Ruby (라인 496)
    describe "예제 16: T-Ruby 코드" do
      let(:example) { examples[15] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 17: T-Ruby (라인 534)
    describe "예제 17: T-Ruby 코드" do
      let(:example) { examples[16] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 18: T-Ruby (라인 547)
    describe "예제 18: T-Ruby 코드" do
      let(:example) { examples[17] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 19: T-Ruby (라인 566)
    describe "예제 19: T-Ruby 코드" do
      let(:example) { examples[18] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 20: T-Ruby (라인 585)
    describe "예제 20: T-Ruby 코드" do
      let(:example) { examples[19] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 21: T-Ruby (라인 600)
    describe "예제 21: T-Ruby 코드" do
      let(:example) { examples[20] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 22: T-Ruby (라인 613)
    describe "예제 22: T-Ruby 코드" do
      let(:example) { examples[21] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end

    # 예제 23: T-Ruby (라인 643)
    describe "예제 23: T-Ruby 코드" do
      let(:example) { examples[22] }

      it "T-Ruby 코드가 파싱에 성공한다" do
        skip "예제를 찾을 수 없음" unless example
        parser = TRuby::Parser.new(example.code)
        expect { parser.parse }.not_to raise_error
      end
    end
  end
end
