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
        end.to output(/Error:/).to_stdout.and raise_error(SystemExit)
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

        expect(output).to include("Error:")
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
          File.write(input_file, "def foo(: String)\n  \"hello\"\nend")

          error = TRuby::ParseError.new("Invalid parameter syntax", line: 1, column: 9)
          allow_any_instance_of(TRuby::Compiler).to receive(:compile).and_raise(error)

          cli = TRuby::CLI.new([input_file])
          output = capture_stdout do
            cli.run
          rescue SystemExit
            # Suppress exit
          end

          expect(output).to include("parse_error.trb:1:9")
          expect(output).to match(/error\s+TR1001/)
          expect(output).to include("|")
          expect(output).to include("def foo(: String)")
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
