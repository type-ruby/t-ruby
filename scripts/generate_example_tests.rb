#!/usr/bin/env ruby
# frozen_string_literal: true

# 문서의 코드 예제를 분석하여:
# 1. spec 파일에 개별 예제 테스트 생성
# 2. 문서의 ExampleBadge 라인 번호 업데이트
#
# 사용법:
#   ruby scripts/generate_example_tests.rb [--dry-run]

require_relative "../lib/t_ruby/docs_example_extractor"

class ExampleTestGenerator
  DOCS_ROOT = File.expand_path("../../t-ruby.github.io", __dir__)
  KO_DOCS = "#{DOCS_ROOT}/i18n/ko/docusaurus-plugin-content-docs/current"
  SPEC_ROOT = File.expand_path("../spec/docs_site/pages", __dir__)

  def initialize(dry_run: false)
    @dry_run = dry_run
    @extractor = TRuby::DocsExampleExtractor.new
  end

  def run
    doc_files = Dir.glob("#{KO_DOCS}/**/*.md")

    doc_files.each do |doc_path|
      process_document(doc_path)
    end
  end

  private

  def process_document(doc_path)
    relative_path = doc_path.sub("#{KO_DOCS}/", "")
    spec_relative = relative_path.sub(".md", "_spec.rb").gsub("-", "_")
    spec_path = "#{SPEC_ROOT}/#{spec_relative}"

    return unless File.exist?(spec_path)

    examples = @extractor.extract_from_file(doc_path)
    return if examples.empty?

    puts "Processing: #{relative_path} (#{examples.size} examples)"

    # 1. spec 파일 생성
    spec_content = generate_spec_content(relative_path, examples)
    line_map = calculate_line_map(spec_content, examples)

    # 2. 문서 업데이트
    doc_content = File.read(doc_path, encoding: "UTF-8")
    updated_doc = update_doc_badges(doc_content, examples, spec_relative, line_map)

    if @dry_run
      puts "  [DRY RUN] Would update spec and doc"
      puts "  Line map: #{line_map.inspect}"
    else
      File.write(spec_path, spec_content, encoding: "UTF-8")
      File.write(doc_path, updated_doc, encoding: "UTF-8")
      puts "  Updated: #{spec_path}"
      puts "  Updated: #{doc_path}"
    end
  end

  def generate_spec_content(relative_path, examples)
    doc_name = relative_path.sub(".md", "").split("/").last.gsub("-", " ").split.map(&:capitalize).join(" ")

    lines = []
    lines << '# frozen_string_literal: true'
    lines << ''
    lines << 'require "spec_helper"'
    lines << 'require_relative "../support/shared_examples"'
    lines << ''
    lines << "RSpec.describe \"한글 문서: #{doc_name}\" do"
    lines << '  include_context "docs site paths"'
    lines << ''
    lines << "  let(:relative_path) { \"#{relative_path}\" }"
    lines << '  let(:doc_path) { "#{ko_docs_root}/#{relative_path}" }'
    lines << '  let(:doc_content) { File.read(doc_path) }'
    lines << '  let(:extractor) { TRuby::DocsExampleExtractor.new }'
    lines << '  let(:verifier) { TRuby::DocsExampleVerifier.new }'
    lines << '  let(:examples) { extractor.extract_from_file(doc_path) }'
    lines << ''
    lines << '  before do'
    lines << '    skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)'
    lines << '    skip "Document not found" unless File.exist?(doc_path)'
    lines << '  end'
    lines << ''
    lines << "  it_behaves_like \"valid documentation page\", \"#{relative_path}\""
    lines << ''
    lines << '  describe "코드 예제" do'

    examples.each_with_index do |example, index|
      lines << generate_example_test(example, index)
    end

    lines << '  end'
    lines << 'end'
    lines << ''

    lines.join("\n")
  end

  def generate_example_test(example, index)
    # 예제 코드의 첫 줄을 기반으로 설명 생성
    first_line = example.code.lines.first&.strip || "코드"
    first_line = first_line[0..40] + "..." if first_line.length > 40

    lang_name = case example.language
                when "trb" then "T-Ruby"
                when "ruby" then "Ruby"
                when "rbs" then "RBS"
                else example.language
                end

    lines = []
    lines << ''
    lines << "    # 예제 #{index + 1}: #{lang_name} (라인 #{example.line_number})"
    lines << "    describe \"예제 #{index + 1}: #{lang_name} 코드\" do"
    lines << "      let(:example) { examples[#{index}] }"
    lines << ''

    case example.language
    when "trb"
      lines << '      it "T-Ruby 코드가 파싱에 성공한다" do'
      lines << '        skip "예제를 찾을 수 없음" unless example'
      lines << '        parser = TRuby::Parser.new(example.code)'
      lines << '        expect { parser.parse }.not_to raise_error'
      lines << '      end'
    when "ruby"
      lines << '      it "유효한 Ruby 문법이다" do'
      lines << '        skip "예제를 찾을 수 없음" unless example'
      lines << '        expect { RubyVM::InstructionSequence.compile(example.code) }.not_to raise_error'
      lines << '      end'
    when "rbs"
      lines << '      it "RBS 형식이다" do'
      lines << '        skip "예제를 찾을 수 없음" unless example'
      lines << '        expect(example.code).to match(/\b(def|class|module|interface|type)\b/)'
      lines << '      end'
    end

    lines << '    end'
    lines.join("\n")
  end

  def calculate_line_map(spec_content, examples)
    # spec 파일에서 각 예제 테스트의 시작 라인 번호 계산
    line_map = {}

    spec_content.lines.each_with_index do |line, index|
      if match = line.match(/# 예제 (\d+):/)
        example_index = match[1].to_i - 1
        line_map[example_index] = index + 1  # 1-based line number
      end
    end

    line_map
  end

  def update_doc_badges(doc_content, examples, spec_file, line_map)
    lines = doc_content.lines
    result = []
    example_index = 0

    i = 0
    while i < lines.size
      line = lines[i]

      # ExampleBadge 찾기
      if line.include?("<ExampleBadge")
        # 다음 코드 블록의 예제 인덱스 찾기
        test_line = line_map[example_index] || 21

        # 라인 번호 업데이트
        updated_badge = line.gsub(/line=\{\d+\}/, "line={#{test_line}}")
        result << updated_badge
        example_index += 1
      else
        result << line
      end

      i += 1
    end

    result.join
  end
end

if __FILE__ == $0
  dry_run = ARGV.include?("--dry-run")
  ExampleTestGenerator.new(dry_run: dry_run).run
end
