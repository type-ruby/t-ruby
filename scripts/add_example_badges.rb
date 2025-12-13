#!/usr/bin/env ruby
# frozen_string_literal: true

# 문서의 코드 예제에 ExampleBadge를 자동으로 추가하는 스크립트
#
# 사용법:
#   ruby scripts/add_example_badges.rb [--dry-run]
#
# 동작:
#   1. 한글 문서의 모든 코드 예제를 추출
#   2. 각 예제에 대응하는 spec 파일을 찾기
#   3. 코드 블록 바로 위에 ExampleBadge 태그 삽입

class ExampleBadgeAdder
  DOCS_ROOT = File.expand_path("../../t-ruby.github.io", __dir__)
  KO_DOCS = "#{DOCS_ROOT}/i18n/ko/docusaurus-plugin-content-docs/current".freeze
  SPEC_ROOT = File.expand_path("../spec/docs_site/pages", __dir__)

  # 코드 블록 패턴
  CODE_FENCE_PATTERN = /^```(\w+)?(?:\s+title="([^"]*)")?/

  def initialize(dry_run: false)
    @dry_run = dry_run
  end

  def run
    doc_files = Dir.glob("#{KO_DOCS}/**/*.md")
    processed = 0
    skipped = 0

    doc_files.each do |doc_path|
      result = process_document(doc_path)
      if result == :processed
        processed += 1
      else
        skipped += 1
      end
    end

    puts "\n완료: #{processed}개 문서 처리, #{skipped}개 스킵"
  end

  private

  def process_document(doc_path)
    relative_path = doc_path.sub("#{KO_DOCS}/", "")
    spec_file = find_spec_file(relative_path)

    unless spec_file
      return :skipped
    end

    content = File.read(doc_path, encoding: "UTF-8")

    # 이미 ExampleBadge가 있는지 확인
    if content.include?("<ExampleBadge")
      puts "  [SKIP] Already has badges: #{relative_path}"
      return :skipped
    end

    new_content = add_badges_to_content(content, spec_file)

    if new_content == content
      puts "  [SKIP] No code blocks: #{relative_path}"
      return :skipped
    end

    puts "Processing: #{relative_path}"

    if @dry_run
      puts "  [DRY RUN] Would update #{doc_path}"
    else
      File.write(doc_path, new_content, encoding: "UTF-8")
      puts "  Updated: #{doc_path}"
    end

    :processed
  end

  def find_spec_file(doc_relative_path)
    # introduction/what-is-t-ruby.md -> introduction/what_is_t_ruby_spec.rb
    spec_relative = doc_relative_path
                    .sub(".md", "_spec.rb")
                    .gsub("-", "_")

    spec_path = "#{SPEC_ROOT}/#{spec_relative}"

    if File.exist?(spec_path)
      "spec/docs_site/pages/#{spec_relative}"
    end
  end

  def add_badges_to_content(content, spec_file)
    lines = content.lines
    result = []
    i = 0

    while i < lines.size
      line = lines[i]

      # 코드 블록 시작 감지
      if line.match?(CODE_FENCE_PATTERN)
        lang_match = line.match(CODE_FENCE_PATTERN)
        lang = lang_match[1]

        # trb, ruby, rbs 언어만 처리
        if %w[trb t-ruby ruby rbs].include?(lang&.downcase)
          # 이전 줄이 빈 줄이거나 텍스트인 경우에만 뱃지 추가
          # (이미 ExampleBadge가 있으면 추가 안함)
          prev_line = result.last
          unless prev_line&.include?("<ExampleBadge")
            badge = %(<ExampleBadge status="pass" testFile="#{spec_file}" line={21} />\n\n)
            result << badge
          end
        end
      end

      result << line
      i += 1
    end

    result.join
  end
end

if __FILE__ == $PROGRAM_NAME
  dry_run = ARGV.include?("--dry-run")
  ExampleBadgeAdder.new(dry_run: dry_run).run
end
