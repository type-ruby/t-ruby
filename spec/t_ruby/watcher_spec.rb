# frozen_string_literal: true

require "spec_helper"

describe TRuby::Watcher do
  describe "#initialize" do
    it "initializes with default path" do
      watcher = TRuby::Watcher.new
      expect(watcher).to be_a(TRuby::Watcher)
    end

    it "accepts custom paths" do
      watcher = TRuby::Watcher.new(paths: ["src/", "lib/"])
      expect(watcher).to be_a(TRuby::Watcher)
    end

    it "accepts custom config" do
      config = TRuby::Config.new
      watcher = TRuby::Watcher.new(config: config)
      expect(watcher).to be_a(TRuby::Watcher)
    end
  end

  describe "COLORS constant" do
    it "defines ANSI color codes" do
      expect(TRuby::Watcher::COLORS).to include(:reset, :red, :green, :cyan)
    end
  end

  describe "TypeScript-style output" do
    let(:watcher) { TRuby::Watcher.new }

    describe "#timestamp" do
      it "returns time in [HH:MM:SS AM/PM] format" do
        timestamp = watcher.send(:timestamp)
        expect(timestamp).to match(/\[\d{2}:\d{2}:\d{2} [AP]M\]/)
      end
    end

    describe "#relative_path" do
      it "converts absolute path to relative" do
        absolute_path = "#{Dir.pwd}/src/test.trb"
        relative = watcher.send(:relative_path, absolute_path)
        expect(relative).to eq("src/test.trb")
      end

      it "returns unchanged if not in current directory" do
        other_path = "/other/path/test.trb"
        relative = watcher.send(:relative_path, other_path)
        expect(relative).to eq(other_path)
      end
    end

    describe "#colorize" do
      context "when output is not a TTY" do
        before do
          allow($stdout).to receive(:tty?).and_return(false)
        end

        it "returns plain text without ANSI codes" do
          watcher_no_color = TRuby::Watcher.new
          result = watcher_no_color.send(:colorize, :red, "error")
          expect(result).to eq("error")
          expect(result).not_to include("\e[")
        end
      end
    end

    describe "#create_generic_diagnostic" do
      it "returns Diagnostic with file, line, column, and message" do
        diagnostic = watcher.send(:create_generic_diagnostic, "test.trb", "syntax error")

        expect(diagnostic).to be_a(TRuby::Diagnostic)
        expect(diagnostic.file).to eq("test.trb")
        expect(diagnostic.line).to eq(1)
        expect(diagnostic.column).to eq(1)
        expect(diagnostic.message).to eq("syntax error")
      end

      it "extracts line number from error message if available" do
        diagnostic = watcher.send(:create_generic_diagnostic, "test.trb", "error on line 42")
        expect(diagnostic.line).to eq(42)
      end

      it "includes error code TR0001" do
        diagnostic = watcher.send(:create_generic_diagnostic, "test.trb", "syntax error")
        expect(diagnostic.code).to eq("TR0001")
      end
    end
  end

  describe "file discovery" do
    describe "#find_trb_files" do
      it "finds .trb files in specified directories" do
        Dir.mktmpdir do |tmpdir|
          # Create test files
          File.write(File.join(tmpdir, "test1.trb"), "# test1")
          File.write(File.join(tmpdir, "test2.trb"), "# test2")
          File.write(File.join(tmpdir, "ignore.rb"), "# ignore")

          watcher = TRuby::Watcher.new(paths: [tmpdir])
          files = watcher.send(:find_trb_files)

          expect(files.length).to eq(2)
          expect(files.all? { |f| f.end_with?(".trb") }).to be true
        end
      end

      it "finds .trb files in subdirectories" do
        Dir.mktmpdir do |tmpdir|
          subdir = File.join(tmpdir, "sub")
          FileUtils.mkdir_p(subdir)
          File.write(File.join(subdir, "nested.trb"), "# nested")

          watcher = TRuby::Watcher.new(paths: [tmpdir])
          files = watcher.send(:find_trb_files)

          expect(files.length).to eq(1)
          expect(files.first).to include("nested.trb")
        end
      end

      it "handles single file path" do
        Dir.mktmpdir do |tmpdir|
          file_path = File.join(tmpdir, "single.trb")
          File.write(file_path, "# single")

          watcher = TRuby::Watcher.new(paths: [file_path])
          files = watcher.send(:find_trb_files)

          expect(files).to eq([file_path])
        end
      end
    end
  end

  describe "compilation" do
    describe "#compile_file" do
      it "returns success result for valid file" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "valid.trb")
          File.write(input_file, "def hello: void\n  puts 'hi'\nend")

          config = TRuby::Config.new
          allow(config).to receive(:out_dir).and_return(tmpdir)

          watcher = TRuby::Watcher.new(paths: [tmpdir], config: config)
          result = watcher.send(:compile_file, input_file)

          expect(result[:success]).to be true
          expect(result[:diagnostics]).to be_empty
        end
      end

      it "returns error result for non-existent file" do
        watcher = TRuby::Watcher.new(paths: ["."])
        result = watcher.send(:compile_file, "/nonexistent/file.trb")

        expect(result[:success]).to be false
        expect(result[:diagnostics]).not_to be_empty
      end
    end
  end

  describe "CLI integration" do
    it "help text includes watch option" do
      help = TRuby::CLI::HELP_TEXT
      expect(help).to include("--watch")
      expect(help).to include("-w")
    end

    it "help text includes watch examples" do
      help = TRuby::CLI::HELP_TEXT
      expect(help).to include("trc -w")
      expect(help).to include("Watch")
    end
  end

  describe "initialization options" do
    it "accepts incremental option" do
      watcher = TRuby::Watcher.new(incremental: true)
      expect(watcher.incremental_compiler).not_to be_nil
    end

    it "disables incremental compiler when incremental is false" do
      watcher = TRuby::Watcher.new(incremental: false)
      expect(watcher.incremental_compiler).to be_nil
    end

    it "initializes stats" do
      watcher = TRuby::Watcher.new
      expect(watcher.stats).to include(:total_compilations, :incremental_hits, :total_time)
    end
  end

  describe "#watch_directory" do
    let(:watcher) { TRuby::Watcher.new }

    it "returns directory as-is when path is directory" do
      Dir.mktmpdir do |tmpdir|
        result = watcher.send(:watch_directory, tmpdir)
        expect(result).to eq(tmpdir)
      end
    end

    it "returns dirname when path is file" do
      Dir.mktmpdir do |tmpdir|
        file_path = File.join(tmpdir, "test.trb")
        File.write(file_path, "# test")
        result = watcher.send(:watch_directory, file_path)
        expect(result).to eq(tmpdir)
      end
    end
  end

  describe "#find_rb_files" do
    it "finds .rb files in specified directories" do
      Dir.mktmpdir do |tmpdir|
        File.write(File.join(tmpdir, "test.rb"), "# test")
        File.write(File.join(tmpdir, "test.trb"), "# ignore")

        watcher = TRuby::Watcher.new(paths: [tmpdir])
        files = watcher.send(:find_rb_files)

        expect(files.length).to eq(1)
        expect(files.first).to end_with(".rb")
      end
    end
  end

  describe "#find_source_files_by_extension" do
    it "finds files with specified extension" do
      Dir.mktmpdir do |tmpdir|
        File.write(File.join(tmpdir, "test.trb"), "# trb")
        File.write(File.join(tmpdir, "test.rb"), "# rb")

        watcher = TRuby::Watcher.new(paths: [tmpdir])
        trb_files = watcher.send(:find_source_files_by_extension, ".trb")
        rb_files = watcher.send(:find_source_files_by_extension, ".rb")

        expect(trb_files.length).to eq(1)
        expect(rb_files.length).to eq(1)
      end
    end

    it "returns unique files" do
      Dir.mktmpdir do |tmpdir|
        File.write(File.join(tmpdir, "test.trb"), "# test")

        watcher = TRuby::Watcher.new(paths: [tmpdir, tmpdir])
        files = watcher.send(:find_source_files_by_extension, ".trb")

        expect(files.uniq).to eq(files)
      end
    end
  end

  describe "#compile_file_with_ir" do
    it "compiles file and updates incremental compiler" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        File.write(input_file, "def hello: void\n  puts 'hi'\nend")

        config = TRuby::Config.new
        allow(config).to receive(:out_dir).and_return(tmpdir)

        watcher = TRuby::Watcher.new(paths: [tmpdir], config: config, incremental: true)
        result = watcher.send(:compile_file_with_ir, input_file)

        expect(result).to have_key(:file)
        expect(result).to have_key(:diagnostics)
        expect(result).to have_key(:success)
      end
    end
  end

  describe "#create_diagnostic_from_cross_file_error" do
    let(:watcher) { TRuby::Watcher.new }

    it "creates diagnostic from cross file error" do
      Dir.mktmpdir do |tmpdir|
        file_path = File.join(tmpdir, "test.trb")
        File.write(file_path, "def test: void\nend")

        error = { file: file_path, message: "Undefined type" }
        diagnostic = watcher.send(:create_diagnostic_from_cross_file_error, error)

        expect(diagnostic).to be_a(TRuby::Diagnostic)
        expect(diagnostic.message).to eq("Undefined type")
      end
    end
  end

  describe "statistics" do
    it "tracks total compilations" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        File.write(input_file, "def hello: void\n  puts 'hi'\nend")

        config = TRuby::Config.new
        allow(config).to receive(:out_dir).and_return(tmpdir)

        watcher = TRuby::Watcher.new(paths: [tmpdir], config: config)
        initial_count = watcher.stats[:total_compilations]
        watcher.send(:compile_file, input_file)

        expect(watcher.stats[:total_compilations]).to eq(initial_count + 1)
      end
    end
  end

  describe "#print_errors" do
    let(:watcher) { TRuby::Watcher.new }

    it "does nothing when diagnostics are empty" do
      expect { watcher.send(:print_errors, []) }.not_to output.to_stdout
    end

    it "prints formatted diagnostics when present" do
      diagnostic = TRuby::Diagnostic.new(
        code: "TR0001",
        message: "Test error",
        file: "test.trb",
        line: 1,
        column: 1,
        source_line: "def test"
      )

      output = capture_stdout { watcher.send(:print_errors, [diagnostic]) }
      expect(output).to include("Test error")
    end
  end

  describe "#print_start_message" do
    let(:watcher) { TRuby::Watcher.new }

    it "prints starting message with timestamp" do
      output = capture_stdout { watcher.send(:print_start_message) }
      expect(output).to include("Starting compilation in watch mode")
      expect(output).to match(/\[\d{2}:\d{2}:\d{2} [AP]M\]/)
    end
  end

  describe "#print_file_change_message" do
    let(:watcher) { TRuby::Watcher.new }

    it "prints file change message" do
      output = capture_stdout { watcher.send(:print_file_change_message) }
      expect(output).to include("File change detected")
      expect(output).to include("incremental compilation")
    end
  end

  describe "#print_summary" do
    it "prints zero errors when no errors" do
      watcher = TRuby::Watcher.new
      watcher.instance_variable_set(:@error_count, 0)

      output = capture_stdout { watcher.send(:print_summary) }
      expect(output).to include("0 errors")
    end

    it "prints error count when errors exist" do
      watcher = TRuby::Watcher.new
      watcher.instance_variable_set(:@error_count, 5)

      output = capture_stdout { watcher.send(:print_summary) }
      expect(output).to include("5 errors")
    end

    it "uses singular 'error' for one error" do
      watcher = TRuby::Watcher.new
      watcher.instance_variable_set(:@error_count, 1)

      output = capture_stdout { watcher.send(:print_summary) }
      expect(output).to include("1 error")
    end
  end

  describe "#print_stats" do
    it "prints compilation statistics" do
      watcher = TRuby::Watcher.new
      watcher.stats[:total_compilations] = 10
      watcher.stats[:incremental_hits] = 5
      watcher.stats[:total_time] = 2.5

      output = capture_stdout { watcher.send(:print_stats) }
      expect(output).to include("Watch Mode Statistics")
      expect(output).to include("Total compilations: 10")
      expect(output).to include("Incremental cache hits: 5")
      # hit_rate = incremental_hits / (total_compilations + incremental_hits) = 5 / 15 = 33.3%
      expect(output).to include("33.3%")
      expect(output).to include("2.5s")
    end

    it "handles zero compilations" do
      watcher = TRuby::Watcher.new
      watcher.stats[:total_compilations] = 0
      watcher.stats[:incremental_hits] = 0
      watcher.stats[:total_time] = 0.0

      output = capture_stdout { watcher.send(:print_stats) }
      expect(output).to include("0%")
    end
  end

  describe "#colorize" do
    context "when output is TTY" do
      it "applies ANSI codes" do
        watcher = TRuby::Watcher.new
        watcher.instance_variable_set(:@use_colors, true)

        result = watcher.send(:colorize, :red, "error")
        expect(result).to include("\e[31m")
        expect(result).to include("\e[0m")
      end
    end

    it "returns plain text for unknown color" do
      watcher = TRuby::Watcher.new
      watcher.instance_variable_set(:@use_colors, true)

      result = watcher.send(:colorize, :unknown_color, "text")
      expect(result).to eq("text")
    end
  end

  describe "#watch_directories" do
    it "returns source_include directories when default path" do
      config = TRuby::Config.new
      allow(config).to receive(:source_include).and_return(["src/", "lib/"])

      watcher = TRuby::Watcher.new(paths: ["."], config: config)
      dirs = watcher.send(:watch_directories)

      expect(dirs).to be_an(Array)
    end

    it "returns specific paths when provided" do
      Dir.mktmpdir do |tmpdir|
        watcher = TRuby::Watcher.new(paths: [tmpdir])
        dirs = watcher.send(:watch_directories)

        expect(dirs).to include(tmpdir)
      end
    end
  end

  describe "#handle_changes" do
    it "skips when no relevant files changed" do
      watcher = TRuby::Watcher.new
      expect { watcher.send(:handle_changes, [], [], []) }.not_to output.to_stdout
    end

    it "handles removed files" do
      Dir.mktmpdir do |tmpdir|
        file_path = File.join(tmpdir, "test.trb")

        config = TRuby::Config.new
        allow(config).to receive(:out_dir).and_return(tmpdir)

        watcher = TRuby::Watcher.new(paths: [tmpdir], config: config)
        watcher.instance_variable_set(:@file_diagnostics, {})

        output = capture_stdout { watcher.send(:handle_changes, [], [], [file_path]) }
        expect(output).to include("File removed")
      end
    end
  end

  describe "#compile_all" do
    it "compiles all trb and rb files" do
      Dir.mktmpdir do |tmpdir|
        File.write(File.join(tmpdir, "test.trb"), "def hello: void\nend")

        config = TRuby::Config.new
        allow(config).to receive(:out_dir).and_return(tmpdir)
        allow(config).to receive(:source_include).and_return([tmpdir])
        allow(config).to receive(:excluded?).and_return(false)

        watcher = TRuby::Watcher.new(paths: [tmpdir], config: config)

        capture_stdout { watcher.send(:compile_all) }

        expect(watcher.stats[:total_compilations]).to be >= 1
      end
    end
  end

  describe "#compile_files_incremental" do
    context "with incremental mode" do
      it "skips unchanged files" do
        Dir.mktmpdir do |tmpdir|
          file_path = File.join(tmpdir, "test.trb")
          File.write(file_path, "def hello: void\nend")

          config = TRuby::Config.new
          allow(config).to receive(:out_dir).and_return(tmpdir)

          watcher = TRuby::Watcher.new(paths: [tmpdir], config: config, incremental: true)
          watcher.instance_variable_set(:@file_diagnostics, {})

          # First compile
          capture_stdout { watcher.send(:compile_files_incremental, [file_path]) }

          # Second compile (should skip)
          output = capture_stdout { watcher.send(:compile_files_incremental, [file_path]) }
          expect(output).to include("Skipping unchanged")
        end
      end
    end

    context "without incremental mode" do
      it "compiles all files" do
        Dir.mktmpdir do |tmpdir|
          file_path = File.join(tmpdir, "test.trb")
          File.write(file_path, "def hello: void\nend")

          config = TRuby::Config.new
          allow(config).to receive(:out_dir).and_return(tmpdir)

          watcher = TRuby::Watcher.new(paths: [tmpdir], config: config, incremental: false)
          watcher.instance_variable_set(:@file_diagnostics, {})

          capture_stdout { watcher.send(:compile_files_incremental, [file_path]) }

          expect(watcher.stats[:total_compilations]).to be >= 1
        end
      end
    end
  end

  describe "LISTEN_AVAILABLE constant" do
    it "is defined" do
      expect(defined?(LISTEN_AVAILABLE)).to be_truthy
    end
  end

  describe "parallel processor" do
    it "initializes parallel processor when parallel is true" do
      watcher = TRuby::Watcher.new(parallel: true)
      expect(watcher.instance_variable_get(:@parallel_processor)).not_to be_nil
    end

    it "does not initialize parallel processor when parallel is false" do
      watcher = TRuby::Watcher.new(parallel: false)
      expect(watcher.instance_variable_get(:@parallel_processor)).to be_nil
    end
  end

  describe "cross file checking" do
    it "enables cross file check by default" do
      watcher = TRuby::Watcher.new
      expect(watcher.instance_variable_get(:@cross_file_check)).to be true
    end

    it "can disable cross file check" do
      watcher = TRuby::Watcher.new(cross_file_check: false)
      expect(watcher.instance_variable_get(:@cross_file_check)).to be false
    end
  end

  private

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
