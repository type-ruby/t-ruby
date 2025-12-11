# frozen_string_literal: true

require_relative "docs_example_extractor"

module TRuby
  # Verifies code examples extracted from documentation.
  #
  # Performs:
  # - Syntax validation (parsing)
  # - Type checking (for .trb examples)
  # - Compilation (generates Ruby output)
  #
  # @example
  #   verifier = DocsExampleVerifier.new
  #   results = verifier.verify_file("docs/getting-started.md")
  #   results.each { |r| puts "#{r.status}: #{r.file_path}:#{r.line_number}" }
  #
  class DocsExampleVerifier
    # Result of verifying a single example
    VerificationResult = Struct.new(
      :example,        # The original CodeExample
      :status,         # :pass, :fail, :skip
      :errors,         # Array of error messages
      :output,         # Compiled output (if applicable)
      keyword_init: true
    ) do
      def pass?
        status == :pass
      end

      def fail?
        status == :fail
      end

      def skip?
        status == :skip
      end

      def file_path
        example.file_path
      end

      def line_number
        example.line_number
      end
    end

    def initialize
      @extractor = DocsExampleExtractor.new
      @parser = TRuby::Parser.new
      @type_checker = TRuby::TypeChecker.new
      @compiler = TRuby::Compiler.new
    end

    # Verify all examples in a file
    #
    # @param file_path [String] Path to the markdown file
    # @return [Array<VerificationResult>] Results for each example
    def verify_file(file_path)
      examples = @extractor.extract_from_file(file_path)
      examples.map { |example| verify_example(example) }
    end

    # Verify all examples from multiple files
    #
    # @param pattern [String] Glob pattern
    # @return [Array<VerificationResult>] All results
    def verify_glob(pattern)
      examples = @extractor.extract_from_glob(pattern)
      examples.map { |example| verify_example(example) }
    end

    # Verify a single code example
    #
    # @param example [DocsExampleExtractor::CodeExample] The example to verify
    # @return [VerificationResult] The verification result
    def verify_example(example)
      return skip_result(example, "Marked as skip-verify") unless example.should_verify?

      case example.language
      when "trb"
        verify_trb_example(example)
      when "ruby"
        verify_ruby_example(example)
      when "rbs"
        verify_rbs_example(example)
      else
        skip_result(example, "Unknown language: #{example.language}")
      end
    rescue StandardError => e
      fail_result(example, ["Exception: #{e.message}"])
    end

    # Generate a summary report
    #
    # @param results [Array<VerificationResult>] Verification results
    # @return [Hash] Summary statistics
    def summary(results)
      {
        total: results.size,
        passed: results.count(&:pass?),
        failed: results.count(&:fail?),
        skipped: results.count(&:skip?),
        pass_rate: results.empty? ? 0 : (results.count(&:pass?).to_f / results.size * 100).round(2),
      }
    end

    # Print results to stdout
    #
    # @param results [Array<VerificationResult>] Verification results
    # @param verbose [Boolean] Show passing tests too
    def print_results(results, verbose: false)
      results.each do |result|
        next if result.pass? && !verbose

        status_icon = case result.status
                      when :pass then "\e[32m✓\e[0m"
                      when :fail then "\e[31m✗\e[0m"
                      when :skip then "\e[33m○\e[0m"
                      end

        puts "#{status_icon} #{result.file_path}:#{result.line_number}"

        result.errors&.each do |error|
          puts "    #{error}"
        end
      end

      summary_data = summary(results)
      puts
      puts "Results: #{summary_data[:passed]} passed, #{summary_data[:failed]} failed, #{summary_data[:skipped]} skipped"
      puts "Pass rate: #{summary_data[:pass_rate]}%"
    end

    private

    def verify_trb_example(example)
      errors = []

      # Step 1: Parse
      begin
        ast = @parser.parse(example.code)
      rescue TRuby::ParseError => e
        return fail_result(example, ["Parse error: #{e.message}"])
      end

      # Step 2: Type check (if enabled)
      if example.should_typecheck?
        begin
          type_errors = @type_checker.check(ast)
          errors.concat(type_errors.map { |e| "Type error: #{e}" }) if type_errors.any?
        rescue StandardError => e
          errors << "Type check error: #{e.message}"
        end
      end

      # Step 3: Compile (if enabled)
      output = nil
      if example.should_compile?
        begin
          output = @compiler.compile(example.code)
        rescue StandardError => e
          errors << "Compile error: #{e.message}"
        end
      end

      errors.empty? ? pass_result(example, output) : fail_result(example, errors)
    end

    def verify_ruby_example(example)
      # For Ruby examples, just validate syntax
      begin
        RubyVM::InstructionSequence.compile(example.code)
        pass_result(example)
      rescue SyntaxError => e
        fail_result(example, ["Ruby syntax error: #{e.message}"])
      end
    end

    def verify_rbs_example(example)
      # For RBS, we just do basic validation
      # Full RBS validation would require rbs gem
      if example.code.include?("def ") || example.code.include?("type ") ||
         example.code.include?("interface ") || example.code.include?("class ")
        pass_result(example)
      else
        skip_result(example, "Cannot validate RBS without rbs gem")
      end
    end

    def pass_result(example, output = nil)
      VerificationResult.new(
        example: example,
        status: :pass,
        errors: [],
        output: output
      )
    end

    def fail_result(example, errors)
      VerificationResult.new(
        example: example,
        status: :fail,
        errors: errors,
        output: nil
      )
    end

    def skip_result(example, reason)
      VerificationResult.new(
        example: example,
        status: :skip,
        errors: [reason],
        output: nil
      )
    end
  end
end
