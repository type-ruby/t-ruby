# frozen_string_literal: true

# 문서 페이지 테스트를 위한 공통 shared examples
# 한글 문서 기준으로 테스트하며, 다른 언어는 구조 일치만 확인

RSpec.shared_context "docs site paths" do
  let(:docs_site_root) { File.expand_path("../../../../../t-ruby.github.io", __dir__) }
  let(:ko_docs_root) { "#{docs_site_root}/i18n/ko/docusaurus-plugin-content-docs/current" }
  let(:en_docs_root) { "#{docs_site_root}/docs" }
  let(:ja_docs_root) { "#{docs_site_root}/i18n/ja/docusaurus-plugin-content-docs/current" }
end

RSpec.shared_examples "valid documentation page" do |relative_path|
  include_context "docs site paths"

  let(:doc_path) { "#{ko_docs_root}/#{relative_path}" }
  let(:doc_content) { File.read(doc_path) }
  let(:extractor) { TRuby::DocsExampleExtractor.new }
  let(:verifier) { TRuby::DocsExampleVerifier.new }

  before do
    skip "t-ruby.github.io not found at #{docs_site_root}" unless Dir.exist?(docs_site_root)
    skip "Document not found at #{doc_path}" unless File.exist?(doc_path)
  end

  describe "문서 구조" do
    it "frontmatter가 존재한다" do
      expect(doc_content).to match(/\A---\n.*?---/m)
    end

    it "title이 frontmatter에 포함되어 있다" do
      frontmatter = doc_content.match(/\A---\n(.*?)---/m)&.[](1)
      expect(frontmatter).to include("title:")
    end

    it "최소 1개 이상의 heading이 존재한다" do
      # frontmatter 이후의 본문에서 heading 찾기
      body = doc_content.sub(/\A---\n.*?---\n/m, "")
      expect(body).to match(/^#+ /)
    end
  end

  describe "DocsBadge" do
    it "DocsBadge 컴포넌트가 포함되어 있다" do
      expect(doc_content).to include("<DocsBadge")
    end
  end

  describe "코드 예제 검증" do
    let(:examples) { extractor.extract_from_file(doc_path) }

    it "모든 T-Ruby 예제가 파싱된다" do
      trb_examples = examples.select(&:trb?).select(&:should_verify?)
      skip "T-Ruby 예제 없음" if trb_examples.empty?

      parse_failures = []
      trb_examples.each do |example|
        parser = TRuby::Parser.new(example.code)
        parser.parse
      rescue TRuby::ParseError => e
        parse_failures << { line: example.line_number, error: e.message }
      end

      if parse_failures.any?
        messages = parse_failures.map { |f| "Line #{f[:line]}: #{f[:error]}" }
        raise "T-Ruby 파싱 실패:\n#{messages.join("\n")}"
      end
    end

    it "모든 T-Ruby 예제가 컴파일된다" do
      trb_examples = examples.select(&:trb?).select(&:should_verify?).select(&:should_compile?)
      skip "컴파일 대상 T-Ruby 예제 없음" if trb_examples.empty?

      compiler = TRuby::Compiler.new
      compile_failures = []

      trb_examples.each do |example|
        compiler.compile_string(example.code)
      rescue StandardError => e
        compile_failures << { line: example.line_number, error: e.message }
      end

      if compile_failures.any?
        messages = compile_failures.map { |f| "Line #{f[:line]}: #{f[:error]}" }
        raise "T-Ruby 컴파일 실패:\n#{messages.join("\n")}"
      end
    end

    it "모든 Ruby 예제가 유효한 문법이다" do
      ruby_examples = examples.select(&:ruby?).select(&:should_verify?)
      skip "Ruby 예제 없음" if ruby_examples.empty?

      syntax_failures = []
      ruby_examples.each do |example|
        RubyVM::InstructionSequence.compile(example.code)
      rescue SyntaxError => e
        syntax_failures << { line: example.line_number, error: e.message }
      end

      if syntax_failures.any?
        messages = syntax_failures.map { |f| "Line #{f[:line]}: #{f[:error]}" }
        raise "Ruby 문법 오류:\n#{messages.join("\n")}"
      end
    end

    it "모든 RBS 예제가 유효하다" do
      rbs_examples = examples.select(&:rbs?).select(&:should_verify?)
      skip "RBS 예제 없음" if rbs_examples.empty?

      invalid_examples = []
      rbs_examples.each do |example|
        # 기본 유효성 검사: def, type, interface, class 중 하나 포함
        unless example.code.match?(/\b(def|type|interface|class|module)\b/)
          invalid_examples << { line: example.line_number, error: "RBS 키워드 없음" }
        end
      end

      if invalid_examples.any?
        messages = invalid_examples.map { |f| "Line #{f[:line]}: #{f[:error]}" }
        raise "RBS 유효성 검사 실패:\n#{messages.join("\n")}"
      end
    end
  end
end

RSpec.shared_examples "code example" do |example_index, description|
  it "예제 #{example_index + 1}: #{description}" do
    example = examples[example_index]
    skip "예제를 찾을 수 없음" unless example

    result = verifier.verify_example(example)
    expect(result).to be_pass, -> { "검증 실패: #{result.errors.join(", ")}" }
  end
end
