# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Documentation Site Components" do
  let(:docs_site_path) { File.expand_path("../../../t-ruby.github.io", __dir__) }

  before(:all) do
    @docs_site_path = File.expand_path("../../../t-ruby.github.io", __dir__)
    skip "t-ruby.github.io not found at #{@docs_site_path}" unless Dir.exist?(@docs_site_path)
  end

  describe "DocsBadge component" do
    let(:component_path) { "#{docs_site_path}/src/components/DocsBadge/index.tsx" }

    it "exists" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)
      expect(File.exist?(component_path)).to be true
    end

    it "uses lucide-react BadgeCheck icon" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)
      content = File.read(component_path)
      expect(content).to include("BadgeCheck")
      expect(content).to include("lucide-react")
    end
  end

  describe "VerifiedBadge component" do
    let(:component_path) { "#{docs_site_path}/src/components/VerifiedBadge/index.tsx" }

    it "exists" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)
      expect(File.exist?(component_path)).to be true
    end

    it "supports pass and fail status" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)
      content = File.read(component_path)
      expect(content).to include("'pass'")
      expect(content).to include("'fail'")
    end

    it "uses lucide-react icons" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)
      content = File.read(component_path)
      expect(content).to include("lucide-react")
      expect(content).to include("BadgeCheck")
    end
  end

  describe "MDXComponents theme override" do
    let(:mdx_components_path) { "#{docs_site_path}/src/theme/MDXComponents.tsx" }

    it "exists" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)
      expect(File.exist?(mdx_components_path)).to be true
    end

    it "exports DocsBadge and VerifiedBadge" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)
      content = File.read(mdx_components_path)
      expect(content).to include("DocsBadge")
      expect(content).to include("VerifiedBadge")
    end
  end

  describe "Package dependencies" do
    let(:package_json_path) { "#{docs_site_path}/package.json" }

    it "has lucide-react installed" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)
      content = File.read(package_json_path)
      expect(content).to include("lucide-react")
    end
  end

  describe "DocsBadge usage in documents" do
    it "all Korean documents have DocsBadge" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)

      ko_docs = Dir.glob("#{docs_site_path}/i18n/ko/docusaurus-plugin-content-docs/current/**/*.md")
      missing_badge = ko_docs.reject do |file|
        content = File.read(file)
        content.include?("<DocsBadge")
      end

      if missing_badge.any?
        fail "#{missing_badge.size} Korean documents missing DocsBadge:\n#{missing_badge.join("\n")}"
      end

      expect(missing_badge).to be_empty
    end

    it "all English documents have DocsBadge" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)

      en_docs = Dir.glob("#{docs_site_path}/docs/**/*.md")
      missing_badge = en_docs.reject do |file|
        content = File.read(file)
        content.include?("<DocsBadge")
      end

      if missing_badge.any?
        fail "#{missing_badge.size} English documents missing DocsBadge:\n#{missing_badge.join("\n")}"
      end

      expect(missing_badge).to be_empty
    end

    it "all Japanese documents have DocsBadge" do
      skip "t-ruby.github.io not found" unless Dir.exist?(docs_site_path)

      ja_docs = Dir.glob("#{docs_site_path}/i18n/ja/docusaurus-plugin-content-docs/current/**/*.md")
      missing_badge = ja_docs.reject do |file|
        content = File.read(file)
        content.include?("<DocsBadge")
      end

      if missing_badge.any?
        fail "#{missing_badge.size} Japanese documents missing DocsBadge:\n#{missing_badge.join("\n")}"
      end

      expect(missing_badge).to be_empty
    end
  end
end
