# frozen_string_literal: true

require "spec_helper"

RSpec.describe "다국어 문서 구조 일치 테스트" do
  let(:docs_site_root) { File.expand_path("../../../t-ruby.github.io", __dir__) }
  let(:ko_docs_root) { "#{docs_site_root}/i18n/ko/docusaurus-plugin-content-docs/current" }
  let(:en_docs_root) { "#{docs_site_root}/docs" }
  let(:ja_docs_root) { "#{docs_site_root}/i18n/ja/docusaurus-plugin-content-docs/current" }

  before(:all) do
    @docs_site_root = File.expand_path("../../../t-ruby.github.io", __dir__)
    skip "t-ruby.github.io not found at #{@docs_site_root}" unless Dir.exist?(@docs_site_root)
  end

  def relative_paths(base_path)
    Dir.glob("#{base_path}/**/*.md").map do |file|
      file.sub("#{base_path}/", "")
    end.sort
  end

  describe "한글 문서 (기준)" do
    it "한글 문서 폴더가 존재한다" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
      expect(Dir.exist?(ko_docs_root)).to be true
    end

    it "한글 문서가 존재한다" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
      ko_docs = Dir.glob("#{ko_docs_root}/**/*.md")
      expect(ko_docs).not_to be_empty
    end
  end

  describe "영어 문서 구조 일치" do
    it "영어 문서 폴더가 존재한다" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
      expect(Dir.exist?(en_docs_root)).to be true
    end

    it "한글 문서와 동일한 파일 수를 가진다" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)

      ko_count = Dir.glob("#{ko_docs_root}/**/*.md").size
      en_count = Dir.glob("#{en_docs_root}/**/*.md").size

      expect(en_count).to eq(ko_count),
        "영어 문서 수(#{en_count})가 한글 문서 수(#{ko_count})와 다릅니다"
    end

    it "한글 문서와 동일한 파일 구조를 가진다" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)

      ko_structure = relative_paths(ko_docs_root)
      en_structure = relative_paths(en_docs_root)

      missing_in_en = ko_structure - en_structure
      extra_in_en = en_structure - ko_structure

      error_messages = []
      if missing_in_en.any?
        error_messages << "영어 문서에 없는 파일:\n  #{missing_in_en.join("\n  ")}"
      end
      if extra_in_en.any?
        error_messages << "한글 문서에 없는 파일 (영어에만 존재):\n  #{extra_in_en.join("\n  ")}"
      end

      expect(error_messages).to be_empty, error_messages.join("\n\n")
    end
  end

  describe "일본어 문서 구조 일치" do
    it "일본어 문서 폴더가 존재한다" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
      expect(Dir.exist?(ja_docs_root)).to be true
    end

    it "한글 문서와 동일한 파일 수를 가진다" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)

      ko_count = Dir.glob("#{ko_docs_root}/**/*.md").size
      ja_count = Dir.glob("#{ja_docs_root}/**/*.md").size

      expect(ja_count).to eq(ko_count),
        "일본어 문서 수(#{ja_count})가 한글 문서 수(#{ko_count})와 다릅니다"
    end

    it "한글 문서와 동일한 파일 구조를 가진다" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)

      ko_structure = relative_paths(ko_docs_root)
      ja_structure = relative_paths(ja_docs_root)

      missing_in_ja = ko_structure - ja_structure
      extra_in_ja = ja_structure - ko_structure

      error_messages = []
      if missing_in_ja.any?
        error_messages << "일본어 문서에 없는 파일:\n  #{missing_in_ja.join("\n  ")}"
      end
      if extra_in_ja.any?
        error_messages << "한글 문서에 없는 파일 (일본어에만 존재):\n  #{extra_in_ja.join("\n  ")}"
      end

      expect(error_messages).to be_empty, error_messages.join("\n\n")
    end
  end

  describe "섹션별 구조 상세 검증" do
    SECTIONS = %w[
      introduction
      getting-started
      learn
      cli
      reference
      tooling
      project
    ].freeze

    SECTIONS.each do |section|
      describe "#{section}/ 섹션" do
        it "한글 문서에 #{section} 폴더가 존재한다" do
          skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
          expect(Dir.exist?("#{ko_docs_root}/#{section}")).to be true
        end

        it "영어 문서에 #{section} 폴더가 존재한다" do
          skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
          expect(Dir.exist?("#{en_docs_root}/#{section}")).to be true
        end

        it "일본어 문서에 #{section} 폴더가 존재한다" do
          skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)
          expect(Dir.exist?("#{ja_docs_root}/#{section}")).to be true
        end

        it "#{section} 섹션의 파일 수가 일치한다" do
          skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_root)

          ko_files = Dir.glob("#{ko_docs_root}/#{section}/**/*.md").size
          en_files = Dir.glob("#{en_docs_root}/#{section}/**/*.md").size
          ja_files = Dir.glob("#{ja_docs_root}/#{section}/**/*.md").size

          expect(en_files).to eq(ko_files),
            "#{section}: 영어(#{en_files}) != 한글(#{ko_files})"
          expect(ja_files).to eq(ko_files),
            "#{section}: 일본어(#{ja_files}) != 한글(#{ko_files})"
        end
      end
    end
  end
end
