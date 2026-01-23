# frozen_string_literal: true

require "time"
require_relative "docs_example_verifier"

module TRuby
  # Generates badges and reports for documentation verification results.
  #
  # Supports:
  # - Shields.io compatible JSON badges
  # - SVG badge generation
  # - Markdown report generation
  # - JSON report generation
  #
  # @example
  #   generator = DocsBadgeGenerator.new
  #   verifier = DocsExampleVerifier.new
  #   results = verifier.verify_glob("docs/**/*.md")
  #   generator.generate_badge(results, "coverage/docs_badge.json")
  #
  class DocsBadgeGenerator
    # Badge colors based on pass rate
    COLORS = {
      excellent: "brightgreen",   # 95-100%
      good: "green",              # 80-94%
      fair: "yellow",             # 60-79%
      poor: "orange",             # 40-59%
      critical: "red",            # 0-39%
    }.freeze

    def initialize
      @verifier = DocsExampleVerifier.new
    end

    # Generate all outputs
    #
    # @param results [Array<DocsExampleVerifier::VerificationResult>] Results
    # @param output_dir [String] Output directory
    def generate_all(results, output_dir)
      FileUtils.mkdir_p(output_dir)

      generate_badge_json(results, File.join(output_dir, "docs_badge.json"))
      generate_badge_svg(results, File.join(output_dir, "docs_badge.svg"))
      generate_report_json(results, File.join(output_dir, "docs_report.json"))
      generate_report_markdown(results, File.join(output_dir, "docs_report.md"))
    end

    # Generate Shields.io compatible JSON badge
    #
    # @param results [Array<DocsExampleVerifier::VerificationResult>] Results
    # @param output_path [String] Output file path
    def generate_badge_json(results, output_path)
      summary = @verifier.summary(results)
      pass_rate = summary[:pass_rate]

      badge = {
        schemaVersion: 1,
        label: "docs examples",
        message: "#{pass_rate}%",
        color: color_for_rate(pass_rate),
      }

      File.write(output_path, JSON.pretty_generate(badge))
    end

    # Generate SVG badge
    #
    # @param results [Array<DocsExampleVerifier::VerificationResult>] Results
    # @param output_path [String] Output file path
    def generate_badge_svg(results, output_path)
      summary = @verifier.summary(results)
      pass_rate = summary[:pass_rate]
      color = svg_color_for_rate(pass_rate)

      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="140" height="20">
          <linearGradient id="b" x2="0" y2="100%">
            <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
            <stop offset="1" stop-opacity=".1"/>
          </linearGradient>
          <mask id="a">
            <rect width="140" height="20" rx="3" fill="#fff"/>
          </mask>
          <g mask="url(#a)">
            <path fill="#555" d="M0 0h85v20H0z"/>
            <path fill="#{color}" d="M85 0h55v20H85z"/>
            <path fill="url(#b)" d="M0 0h140v20H0z"/>
          </g>
          <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
            <text x="42.5" y="15" fill="#010101" fill-opacity=".3">docs examples</text>
            <text x="42.5" y="14">docs examples</text>
            <text x="112" y="15" fill="#010101" fill-opacity=".3">#{pass_rate}%</text>
            <text x="112" y="14">#{pass_rate}%</text>
          </g>
        </svg>
      SVG

      File.write(output_path, svg)
    end

    # Generate JSON report
    #
    # @param results [Array<DocsExampleVerifier::VerificationResult>] Results
    # @param output_path [String] Output file path
    def generate_report_json(results, output_path)
      summary = @verifier.summary(results)

      report = {
        generated_at: Time.now.iso8601,
        summary: summary,
        files: group_results_by_file(results),
      }

      File.write(output_path, JSON.pretty_generate(report))
    end

    # Generate Markdown report
    #
    # @param results [Array<DocsExampleVerifier::VerificationResult>] Results
    # @param output_path [String] Output file path
    def generate_report_markdown(results, output_path)
      summary = @verifier.summary(results)
      grouped = group_results_by_file(results)

      markdown = <<~MD
        # Documentation Examples Verification Report

        Generated: #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}

        ## Summary

        | Metric | Value |
        |--------|-------|
        | Total Examples | #{summary[:total]} |
        | Passed | #{summary[:passed]} |
        | Failed | #{summary[:failed]} |
        | Skipped | #{summary[:skipped]} |
        | **Pass Rate** | **#{summary[:pass_rate]}%** |

        ## Results by File

      MD

      grouped.each do |file_path, file_results|
        file_summary = @verifier.summary(file_results)
        status_emoji = file_summary[:failed].zero? ? "✅" : "❌"

        markdown += "### #{status_emoji} #{file_path}\n\n"
        markdown += "Pass rate: #{file_summary[:pass_rate]}% (#{file_summary[:passed]}/#{file_summary[:total]})\n\n"

        failed_results = file_results.select(&:fail?)
        next unless failed_results.any?

        markdown += "**Failed examples:**\n\n"
        failed_results.each do |result|
          markdown += "- Line #{result.line_number}:\n"
          result.errors.each do |error|
            markdown += "  - #{error}\n"
          end
        end
        markdown += "\n"
      end

      File.write(output_path, markdown)
    end

    private

    def color_for_rate(rate)
      case rate
      when 95..100 then COLORS[:excellent]
      when 80...95 then COLORS[:good]
      when 60...80 then COLORS[:fair]
      when 40...60 then COLORS[:poor]
      else COLORS[:critical]
      end
    end

    def svg_color_for_rate(rate)
      case rate
      when 95..100 then "#4c1"      # bright green
      when 80...95 then "#97ca00"   # green
      when 60...80 then "#dfb317"   # yellow
      when 40...60 then "#fe7d37"   # orange
      else "#e05d44"                # red
      end
    end

    def group_results_by_file(results)
      results.group_by(&:file_path)
    end
  end
end
