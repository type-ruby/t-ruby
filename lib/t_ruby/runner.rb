# frozen_string_literal: true

require "thor"

module TRuby
  # Thor-based CLI for t-ruby command
  # Runs .trb files directly without generating intermediate files
  class RunnerCLI < Thor
    def self.exit_on_failure?
      true
    end

    # Override Thor's default behavior to treat unknown arguments as the file to run
    def self.start(given_args = ARGV, _config = {})
      # Handle version flag
      if given_args.include?("--version") || given_args.include?("-v")
        new.version
        return
      end

      # Handle help flag or no arguments
      if given_args.empty? || given_args.include?("--help") || given_args.include?("-h")
        new.help
        return
      end

      # Treat first argument as file, rest as script arguments
      file = given_args.first
      args = given_args[1..] || []

      runner = Runner.new
      runner.run_file(file, args)
    end

    desc "FILE [ARGS...]", "Run a .trb file directly without generating files"
    def run_file(file, *args)
      runner = Runner.new
      runner.run_file(file, args)
    end

    map %w[--version -v] => :version
    desc "--version, -v", "Show version"
    def version
      puts "t-ruby #{VERSION}"
    end

    desc "--help, -h", "Show help"
    def help
      puts <<~HELP
        t-ruby v#{VERSION} - Run T-Ruby files directly

        Usage:
          t-ruby <file.trb>              Run a .trb file directly
          t-ruby <file.trb> [args...]    Run with arguments passed to the script
          t-ruby --version, -v           Show version
          t-ruby --help, -h              Show this help

        Examples:
          t-ruby hello.trb               Run hello.trb
          t-ruby server.trb 8080         Run with argument 8080
          t-ruby script.trb foo bar      Run with multiple arguments

        Notes:
          - No .rb or .rbs files are generated
          - Type annotations are stripped at runtime
          - Arguments after the file are passed to ARGV
      HELP
    end
  end

  # Runner class - executes T-Ruby code directly
  # Can be used as a library or through RunnerCLI
  class Runner
    def initialize(config = nil)
      @config = config || Config.new
      @compiler = Compiler.new(@config)
    end

    # Run a .trb file directly
    # @param input_path [String] Path to the .trb file
    # @param argv [Array<String>] Arguments to pass to the script via ARGV
    def run_file(input_path, argv = [])
      unless File.exist?(input_path)
        warn "Error: File not found: #{input_path}"
        exit 1
      end

      source = File.read(input_path)
      result = @compiler.compile_string(source)

      if result[:errors].any?
        result[:errors].each { |e| warn e }
        exit 1
      end

      execute_ruby(result[:ruby], input_path, argv)
    end

    # Run T-Ruby source code from a string
    # @param source [String] T-Ruby source code
    # @param filename [String] Filename for error reporting
    # @param argv [Array<String>] Arguments to pass via ARGV
    # @return [Boolean] true if execution succeeded
    def run_string(source, filename: "(t-ruby)", argv: [])
      result = @compiler.compile_string(source)

      if result[:errors].any?
        result[:errors].each { |e| warn e }
        return false
      end

      execute_ruby(result[:ruby], filename, argv)
      true
    end

    private

    # Execute Ruby code with proper script environment
    # @param ruby_code [String] Ruby code to execute
    # @param filename [String] Script filename (for $0 and stack traces)
    # @param argv [Array<String>] Script arguments
    def execute_ruby(ruby_code, filename, argv)
      # Set up script environment
      ARGV.replace(argv)
      $0 = filename

      # Execute using eval with filename and line number preserved
      # This ensures stack traces point to the original .trb file
      TOPLEVEL_BINDING.eval(ruby_code, filename, 1)
    end
  end
end
