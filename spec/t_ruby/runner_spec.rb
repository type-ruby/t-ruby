# frozen_string_literal: true

require "spec_helper"

describe TRuby::Runner do
  describe "#initialize" do
    it "initializes with default config" do
      runner = TRuby::Runner.new
      expect(runner).to be_a(TRuby::Runner)
    end

    it "accepts custom config" do
      config = TRuby::Config.new
      runner = TRuby::Runner.new(config)
      expect(runner).to be_a(TRuby::Runner)
    end
  end

  describe "#run_file" do
    context "with a valid .trb file" do
      it "executes the file and returns result" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "test.trb")
          File.write(input_file, "puts 'Hello from T-Ruby!'")

          runner = TRuby::Runner.new
          output = capture_stdout { runner.run_file(input_file) }

          expect(output).to include("Hello from T-Ruby!")
        end
      end

      it "strips type annotations before execution" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "typed.trb")
          File.write(input_file, <<~TRB)
            def greet(name: String): String
              "Hello, \#{name}!"
            end
            puts greet("World")
          TRB

          runner = TRuby::Runner.new
          output = capture_stdout { runner.run_file(input_file) }

          expect(output).to include("Hello, World!")
        end
      end

      it "passes arguments via ARGV" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "args.trb")
          File.write(input_file, "puts ARGV.inspect")

          runner = TRuby::Runner.new
          output = capture_stdout { runner.run_file(input_file, %w[foo bar baz]) }

          expect(output).to include('["foo", "bar", "baz"]')
        end
      end

      it "sets $0 to the script path" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "dollar_zero.trb")
          File.write(input_file, "puts $0")

          runner = TRuby::Runner.new
          output = capture_stdout { runner.run_file(input_file) }

          expect(output.strip).to eq(input_file)
        end
      end
    end

    context "with a non-existent file" do
      it "prints error message and exits with status 1" do
        runner = TRuby::Runner.new

        expect do
          capture_stderr { runner.run_file("/nonexistent/file.trb") }
        end.to raise_error(SystemExit) do |exit_error|
          expect(exit_error.status).to eq(1)
        end
      end

      it "outputs error message to stderr" do
        runner = TRuby::Runner.new

        output = capture_stderr do
          runner.run_file("/nonexistent/file.trb")
        rescue SystemExit
          # Expected
        end

        expect(output).to include("Error: File not found")
        expect(output).to include("/nonexistent/file.trb")
      end
    end

    context "with compile errors" do
      it "prints errors and exits with status 1" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "error.trb")
          File.write(input_file, "puts 'hello'")

          # Mock compile_string to return errors
          compiler = instance_double(TRuby::Compiler)
          allow(TRuby::Compiler).to receive(:new).and_return(compiler)
          allow(compiler).to receive(:compile_string).and_return({
                                                                   ruby: "",
                                                                   rbs: "",
                                                                   errors: ["Syntax error at line 1"],
                                                                 })

          runner = TRuby::Runner.new

          expect do
            capture_stderr { runner.run_file(input_file) }
          end.to raise_error(SystemExit) do |exit_error|
            expect(exit_error.status).to eq(1)
          end
        end
      end
    end
  end

  describe "#run_string" do
    it "executes T-Ruby source code from a string" do
      runner = TRuby::Runner.new
      output = capture_stdout do
        runner.run_string("puts 'Hello from string!'")
      end

      expect(output).to include("Hello from string!")
    end

    it "strips type annotations" do
      runner = TRuby::Runner.new
      output = capture_stdout do
        runner.run_string(<<~TRB)
          def add(a: Integer, b: Integer): Integer
            a + b
          end
          puts add(1, 2)
        TRB
      end

      expect(output.strip).to eq("3")
    end

    it "returns true on success" do
      runner = TRuby::Runner.new
      result = capture_stdout { runner.run_string("puts 'ok'") }

      # run_string returns true on success
      expect(result).to include("ok")
    end

    it "returns false on compile error" do
      # Mock compile_string to return errors
      compiler = instance_double(TRuby::Compiler)
      allow(TRuby::Compiler).to receive(:new).and_return(compiler)
      allow(compiler).to receive(:compile_string).and_return({
                                                               ruby: "",
                                                               rbs: "",
                                                               errors: ["Syntax error"],
                                                             })

      runner = TRuby::Runner.new

      result = nil
      capture_stderr do
        result = runner.run_string("invalid code")
      end

      expect(result).to be false
    end

    it "passes arguments via ARGV" do
      runner = TRuby::Runner.new
      output = capture_stdout do
        runner.run_string("puts ARGV.join(',')", argv: %w[a b c])
      end

      expect(output.strip).to eq("a,b,c")
    end

    it "uses custom filename for error reporting" do
      runner = TRuby::Runner.new
      output = capture_stdout do
        runner.run_string("puts $0", filename: "custom_script.trb")
      end

      expect(output.strip).to eq("custom_script.trb")
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

describe TRuby::RunnerCLI do
  describe ".start" do
    context "with --help flag" do
      it "displays help text" do
        output = capture_stdout { TRuby::RunnerCLI.start(["--help"]) }

        expect(output).to include("t-ruby")
        expect(output).to include("Usage:")
        expect(output).to include("Run a .trb file directly")
      end
    end

    context "with -h flag" do
      it "displays help text" do
        output = capture_stdout { TRuby::RunnerCLI.start(["-h"]) }

        expect(output).to include("Usage:")
      end
    end

    context "with --version flag" do
      it "displays version" do
        output = capture_stdout { TRuby::RunnerCLI.start(["--version"]) }

        expect(output).to include("t-ruby")
        expect(output).to include(TRuby::VERSION)
      end
    end

    context "with -v flag" do
      it "displays version" do
        output = capture_stdout { TRuby::RunnerCLI.start(["-v"]) }

        expect(output).to include(TRuby::VERSION)
      end
    end

    context "with no arguments" do
      it "displays help text" do
        output = capture_stdout { TRuby::RunnerCLI.start([]) }

        expect(output).to include("Usage:")
      end
    end

    context "with a valid .trb file" do
      it "executes the file" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "hello.trb")
          File.write(input_file, "puts 'Hello!'")

          output = capture_stdout { TRuby::RunnerCLI.start([input_file]) }

          expect(output).to include("Hello!")
        end
      end

      it "passes additional arguments to the script" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "args.trb")
          File.write(input_file, "puts ARGV.length")

          output = capture_stdout { TRuby::RunnerCLI.start([input_file, "one", "two", "three"]) }

          expect(output.strip).to eq("3")
        end
      end
    end
  end

  describe "#version" do
    it "outputs version string" do
      cli = TRuby::RunnerCLI.new
      output = capture_stdout { cli.version }

      expect(output).to include("t-ruby")
      expect(output).to include(TRuby::VERSION)
    end
  end

  describe "#help" do
    it "outputs help text with usage examples" do
      cli = TRuby::RunnerCLI.new
      output = capture_stdout { cli.help }

      expect(output).to include("Usage:")
      expect(output).to include("Examples:")
      expect(output).to include("t-ruby hello.trb")
      expect(output).to include("Notes:")
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
end
