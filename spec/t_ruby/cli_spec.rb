# frozen_string_literal: true

require "spec_helper"

describe TRuby::CLI do
  describe ".run" do
    it "is a class method that creates an instance and runs it" do
      expect_any_instance_of(TRuby::CLI).to receive(:run)
      TRuby::CLI.run([])
    end
  end

  describe "#initialize" do
    it "initializes with command line arguments" do
      args = ["hello.trb"]
      cli = TRuby::CLI.new(args)
      expect(cli).to be_a(TRuby::CLI)
    end

    it "accepts empty arguments" do
      cli = TRuby::CLI.new([])
      expect(cli).to be_a(TRuby::CLI)
    end
  end

  describe "#run" do
    context "with no arguments" do
      it "displays help text" do
        cli = TRuby::CLI.new([])
        output = capture_stdout { cli.run }

        expect(output).to include("t-ruby compiler")
        expect(output).to include("Usage:")
        expect(output).to include("trc")
      end

      it "includes version in help text" do
        cli = TRuby::CLI.new([])
        output = capture_stdout { cli.run }

        expect(output).to include(TRuby::VERSION)
      end
    end

    context "with --help flag" do
      it "displays help text" do
        cli = TRuby::CLI.new(["--help"])
        output = capture_stdout { cli.run }

        expect(output).to include("Usage:")
        expect(output).to include("trc")
      end

      it "includes examples in help text" do
        cli = TRuby::CLI.new(["--help"])
        output = capture_stdout { cli.run }

        expect(output).to include("Examples:")
      end
    end

    context "with -h flag" do
      it "displays help text" do
        cli = TRuby::CLI.new(["-h"])
        output = capture_stdout { cli.run }

        expect(output).to include("Usage:")
      end
    end

    context "with --version flag" do
      it "displays version number" do
        cli = TRuby::CLI.new(["--version"])
        output = capture_stdout { cli.run }

        expect(output).to include("trc")
        expect(output).to include(TRuby::VERSION)
      end

      it "displays only version without help text" do
        cli = TRuby::CLI.new(["--version"])
        output = capture_stdout { cli.run }

        expect(output).not_to include("Usage:")
      end
    end

    context "with -v flag" do
      it "displays version number" do
        cli = TRuby::CLI.new(["-v"])
        output = capture_stdout { cli.run }

        expect(output).to include(TRuby::VERSION)
      end
    end

    context "with a valid .trb file" do
      it "compiles the file and displays success message" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "test.trb")
          File.write(input_file, "puts 'hello'")

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)

          cli = TRuby::CLI.new([input_file])
          output = capture_stdout { cli.run }

          expect(output).to include("Compiled:")
          expect(output).to include(input_file)
          expect(output).to include(".rb")
        end
      end

      it "creates output file in build directory" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "script.trb")
          File.write(input_file, "def hello; end")

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
          allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
          allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])

          cli = TRuby::CLI.new([input_file])
          capture_stdout { cli.run }

          expected_output = File.join(tmpdir, "script.rb")
          expect(File.exist?(expected_output)).to be true
        end
      end
    end

    context "with a non-existent file" do
      it "displays error message" do
        cli = TRuby::CLI.new(["/nonexistent/file.trb"])

        expect do
          cli.run
        end.to output(/error TR\d+:/).to_stdout.and raise_error(SystemExit)
      end

      it "exits with status 1" do
        cli = TRuby::CLI.new(["/nonexistent/file.trb"])

        expect do
          cli.run
        end.to raise_error(SystemExit) do |exit_error|
          expect(exit_error.status).to eq(1)
        end
      end
    end

    context "with wrong file extension" do
      it "compiles .rb file successfully (copies to build and generates rbs)" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "test.rb")
          File.write(input_file, "puts 'hello'")

          cli = TRuby::CLI.new([input_file])

          expect do
            cli.run
          end.to output(/Compiled: .* -> /).to_stdout
        end
      end

      it "exits with status 1 for wrong extension" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "test.txt")
          File.write(input_file, "puts 'hello'")

          cli = TRuby::CLI.new([input_file])

          expect do
            cli.run
          end.to raise_error(SystemExit) do |exit_error|
            expect(exit_error.status).to eq(1)
          end
        end
      end
    end

    context "with multiple arguments" do
      it "compiles the first argument" do
        Dir.mktmpdir do |tmpdir|
          file1 = File.join(tmpdir, "file1.trb")
          file2 = File.join(tmpdir, "file2.trb")
          File.write(file1, "puts 'first'")
          File.write(file2, "puts 'second'")

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)

          cli = TRuby::CLI.new([file1, file2])
          output = capture_stdout { cli.run }

          expect(output).to include(file1)
          expect(output).not_to include(file2)
        end
      end
    end

    context "with flags and file arguments combined" do
      it "handles version flag even when file is present" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "test.trb")
          File.write(input_file, "puts 'test'")

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)

          cli = TRuby::CLI.new([input_file, "--version"])
          output = capture_stdout { cli.run }

          # CLI checks for --version first, so it displays version instead of compiling
          expect(output).to include(TRuby::VERSION)
        end
      end
    end

    context "error handling" do
      it "catches ArgumentError from compiler" do
        cli = TRuby::CLI.new(["/nonexistent.trb"])

        expect do
          cli.run
        end.to raise_error(SystemExit) do |exit_error|
          expect(exit_error.status).to eq(1)
        end
      end

      it "prints error message to output" do
        cli = TRuby::CLI.new(["/nonexistent.trb"])

        output = capture_stdout do
          cli.run
        rescue SystemExit
          # Suppress exit
        end

        # Uses tsc-style error format
        expect(output).to match(/error TR\d+:/)
        expect(output).to include("Found 1 error")
      end
    end

    context "tsc-style error formatting" do
      it "formats TypeCheckError with file:line:col format" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "type_error.trb")
          File.write(input_file, "def greet(name: String): String\n  name\nend")

          error = TRuby::TypeCheckError.new(
            message: "Type mismatch",
            location: "#{input_file}:3:5",
            expected: "String",
            actual: "Integer"
          )
          allow_any_instance_of(TRuby::Compiler).to receive(:compile).and_raise(error)

          cli = TRuby::CLI.new([input_file])
          output = capture_stdout do
            cli.run
          rescue SystemExit
            # Suppress exit
          end

          # Should include tsc-style format
          expect(output).to include("type_error.trb:3:5")
          expect(output).to match(/error\s+TR2001/)
          expect(output).to include("Type mismatch")
          expect(output).to include("Found 1 error")
        end
      end

      it "formats ParseError with source code snippet" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "parse_error.trb")
          # Use code that will trigger a ParseError - unterminated string
          File.write(input_file, "def foo\n  \"hello\nend")

          cli = TRuby::CLI.new([input_file])
          output = capture_stdout do
            cli.run
          rescue SystemExit
            # Suppress exit
          end

          # Should include file path and error code
          expect(output).to include("parse_error.trb")
          expect(output).to match(/error\s+TR\d+/)
        end
      end

      it "formats ScanError with error marker" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "scan_error.trb")
          File.write(input_file, "puts unterminated_var")

          error = TRuby::Scanner::ScanError.new("Unterminated string", line: 1, column: 6, position: 5)
          allow_any_instance_of(TRuby::Compiler).to receive(:compile).and_raise(error)

          cli = TRuby::CLI.new([input_file])
          output = capture_stdout do
            cli.run
          rescue SystemExit
            # Suppress exit
          end

          expect(output).to include("scan_error.trb:1:6")
          expect(output).to include("Unterminated string")
          # Marker should cover "unterminated_var" (16 chars)
          expect(output).to include("~")
        end
      end

      it "includes Expected/Actual context for type errors" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "context.trb")
          File.write(input_file, "greet(123)")

          error = TRuby::TypeCheckError.new(
            message: "Argument type mismatch",
            location: "#{input_file}:1:7",
            expected: "String",
            actual: "Integer",
            suggestion: "Use .to_s to convert"
          )
          allow_any_instance_of(TRuby::Compiler).to receive(:compile).and_raise(error)

          cli = TRuby::CLI.new([input_file])
          output = capture_stdout do
            cli.run
          rescue SystemExit
            # Suppress exit
          end

          expect(output).to include("Expected:")
          expect(output).to include("String")
          expect(output).to include("Actual:")
          expect(output).to include("Integer")
          expect(output).to include("Suggestion:")
          expect(output).to include("Use .to_s to convert")
        end
      end
    end
  end

  describe "#run with --init flag" do
    it "creates trbconfig.yml, src/, and build/ directories" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          cli = TRuby::CLI.new(["--init"])
          output = capture_stdout { cli.run }

          expect(File.exist?("trbconfig.yml")).to be true
          expect(Dir.exist?("src")).to be true
          expect(Dir.exist?("build")).to be true
          expect(output).to include("Created:")
          expect(output).to include("initialized successfully")
        end
      end
    end

    it "skips existing files and directories" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          # Pre-create the files/dirs
          File.write("trbconfig.yml", "existing: true")
          Dir.mkdir("src")
          Dir.mkdir("build")

          cli = TRuby::CLI.new(["--init"])
          output = capture_stdout { cli.run }

          expect(output).to include("Skipped")
          expect(output).to include("already exists")
          expect(output).to include("Project already initialized")
          # Original content should be preserved
          expect(File.read("trbconfig.yml")).to eq("existing: true")
        end
      end
    end

    it "creates only missing items" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          # Pre-create only src/
          Dir.mkdir("src")

          cli = TRuby::CLI.new(["--init"])
          output = capture_stdout { cli.run }

          expect(output).to include("Created:")
          expect(output).to include("trbconfig.yml")
          expect(output).to include("Skipped")
          expect(output).to include("src/")
        end
      end
    end

    it "creates config file with correct structure" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          cli = TRuby::CLI.new(["--init"])
          capture_stdout { cli.run }

          content = File.read("trbconfig.yml")
          expect(content).to include("source:")
          expect(content).to include("include:")
          expect(content).to include("output:")
          expect(content).to include("ruby_dir:")
          expect(content).to include("compiler:")
          expect(content).to include("strictness:")
          expect(content).to include("watch:")
        end
      end
    end
  end

  describe "#run with update command" do
    it "attempts to update the gem when successful" do
      allow(TRuby::VersionChecker).to receive(:update).and_return(true)

      cli = TRuby::CLI.new(["update"])
      output = capture_stdout { cli.run }

      expect(output).to include("Updating t-ruby")
      expect(output).to include("Successfully updated")
    end

    it "shows error message when update fails" do
      allow(TRuby::VersionChecker).to receive(:update).and_return(false)

      cli = TRuby::CLI.new(["update"])
      output = capture_stdout { cli.run }

      expect(output).to include("Updating t-ruby")
      expect(output).to include("Update failed")
      expect(output).to include("gem install t-ruby")
    end
  end

  describe "#run version check" do
    it "shows new version available message" do
      allow(TRuby::VersionChecker).to receive(:check).and_return({
                                                                   current: "1.0.0",
                                                                   latest: "2.0.0",
                                                                 })

      cli = TRuby::CLI.new(["--version"])
      output = capture_stdout { cli.run }

      expect(output).to include("New version available: 2.0.0")
      expect(output).to include("current: 1.0.0")
      expect(output).to include("Run 'trc update' to update")
    end

    it "shows nothing extra when no update available" do
      allow(TRuby::VersionChecker).to receive(:check).and_return(nil)

      cli = TRuby::CLI.new(["--version"])
      output = capture_stdout { cli.run }

      expect(output).to include("trc #{TRuby::VERSION}")
      expect(output).not_to include("New version available")
    end
  end

  describe "#run with --lsp flag" do
    it "starts the LSP server" do
      lsp_server = instance_double(TRuby::LSPServer)
      allow(TRuby::LSPServer).to receive(:new).and_return(lsp_server)
      allow(lsp_server).to receive(:run)

      cli = TRuby::CLI.new(["--lsp"])
      cli.run

      expect(TRuby::LSPServer).to have_received(:new)
      expect(lsp_server).to have_received(:run)
    end
  end

  describe "#run with run command" do
    it "delegates to t-ruby executable via exec" do
      cli = TRuby::CLI.new(["run", "test.trb"])

      # exec replaces the process, so we need to mock it
      allow(cli).to receive(:exec)

      cli.run

      expect(cli).to have_received(:exec).with(
        a_string_ending_with("bin/t-ruby"),
        "test.trb"
      )
    end

    it "passes additional arguments to t-ruby" do
      cli = TRuby::CLI.new(["run", "script.trb", "arg1", "arg2"])

      allow(cli).to receive(:exec)

      cli.run

      expect(cli).to have_received(:exec).with(
        a_string_ending_with("bin/t-ruby"),
        "script.trb",
        "arg1",
        "arg2"
      )
    end
  end

  describe "#run with --watch flag" do
    it "starts watch mode with default path" do
      watcher = instance_double(TRuby::Watcher)
      allow(TRuby::Watcher).to receive(:new).and_return(watcher)
      allow(watcher).to receive(:watch)

      cli = TRuby::CLI.new(["--watch"])
      cli.run

      expect(TRuby::Watcher).to have_received(:new).with(hash_including(paths: ["."]))
      expect(watcher).to have_received(:watch)
    end

    it "starts watch mode with specified paths" do
      watcher = instance_double(TRuby::Watcher)
      allow(TRuby::Watcher).to receive(:new).and_return(watcher)
      allow(watcher).to receive(:watch)

      cli = TRuby::CLI.new(["--watch", "src/", "lib/"])
      cli.run

      expect(TRuby::Watcher).to have_received(:new).with(hash_including(paths: ["src/", "lib/"]))
    end

    it "works with -w shorthand" do
      watcher = instance_double(TRuby::Watcher)
      allow(TRuby::Watcher).to receive(:new).and_return(watcher)
      allow(watcher).to receive(:watch)

      cli = TRuby::CLI.new(["-w", "app/"])
      cli.run

      expect(TRuby::Watcher).to have_received(:new).with(hash_including(paths: ["app/"]))
    end
  end

  describe "#run with --decl flag" do
    it "generates declaration file" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        File.write(input_file, "def hello: String\n  'world'\nend")

        generator = instance_double(TRuby::DeclarationGenerator)
        allow(TRuby::DeclarationGenerator).to receive(:new).and_return(generator)
        allow(generator).to receive(:generate_file).and_return("#{tmpdir}/test.d.trb")

        cli = TRuby::CLI.new(["--decl", input_file])
        output = capture_stdout { cli.run }

        expect(output).to include("Generated:")
        expect(output).to include(input_file)
        expect(output).to include(".d.trb")
      end
    end

    it "handles errors gracefully" do
      generator = instance_double(TRuby::DeclarationGenerator)
      allow(TRuby::DeclarationGenerator).to receive(:new).and_return(generator)
      allow(generator).to receive(:generate_file).and_raise(ArgumentError, "Invalid file")

      cli = TRuby::CLI.new(["--decl", "/nonexistent.trb"])
      output = capture_stdout do
        cli.run
      rescue SystemExit
        # Expected
      end

      expect(output).to include("Error:")
      expect(output).to include("Invalid file")
    end
  end

  describe "#run with --config flag" do
    it "uses custom config file" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        config_file = File.join(tmpdir, "custom.yml")
        File.write(input_file, "puts 'hello'")
        File.write(config_file, "output:\n  ruby_dir: #{tmpdir}")

        cli = TRuby::CLI.new(["--config", config_file, input_file])
        output = capture_stdout { cli.run }

        expect(output).to include("Compiled:")
      end
    end

    it "uses -c shorthand" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        config_file = File.join(tmpdir, "my.yml")
        File.write(input_file, "puts 'hello'")
        File.write(config_file, "output:\n  ruby_dir: #{tmpdir}")

        cli = TRuby::CLI.new(["-c", config_file, input_file])
        output = capture_stdout { cli.run }

        expect(output).to include("Compiled:")
      end
    end
  end

  describe "private #find_input_file" do
    it "finds file after flags with arguments" do
      cli = TRuby::CLI.new(["--config", "custom.yml", "input.trb"])
      input_file = cli.send(:find_input_file)
      expect(input_file).to eq("input.trb")
    end

    it "finds file after multiple flags" do
      cli = TRuby::CLI.new(["--decl", "decl.trb", "--config", "c.yml", "main.trb"])
      input_file = cli.send(:find_input_file)
      expect(input_file).to eq("main.trb")
    end

    it "skips flags without arguments" do
      cli = TRuby::CLI.new(["--verbose", "file.trb"])
      input_file = cli.send(:find_input_file)
      expect(input_file).to eq("file.trb")
    end

    it "returns nil when no input file found" do
      cli = TRuby::CLI.new(["--config", "custom.yml"])
      input_file = cli.send(:find_input_file)
      expect(input_file).to be_nil
    end
  end

  describe "private #extract_config_path" do
    it "extracts config path from --config flag" do
      cli = TRuby::CLI.new(["--config", "my_config.yml", "file.trb"])
      config_path = cli.send(:extract_config_path)
      expect(config_path).to eq("my_config.yml")
    end

    it "extracts config path from -c flag" do
      cli = TRuby::CLI.new(["-c", "short.yml", "file.trb"])
      config_path = cli.send(:extract_config_path)
      expect(config_path).to eq("short.yml")
    end

    it "returns nil when no config flag present" do
      cli = TRuby::CLI.new(["file.trb"])
      config_path = cli.send(:extract_config_path)
      expect(config_path).to be_nil
    end
  end

  # Helper to capture stdout
  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  # Helper to capture stderr
  def capture_stderr
    old_stderr = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = old_stderr
  end
end
