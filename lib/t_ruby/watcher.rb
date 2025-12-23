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
      gray: "\e[90m",
    }.freeze

    attr_reader :incremental_compiler, :stats

    def initialize(paths: ["."], config: nil, incremental: true, cross_file_check: true, parallel: true)
      @paths = paths.map { |p| File.expand_path(p) }
      @config = config || Config.new
      @compiler = Compiler.new(@config)
      @error_count = 0
      @file_count = 0
      @use_colors = $stdout.tty?

      # Enhanced features
      @incremental = incremental
      @cross_file_check = cross_file_check
      @parallel = parallel

      # Initialize incremental compiler
      if @incremental
        @incremental_compiler = EnhancedIncrementalCompiler.new(
          @compiler,
          enable_cross_file: @cross_file_check
        )
      end

      # Parallel processor
      @parallel_processor = ParallelProcessor.new if @parallel

      # Statistics
      @stats = {
        total_compilations: 0,
        incremental_hits: 0,
        total_time: 0.0,
      }
    end

    def watch
      print_start_message

      # Initial compilation
      start_time = Time.now
      compile_all
      @stats[:total_time] += Time.now - start_time

      # Start watching (.trb and .rb files)
      listener = Listen.to(*watch_directories, only: /\.(trb|rb)$/) do |modified, added, removed|
        handle_changes(modified, added, removed)
      end

      listener.start

      print_watching_message

      # Keep the process running
      begin
        sleep
      rescue Interrupt
        puts "\n#{colorize(:dim, timestamp)} #{colorize(:cyan, "Stopping watch mode...")}"
        print_stats if @incremental
        listener.stop
      end
    end

    private

    def watch_directory(path)
      File.directory?(path) ? path : File.dirname(path)
    end

    def watch_directories
      if @paths == [File.expand_path(".")]
        # Default case: only watch source_include directories from config
        @config.source_include.map { |dir| File.expand_path(dir) }.select { |dir| Dir.exist?(dir) }
      else
        # Specific paths provided: watch those paths
        @paths.map { |path| watch_directory(path) }.uniq
      end
    end

    def handle_changes(modified, added, removed)
      changed_files = (modified + added)
                      .select { |f| f.end_with?(".trb") || f.end_with?(".rb") }
                      .reject { |f| @config.excluded?(f) }
      return if changed_files.empty? && removed.empty?

      puts
      print_file_change_message

      if removed.any?
        removed.each do |file|
          puts "#{colorize(:gray, timestamp)} #{colorize(:yellow, "File removed:")} #{relative_path(file)}"
          # Clear from incremental compiler cache
          @incremental_compiler&.file_hashes&.delete(file)
        end
      end

      if changed_files.any?
        start_time = Time.now
        compile_files_incremental(changed_files)
        @stats[:total_time] += Time.now - start_time
      else
        print_watching_message
      end
    end

    def compile_all
      @error_count = 0
      @file_count = 0
      errors = []

      trb_files = find_trb_files
      rb_files = find_rb_files
      all_files = trb_files + rb_files
      @file_count = all_files.size

      if @incremental && @cross_file_check
        # Use enhanced incremental compiler with cross-file checking
        result = @incremental_compiler.compile_all_with_checking(trb_files)
        errors = result[:errors].map { |e| format_error(e[:file], e[:error] || e[:message]) }
        @error_count = errors.size
        @stats[:total_compilations] += trb_files.size

        # Also compile .rb files
        rb_files.each do |file|
          result = compile_file(file)
          errors.concat(result[:errors]) if result[:errors].any?
        end
      elsif @parallel && all_files.size > 1
        # Parallel compilation
        results = @parallel_processor.process_files(all_files) do |file|
          compile_file(file)
        end
        results.each do |result|
          errors.concat(result[:errors]) if result[:errors]&.any?
        end
      else
        # Sequential compilation
        all_files.each do |file|
          result = compile_file(file)
          errors.concat(result[:errors]) if result[:errors].any?
        end
      end

      print_errors(errors)
      print_summary
    end

    def compile_files_incremental(files)
      @error_count = 0
      errors = []
      compiled_count = 0

      if @incremental
        files.each do |file|
          if @incremental_compiler.needs_compile?(file)
            @stats[:total_compilations] += 1
            result = compile_file_with_ir(file)
            errors.concat(result[:errors]) if result[:errors].any?
            compiled_count += 1
          else
            @stats[:incremental_hits] += 1
            puts "#{colorize(:gray, timestamp)} #{colorize(:dim, "Skipping unchanged:")} #{relative_path(file)}"
          end
        end

        # Run cross-file check if enabled
        if @cross_file_check && @incremental_compiler.cross_file_checker
          check_result = @incremental_compiler.cross_file_checker.check_all
          check_result[:errors].each do |e|
            errors << format_error(e[:file], e[:message])
          end
        end
      else
        files.each do |file|
          result = compile_file(file)
          errors.concat(result[:errors]) if result[:errors].any?
          compiled_count += 1
        end
      end

      @file_count = compiled_count
      print_errors(errors)
      print_summary
      print_watching_message
    end

    def compile_file_with_ir(file)
      result = { file: file, errors: [], success: false }

      begin
        @incremental_compiler.compile_with_ir(file)
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

    def compile_file(file)
      result = { file: file, errors: [], success: false }

      begin
        @compiler.compile(file)
        result[:success] = true
        @stats[:total_compilations] += 1
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
      find_source_files_by_extension(".trb")
    end

    def find_rb_files
      find_source_files_by_extension(".rb")
    end

    def find_source_files_by_extension(ext)
      files = []

      # Always search in source_include directories only
      source_dirs = if @paths == [File.expand_path(".")]
                      @config.source_include.map { |dir| File.expand_path(dir) }
                    else
                      @paths.map { |path| File.expand_path(path) }
                    end

      source_dirs.each do |dir|
        next unless Dir.exist?(dir)

        Dir.glob(File.join(dir, "**", "*#{ext}")).each do |file|
          files << file unless @config.excluded?(file)
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
        message: message,
      }
    end

    def print_errors(errors)
      errors.each do |error|
        puts
        # TypeScript-style error format: file:line:col - error TSXXXX: message
        location = "#{colorize(:cyan,
                               relative_path(error[:file]))}:#{colorize(:yellow,
                                                                        error[:line])}:#{colorize(:yellow,
                                                                                                  error[:col])}"
        puts "#{location} - #{colorize(:red, "error")} #{colorize(:gray, "TRB0001")}: #{error[:message]}"
      end
    end

    def print_start_message
      puts "#{colorize(:gray, timestamp)} #{colorize(:bold, "Starting compilation in watch mode...")}"
      puts
    end

    def print_file_change_message
      puts "#{colorize(:gray,
                       timestamp)} #{colorize(:bold, "File change detected. Starting incremental compilation...")}"
      puts
    end

    def print_summary
      puts
      if @error_count.zero?
        msg = "Found #{colorize(:green, "0 errors")}. Watching for file changes."
      else
        error_word = @error_count == 1 ? "error" : "errors"
        msg = "Found #{colorize(:red, "#{@error_count} #{error_word}")}. Watching for file changes."
      end
      puts "#{colorize(:gray, timestamp)} #{msg}"
    end

    def print_watching_message
      # Just print a blank line for readability
    end

    def print_stats
      puts
      puts "#{colorize(:gray, timestamp)} #{colorize(:bold, "Watch Mode Statistics:")}"
      puts "  Total compilations: #{@stats[:total_compilations]}"
      puts "  Incremental cache hits: #{@stats[:incremental_hits]}"
      total = @stats[:total_compilations] + @stats[:incremental_hits]
      hit_rate = if total.positive?
                   (@stats[:incremental_hits].to_f / total * 100).round(1)
                 else
                   0
                 end
      puts "  Cache hit rate: #{hit_rate}%"
      puts "  Total compile time: #{@stats[:total_time].round(2)}s"
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
