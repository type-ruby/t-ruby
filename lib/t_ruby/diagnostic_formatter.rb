# frozen_string_literal: true

module TRuby
  class DiagnosticFormatter
    COLORS = {
      reset: "\e[0m",
      bold: "\e[1m",
      dim: "\e[2m",
      red: "\e[31m",
      green: "\e[32m",
      yellow: "\e[33m",
      blue: "\e[34m",
      cyan: "\e[36m",
      gray: "\e[90m",
      white: "\e[37m",
    }.freeze

    def initialize(use_colors: nil)
      @use_colors = use_colors.nil? ? $stdout.tty? : use_colors
    end

    def format(diagnostic)
      lines = []

      lines << format_header(diagnostic)

      if diagnostic.source_line && diagnostic.line
        lines << ""
        lines << format_source_snippet(diagnostic)
        lines << format_marker(diagnostic)
        lines.concat(format_context(diagnostic))
      end

      lines.join("\n")
    end

    def format_all(diagnostics)
      return "" if diagnostics.empty?

      output = diagnostics.map { |d| format(d) }.join("\n\n")
      "#{output}\n\n#{format_summary(diagnostics)}"
    end

    private

    def format_header(diagnostic)
      location = format_location(diagnostic)
      severity_text = colorize(severity_color(diagnostic.severity), diagnostic.severity.to_s)
      code_text = colorize(:gray, diagnostic.code)

      "#{location} - #{severity_text} #{code_text}: #{diagnostic.message}"
    end

    def format_location(diagnostic)
      file_part = colorize(:cyan, diagnostic.file || "<unknown>")

      if diagnostic.line
        line_part = colorize(:yellow, diagnostic.line.to_s)
        col_part = colorize(:yellow, diagnostic.column.to_s)
        "#{file_part}:#{line_part}:#{col_part}"
      else
        file_part
      end
    end

    def format_source_snippet(diagnostic)
      line_num = diagnostic.line.to_s.rjust(4)
      line_num_colored = colorize(:gray, line_num)

      "#{line_num_colored} | #{diagnostic.source_line}"
    end

    def format_marker(diagnostic)
      col = diagnostic.column || 1
      width = calculate_marker_width(diagnostic)

      indent = "#{" " * 4} | #{" " * (col - 1)}"
      marker = colorize(:red, "~" * width)

      "#{indent}#{marker}"
    end

    def calculate_marker_width(diagnostic)
      # If end_column is explicitly set (not just default column + 1), use it
      if diagnostic.end_column && diagnostic.end_column > diagnostic.column + 1
        diagnostic.end_column - diagnostic.column
      elsif diagnostic.source_line
        # Try to guess width from identifier at error position
        remaining = diagnostic.source_line[(diagnostic.column - 1)..]
        if remaining && remaining =~ /^(\w+)/
          ::Regexp.last_match(1).length
        else
          1
        end
      else
        1
      end
    end

    def format_context(diagnostic)
      lines = []
      indent = "#{" " * 4} | "

      if diagnostic.expected
        label = colorize(:dim, "Expected:")
        value = colorize(:green, diagnostic.expected)
        lines << "#{indent}#{label} #{value}"
      end

      if diagnostic.actual
        label = colorize(:dim, "Actual:")
        value = colorize(:red, diagnostic.actual)
        lines << "#{indent}#{label} #{value}"
      end

      if diagnostic.suggestion
        label = colorize(:dim, "Suggestion:")
        lines << "#{indent}#{label} #{diagnostic.suggestion}"
      end

      lines
    end

    def format_summary(diagnostics)
      error_count = diagnostics.count { |d| d.severity == Diagnostic::SEVERITY_ERROR }
      warning_count = diagnostics.count { |d| d.severity == Diagnostic::SEVERITY_WARNING }

      parts = []

      if error_count.positive?
        error_word = error_count == 1 ? "error" : "errors"
        parts << colorize(:red, "#{error_count} #{error_word}")
      end

      if warning_count.positive?
        warning_word = warning_count == 1 ? "warning" : "warnings"
        parts << colorize(:yellow, "#{warning_count} #{warning_word}")
      end

      if parts.empty?
        colorize(:green, "No errors found.")
      else
        "Found #{parts.join(" and ")}."
      end
    end

    def severity_color(severity)
      case severity
      when :error then :red
      when :warning then :yellow
      else :white
      end
    end

    def colorize(color, text)
      return text.to_s unless @use_colors
      return text.to_s unless COLORS[color]

      "#{COLORS[color]}#{text}#{COLORS[:reset]}"
    end
  end
end
