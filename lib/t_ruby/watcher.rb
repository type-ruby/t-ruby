# frozen_string_literal: true

require "listen"

module TRuby
  class Watcher
    # ANSI color codes (similar to tsc output style)
    COLORS = {
      reset: "\e[0m",
      bold: "\e[1m",
      dim: "\e[2m",
      red: "\e[31m",
      green: "\e[32m",
      yellow: "\e[33m",
      blue: "\e[34m",
      cyan: "\e[36m",
      gray: "\e[90m"
    }.freeze

    def initialize(paths: ["."], config: nil)
      @paths = paths.map { |p| File.expand_path(p) }
      @config = config || Config.new
      @compiler = Compiler.new(@config)
      @error_count = 0
      @file_count = 0
      @use_colors = $stdout.tty?
    end

    def watch
      print_start_message

      # Initial compilation
      compile_all

      # Start watching
      listener = Listen.to(*watch_directories, only: /\.trb$/) do |modified, added, removed|
        handle_changes(modified, added, removed)
      end

      listener.start

      print_watching_message

      # Keep the process running
      begin
        sleep
      rescue Interrupt
        puts "\n#{colorize(:dim, timestamp)} #{colorize(:cyan, "Stopping watch mode...")}"
        listener.stop
      end
    end

    private

    def watch_directories
      @paths.map do |path|
        if File.directory?(path)
          path
        else
          File.dirname(path)
        end
      end.uniq
    end

    def handle_changes(modified, added, removed)
      changed_files = (modified + added).select { |f| f.end_with?(".trb") }
      return if changed_files.empty? && removed.empty?

      puts
      print_file_change_message

      if removed.any?
        removed.each do |file|
          puts "#{colorize(:gray, timestamp)} #{colorize(:yellow, "File removed:")} #{relative_path(file)}"
        end
      end

      if changed_files.any?
        compile_files(changed_files)
      else
        print_watching_message
      end
    end

    def compile_all
      @error_count = 0
      @file_count = 0
      errors = []

      trb_files = find_trb_files
      @file_count = trb_files.size

      trb_files.each do |file|
        result = compile_file(file)
        errors.concat(result[:errors]) if result[:errors].any?
      end

      print_errors(errors)
      print_summary
    end

    def compile_files(files)
      @error_count = 0
      @file_count = files.size
      errors = []

      files.each do |file|
        result = compile_file(file)
        errors.concat(result[:errors]) if result[:errors].any?
      end

      print_errors(errors)
      print_summary
      print_watching_message
    end

    def compile_file(file)
      result = { file: file, errors: [], success: false }

      begin
        @compiler.compile(file)
        result[:success] = true
      rescue ArgumentError => e
        @error_count += 1
        result[:errors] << format_error(file, e.message)
      rescue StandardError => e
        @error_count += 1
        result[:errors] << format_error(file, e.message)
      end

      result
    end

    def find_trb_files
      files = []
      @paths.each do |path|
        if File.directory?(path)
          files.concat(Dir.glob(File.join(path, "**", "*.trb")))
        elsif File.file?(path) && path.end_with?(".trb")
          files << path
        end
      end
      files.uniq
    end

    def format_error(file, message)
      # Parse error message for line/column info if available
      # Format: file:line:col - error TRB0001: message
      line = 1
      col = 1

      # Try to extract line info from error message
      if message =~ /line (\d+)/i
        line = ::Regexp.last_match(1).to_i
      end

      {
        file: file,
        line: line,
        col: col,
        message: message
      }
    end

    def print_errors(errors)
      errors.each do |error|
        puts
        # TypeScript-style error format: file:line:col - error TSXXXX: message
        location = "#{colorize(:cyan, relative_path(error[:file]))}:#{colorize(:yellow, error[:line])}:#{colorize(:yellow, error[:col])}"
        puts "#{location} - #{colorize(:red, "error")} #{colorize(:gray, "TRB0001")}: #{error[:message]}"
      end
    end

    def print_start_message
      puts "#{colorize(:gray, timestamp)} #{colorize(:bold, "Starting compilation in watch mode...")}"
      puts
    end

    def print_file_change_message
      puts "#{colorize(:gray, timestamp)} #{colorize(:bold, "File change detected. Starting incremental compilation...")}"
      puts
    end

    def print_summary
      puts
      if @error_count.zero?
        msg = "Found #{colorize(:green, "0 errors")}. Watching for file changes."
        puts "#{colorize(:gray, timestamp)} #{msg}"
      else
        error_word = @error_count == 1 ? "error" : "errors"
        msg = "Found #{colorize(:red, "#{@error_count} #{error_word}")}. Watching for file changes."
        puts "#{colorize(:gray, timestamp)} #{msg}"
      end
    end

    def print_watching_message
      # Just print a blank line for readability
    end

    def timestamp
      Time.now.strftime("[%I:%M:%S %p]")
    end

    def relative_path(file)
      file.sub("#{Dir.pwd}/", "")
    end

    def colorize(color, text)
      return text unless @use_colors
      return text unless COLORS[color]

      "#{COLORS[color]}#{text}#{COLORS[:reset]}"
    end
  end
end
