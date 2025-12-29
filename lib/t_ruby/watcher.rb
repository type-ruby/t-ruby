# frozen_string_literal: true

# listen gem is optional - only required for watch mode
# This allows T-Ruby core functionality to work on Ruby 4.0+ where listen/ffi may not be available
begin
  require "listen"
  LISTEN_AVAILABLE = true
rescue LoadError
  LISTEN_AVAILABLE = false
end

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
      @file_diagnostics = {} # Cache diagnostics per file for incremental updates

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
      unless LISTEN_AVAILABLE
        puts colorize(:red, "Error: Watch mode requires the 'listen' gem.")
        puts colorize(:yellow, "The 'listen' gem is not available (possibly due to Ruby 4.0+ ffi compatibility).")
        puts colorize(:dim, "Install with: gem install listen")
        puts colorize(:dim, "Or run without watch mode: trc")
        exit 1
      end

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
      @file_diagnostics = {} # Reset diagnostics cache on full compile

      trb_files = find_trb_files
      rb_files = find_rb_files
      all_files = trb_files + rb_files
      @file_count = all_files.size

      # Use unified compile_with_diagnostics for all files
      # Note: compile_file increments @stats[:total_compilations] internally
      all_files.each do |file|
        result = compile_file(file)
        # Cache diagnostics per file
        @file_diagnostics[file] = result[:diagnostics] || []
      end

      all_diagnostics = @file_diagnostics.values.flatten
      print_errors(all_diagnostics)
      print_summary
    end

    def compile_files_incremental(files)
      compiled_count = 0

      if @incremental
        files.each do |file|
          if @incremental_compiler.needs_compile?(file)
            @stats[:total_compilations] += 1
            result = compile_file_with_ir(file)
            # Update cached diagnostics for this file
            @file_diagnostics[file] = result[:diagnostics] || []
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
            # Add cross-file errors (these are not file-specific)
            @file_diagnostics[:cross_file] ||= []
            @file_diagnostics[:cross_file] << create_diagnostic_from_cross_file_error(e)
          end
        end
      else
        files.each do |file|
          result = compile_file(file)
          # Update cached diagnostics for this file
          @file_diagnostics[file] = result[:diagnostics] || []
          compiled_count += 1
        end
      end

      # Collect all diagnostics from cache (includes unchanged files' errors)
      all_diagnostics = @file_diagnostics.values.flatten

      # Update error count from all cached diagnostics
      @error_count = all_diagnostics.size

      @file_count = compiled_count
      print_errors(all_diagnostics)
      print_summary
      print_watching_message
    end

    def compile_file_with_ir(file)
      # Use unified compile_with_diagnostics from Compiler (same as compile_file)
      # This ensures incremental compile returns the same diagnostics as full compile
      compile_result = @compiler.compile_with_diagnostics(file)

      # Update incremental compiler's file hash to track changes
      @incremental_compiler&.update_file_hash(file)

      {
        file: file,
        diagnostics: compile_result[:diagnostics],
        success: compile_result[:success],
      }
    end

    def compile_file(file)
      # Use unified compile_with_diagnostics from Compiler
      compile_result = @compiler.compile_with_diagnostics(file)

      @error_count += compile_result[:diagnostics].size
      @stats[:total_compilations] += 1

      {
        file: file,
        diagnostics: compile_result[:diagnostics],
        success: compile_result[:success],
      }
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
      source_paths = if @paths == [File.expand_path(".")]
                       @config.source_include.map { |dir| File.expand_path(dir) }
                     else
                       @paths.map { |path| File.expand_path(path) }
                     end

      source_paths.each do |path|
        if File.file?(path)
          # Handle single file path
          files << path if path.end_with?(ext) && !@config.excluded?(path)
        elsif Dir.exist?(path)
          # Handle directory path
          Dir.glob(File.join(path, "**", "*#{ext}")).each do |file|
            files << file unless @config.excluded?(file)
          end
        end
      end

      files.uniq
    end

    # Create a Diagnostic for cross-file check errors
    def create_diagnostic_from_cross_file_error(error)
      file = error[:file]
      source = File.exist?(file) ? File.read(file) : nil
      create_generic_diagnostic(file, error[:message], source)
    end

    # Create a generic Diagnostic for standard errors
    def create_generic_diagnostic(file, message, source = nil)
      line = 1
      col = 1

      # Try to extract line info from error message
      if message =~ /line (\d+)/i
        line = ::Regexp.last_match(1).to_i
      end

      source_line = source&.split("\n")&.at(line - 1)

      Diagnostic.new(
        code: "TR0001",
        message: message,
        file: relative_path(file),
        line: line,
        column: col,
        source_line: source_line
      )
    end

    def print_errors(diagnostics)
      return if diagnostics.empty?

      formatter = DiagnosticFormatter.new(use_colors: @use_colors)
      diagnostics.each do |diagnostic|
        puts
        puts formatter.format(diagnostic)
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
