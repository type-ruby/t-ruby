# frozen_string_literal: true

module TRuby
  class ErrorReporter
    attr_reader :diagnostics

    def initialize(formatter: nil)
      @diagnostics = []
      @formatter = formatter || DiagnosticFormatter.new
      @source_cache = {}
    end

    def add(diagnostic)
      @diagnostics << diagnostic
    end

    def add_type_check_error(error, file:, source: nil)
      source ||= load_source(file)
      add(Diagnostic.from_type_check_error(error, file: file, source: source))
    end

    def add_parse_error(error, file:, source: nil)
      source ||= load_source(file)
      add(Diagnostic.from_parse_error(error, file: file, source: source))
    end

    def add_scan_error(error, file:, source: nil)
      source ||= load_source(file)
      add(Diagnostic.from_scan_error(error, file: file, source: source))
    end

    def has_errors?
      @diagnostics.any? { |d| d.severity == Diagnostic::SEVERITY_ERROR }
    end

    def error_count
      @diagnostics.count { |d| d.severity == Diagnostic::SEVERITY_ERROR }
    end

    def report
      @formatter.format_all(@diagnostics)
    end

    def clear
      @diagnostics.clear
      @source_cache.clear
    end

    private

    def load_source(file)
      return nil unless file && File.exist?(file)

      @source_cache[file] ||= File.read(file)
    end
  end
end
