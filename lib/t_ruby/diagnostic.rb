# frozen_string_literal: true

module TRuby
  class Diagnostic
    SEVERITY_ERROR = :error
    SEVERITY_WARNING = :warning
    SEVERITY_INFO = :info
    SEVERITY_HINT = :hint

    attr_reader :code, :message, :file, :line, :column, :end_column,
                :severity, :expected, :actual, :suggestion, :source_line

    # rubocop:disable Metrics/ParameterLists
    def initialize(
      code:,
      message:,
      file: nil,
      line: nil,
      column: nil,
      end_column: nil,
      severity: SEVERITY_ERROR,
      expected: nil,
      actual: nil,
      suggestion: nil,
      source_line: nil
    )
      # rubocop:enable Metrics/ParameterLists
      @code = code
      @message = message
      @file = file
      @line = line
      @column = column || 1
      @end_column = end_column || (@column + 1)
      @severity = severity
      @expected = expected
      @actual = actual
      @suggestion = suggestion
      @source_line = source_line
    end

    def self.from_type_check_error(error, file: nil, source: nil)
      line, col = parse_location(error.location)
      source_line = extract_source_line(source, line) if source && line

      new(
        code: "TR2001",
        message: error.error_message,
        file: file,
        line: line,
        column: col,
        severity: error.severity || SEVERITY_ERROR,
        expected: error.expected,
        actual: error.actual,
        suggestion: error.suggestion,
        source_line: source_line
      )
    end

    def self.from_parse_error(error, file: nil, source: nil)
      source_line = extract_source_line(source, error.line) if source && error.line

      new(
        code: "TR1001",
        message: error.message,
        file: file,
        line: error.line,
        column: error.column,
        source_line: source_line
      )
    end

    def self.from_scan_error(error, file: nil, source: nil)
      source_line = extract_source_line(source, error.line) if source && error.line
      # ScanError adds " at line X, column Y" to the message in its constructor
      message = error.message.sub(/ at line \d+, column \d+\z/, "")

      new(
        code: "TR1001",
        message: message,
        file: file,
        line: error.line,
        column: error.column,
        source_line: source_line
      )
    end

    def error?
      @severity == SEVERITY_ERROR
    end

    def self.parse_location(location_str)
      return [nil, 1] unless location_str

      case location_str
      when /:(\d+):(\d+)$/
        [::Regexp.last_match(1).to_i, ::Regexp.last_match(2).to_i]
      when /:(\d+)$/
        [::Regexp.last_match(1).to_i, 1]
      when /line (\d+)/i
        [::Regexp.last_match(1).to_i, 1]
      else
        [nil, 1]
      end
    end

    def self.extract_source_line(source, line_num)
      return nil unless source && line_num

      lines = source.split("\n")
      lines[line_num - 1] if line_num.positive? && line_num <= lines.length
    end

    private_class_method :parse_location, :extract_source_line
  end
end
