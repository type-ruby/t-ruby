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

    describe "#format_error" do
      it "returns error hash with file, line, col, and message" do
        error = watcher.send(:format_error, "test.trb", "syntax error")

        expect(error).to include(
          file: "test.trb",
          line: 1,
          col: 1,
          message: "syntax error"
        )
      end

      it "extracts line number from error message if available" do
        error = watcher.send(:format_error, "test.trb", "error on line 42")
        expect(error[:line]).to eq(42)
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
          expect(result[:errors]).to be_empty
        end
      end

      it "returns error result for non-existent file" do
        watcher = TRuby::Watcher.new(paths: ["."])
        result = watcher.send(:compile_file, "/nonexistent/file.trb")

        expect(result[:success]).to be false
        expect(result[:errors]).not_to be_empty
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
end
