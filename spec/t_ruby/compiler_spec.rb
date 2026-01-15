# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"

describe TRuby::Compiler do
  let(:config) { TRuby::Config.new }

  describe "initialization" do
    it "initializes with a config object" do
      compiler = TRuby::Compiler.new(config)
      expect(compiler).to be_a(TRuby::Compiler)
    end
  end

  describe "#compile" do
    context "with valid .trb file" do
      it "successfully compiles a .trb file" do
        Dir.mktmpdir do |tmpdir|
          # Create a temporary .trb file
          input_file = File.join(tmpdir, "test.trb")
          File.write(input_file, "puts 'Hello, world!'")

          # Create a custom config with output in tmpdir
          {
            "emit" => { "rb" => true, "rbs" => false, "dtrb" => false },
            "paths" => { "src" => "./src", "out" => tmpdir },
            "strict" => { "rbs_compat" => true, "null_safety" => false, "inference" => "basic" },
          }
          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
          allow_any_instance_of(TRuby::Config).to receive(:src_dir).and_return("./src")

          compiler = TRuby::Compiler.new(config)
          output_path = compiler.compile(input_file)

          expect(output_path).to end_with(".rb")
          expect(File.exist?(output_path)).to be true
        end
      end

      it "returns the correct output path" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "hello.trb")
          File.write(input_file, "puts 'test'")

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
          allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
          allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])

          compiler = TRuby::Compiler.new(config)
          output_path = compiler.compile(input_file)

          expect(File.basename(output_path)).to eq("hello.rb")
          expect(output_path).to include(tmpdir)
        end
      end

      it "creates output directory if it doesn't exist" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "test.trb")
          File.write(input_file, "puts 'test'")

          output_dir = File.join(tmpdir, "nested", "build")
          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(output_dir)
          allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(output_dir)
          allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])

          compiler = TRuby::Compiler.new(config)
          compiler.compile(input_file)

          expect(File.directory?(output_dir)).to be true
        end
      end

      it "preserves file content during compilation (Milestone 0)" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "script.trb")
          # Write content with string interpolation
          File.write(input_file, "def greet(person)" + "\n  " \
                                                       'puts "Hello, #{person}!"' + "\n" \
                                                                                    "end" + "\n" \
                                                                                            "\n" \
                                                                                            'greet("world")' + "\n")

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)

          compiler = TRuby::Compiler.new(config)
          output_path = compiler.compile(input_file)

          expected_content = File.read(input_file)
          output_content = File.read(output_path)
          expect(output_content).to eq(expected_content)
        end
      end

      it "handles multiple files in sequence" do
        Dir.mktmpdir do |tmpdir|
          files = ["file1.trb", "file2.trb", "file3.trb"]
          files.each do |filename|
            File.write(File.join(tmpdir, filename), "# content of #{filename}")
          end

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)

          compiler = TRuby::Compiler.new(config)

          files.each do |filename|
            input_path = File.join(tmpdir, filename)
            output_path = compiler.compile(input_path)

            expect(File.exist?(output_path)).to be true
            expect(File.basename(output_path)).to eq(filename.sub(".trb", ".rb"))
          end
        end
      end
    end

    context "with invalid input" do
      it "raises ArgumentError when file doesn't exist" do
        compiler = TRuby::Compiler.new(config)

        expect do
          compiler.compile("/nonexistent/path/file.trb")
        end.to raise_error(ArgumentError, /File not found/)
      end

      it "raises ArgumentError with descriptive message for missing file" do
        missing_file = "/path/to/missing.trb"
        compiler = TRuby::Compiler.new(config)

        expect do
          compiler.compile(missing_file)
        end.to raise_error(ArgumentError, /#{Regexp.escape(missing_file)}/)
      end

      it "compiles .rb files (copies and generates rbs)" do
        Dir.mktmpdir do |tmpdir|
          src_dir = File.join(tmpdir, "src")
          out_dir = File.join(tmpdir, "build")
          FileUtils.mkdir_p(src_dir)

          rb_file = File.join(src_dir, "test.rb")
          File.write(rb_file, "puts 'test'")

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(out_dir)

          compiler = TRuby::Compiler.new(config)
          output_path = compiler.compile(rb_file)

          expect(output_path).to end_with(".rb")
          expect(File.exist?(output_path)).to be true
        end
      end

      it "raises ArgumentError for .txt extension" do
        Dir.mktmpdir do |tmpdir|
          txt_file = File.join(tmpdir, "test.txt")
          File.write(txt_file, "puts 'test'")

          compiler = TRuby::Compiler.new(config)

          expect do
            compiler.compile(txt_file)
          end.to raise_error(ArgumentError, /Expected .trb or .rb file/)
        end
      end

      it "raises ArgumentError for .rbs extension" do
        Dir.mktmpdir do |tmpdir|
          rbs_file = File.join(tmpdir, "test.rbs")
          File.write(rbs_file, "def foo: () -> void")

          compiler = TRuby::Compiler.new(config)

          expect do
            compiler.compile(rbs_file)
          end.to raise_error(ArgumentError, /Expected .trb or .rb file/)
        end
      end
    end

    context "with special characters in filenames" do
      it "handles filenames with underscores" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "my_script.trb")
          File.write(input_file, "puts 'test'")

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)

          compiler = TRuby::Compiler.new(config)
          output_path = compiler.compile(input_file)

          expect(File.basename(output_path)).to eq("my_script.rb")
        end
      end

      it "handles filenames with hyphens" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "my-script.trb")
          File.write(input_file, "puts 'test'")

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)

          compiler = TRuby::Compiler.new(config)
          output_path = compiler.compile(input_file)

          expect(File.basename(output_path)).to eq("my-script.rb")
        end
      end

      it "handles filenames with numbers" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "script123.trb")
          File.write(input_file, "puts 'test'")

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)

          compiler = TRuby::Compiler.new(config)
          output_path = compiler.compile(input_file)

          expect(File.basename(output_path)).to eq("script123.rb")
        end
      end
    end

    context "with empty files" do
      it "handles empty .trb files" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "empty.trb")
          File.write(input_file, "")

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)

          compiler = TRuby::Compiler.new(config)
          output_path = compiler.compile(input_file)

          expect(File.read(output_path)).to eq("")
        end
      end
    end

    context "with large files" do
      it "handles larger .trb files" do
        Dir.mktmpdir do |tmpdir|
          large_content = "puts 'line'\n" * 10_000
          input_file = File.join(tmpdir, "large.trb")
          File.write(input_file, large_content)

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)

          compiler = TRuby::Compiler.new(config)
          output_path = compiler.compile(input_file)

          expect(File.read(output_path)).to eq(large_content)
        end
      end
    end

    context "with return type validation" do
      it "raises TypeCheckError when return type mismatches declaration" do
        Dir.mktmpdir do |tmpdir|
          # Method declares Boolean but returns nil
          input_file = File.join(tmpdir, "type_mismatch.trb")
          File.write(input_file, <<~RUBY)
            def test(name: String): Boolean
              return
            end
          RUBY

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
          allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
          allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])
          allow_any_instance_of(TRuby::Config).to receive(:compiler).and_return({ "generate_rbs" => false })
          allow_any_instance_of(TRuby::Config).to receive(:type_check?).and_return(true)

          compiler = TRuby::Compiler.new(config)

          expect do
            compiler.compile(input_file)
          end.to raise_error(TRuby::TypeCheckError)
        end
      end

      it "raises TypeCheckError when inferred type doesn't match declared type" do
        Dir.mktmpdir do |tmpdir|
          # Method declares Integer but returns String
          input_file = File.join(tmpdir, "type_mismatch2.trb")
          File.write(input_file, <<~RUBY)
            def get_value(): Integer
              "hello"
            end
          RUBY

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
          allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
          allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])
          allow_any_instance_of(TRuby::Config).to receive(:compiler).and_return({ "generate_rbs" => false })
          allow_any_instance_of(TRuby::Config).to receive(:type_check?).and_return(true)

          compiler = TRuby::Compiler.new(config)

          error = nil
          begin
            compiler.compile(input_file)
          rescue TRuby::TypeCheckError => e
            error = e
          end

          expect(error).to be_a(TRuby::TypeCheckError)
          expect(error.message).to include("Integer")
          expect(error.message).to include("String")
        end
      end

      it "passes when return type matches declaration" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "type_match.trb")
          File.write(input_file, <<~RUBY)
            def greet(name: String): String
              "Hello, " + name
            end
          RUBY

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
          allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
          allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])
          allow_any_instance_of(TRuby::Config).to receive(:compiler).and_return({ "generate_rbs" => false })
          allow_any_instance_of(TRuby::Config).to receive(:type_check?).and_return(true)

          compiler = TRuby::Compiler.new(config)

          expect do
            compiler.compile(input_file)
          end.not_to raise_error
        end
      end

      it "skips type check when type_check config is false" do
        Dir.mktmpdir do |tmpdir|
          # Type mismatch but type_check is disabled in config
          input_file = File.join(tmpdir, "skip_check.trb")
          File.write(input_file, <<~RUBY)
            def test(): Boolean
              return
            end
          RUBY

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
          allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
          allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])
          allow_any_instance_of(TRuby::Config).to receive(:compiler).and_return({ "generate_rbs" => false })
          allow_any_instance_of(TRuby::Config).to receive(:type_check?).and_return(false)

          compiler = TRuby::Compiler.new(config)

          expect do
            compiler.compile(input_file)
          end.not_to raise_error
        end
      end

      it "validates class methods" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "class_method.trb")
          File.write(input_file, <<~RUBY)
            class Calculator
              def add(a: Integer, b: Integer): Integer
                "not a number"
              end
            end
          RUBY

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
          allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
          allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])
          allow_any_instance_of(TRuby::Config).to receive(:compiler).and_return({ "generate_rbs" => false })
          allow_any_instance_of(TRuby::Config).to receive(:type_check?).and_return(true)

          compiler = TRuby::Compiler.new(config)

          expect do
            compiler.compile(input_file)
          end.to raise_error(TRuby::TypeCheckError)
        end
      end
    end

    context "with directory structure preservation" do
      it "preserves directory structure with single source_include" do
        Dir.mktmpdir do |tmpdir|
          # Create nested source directory
          src_dir = File.join(tmpdir, "src")
          nested_dir = File.join(src_dir, "models", "user")
          FileUtils.mkdir_p(nested_dir)

          input_file = File.join(nested_dir, "account.trb")
          File.write(input_file, "puts 'account'")

          out_dir = File.join(tmpdir, "build")

          allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(out_dir)
          allow_any_instance_of(TRuby::Config).to receive(:rbs_dir).and_return(out_dir)
          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(out_dir)
          allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([src_dir])
          allow_any_instance_of(TRuby::Config).to receive(:compiler).and_return({ "generate_rbs" => false })

          compiler = TRuby::Compiler.new(config)
          output_path = compiler.compile(input_file)

          # Single source_include: exclude source dir name
          # src/models/user/account.trb → build/models/user/account.rb
          expected_path = File.join(out_dir, "models", "user", "account.rb")
          expect(output_path).to eq(expected_path)
          expect(File.exist?(output_path)).to be true
        end
      end

      it "preserves relative path for files outside source directories" do
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            # Create source directory and a file outside it
            src_dir = File.join(tmpdir, "src")
            FileUtils.mkdir_p(src_dir)

            external_dir = File.join(tmpdir, "external")
            FileUtils.mkdir_p(external_dir)

            input_file = File.join(external_dir, "external.trb")
            File.write(input_file, "puts 'external'")

            out_dir = File.join(tmpdir, "build")

            allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(out_dir)
            allow_any_instance_of(TRuby::Config).to receive(:rbs_dir).and_return(out_dir)
            allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(out_dir)
            allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([src_dir])
            allow_any_instance_of(TRuby::Config).to receive(:compiler).and_return({ "generate_rbs" => false })

            compiler = TRuby::Compiler.new(config)
            output_path = compiler.compile(input_file)

            # File outside source directories: preserve relative path from cwd
            # external/external.trb → build/external/external.rb
            expected_path = File.join(out_dir, "external", "external.rb")
            expect(output_path).to eq(expected_path)
            expect(File.exist?(output_path)).to be true
          end
        end
      end

      it "preserves structure for .rb files when copying" do
        Dir.mktmpdir do |tmpdir|
          # Create nested source directory
          src_dir = File.join(tmpdir, "src")
          nested_dir = File.join(src_dir, "lib", "utils")
          FileUtils.mkdir_p(nested_dir)

          input_file = File.join(nested_dir, "helper.rb")
          File.write(input_file, "puts 'helper'")

          out_dir = File.join(tmpdir, "build")

          allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(out_dir)
          allow_any_instance_of(TRuby::Config).to receive(:rbs_dir).and_return(out_dir)
          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(out_dir)
          allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([src_dir])
          allow_any_instance_of(TRuby::Config).to receive(:compiler).and_return({ "generate_rbs" => false })

          compiler = TRuby::Compiler.new(config)
          output_path = compiler.compile(input_file)

          # Should preserve the nested structure
          expected_path = File.join(out_dir, "lib", "utils", "helper.rb")
          expect(output_path).to eq(expected_path)
          expect(File.exist?(output_path)).to be true
        end
      end

      it "generates RBS files with preserved structure" do
        Dir.mktmpdir do |tmpdir|
          # Create nested source directory
          src_dir = File.join(tmpdir, "src")
          nested_dir = File.join(src_dir, "services")
          FileUtils.mkdir_p(nested_dir)

          input_file = File.join(nested_dir, "auth.trb")
          File.write(input_file, "def login(user: String): Boolean\n  true\nend")

          out_dir = File.join(tmpdir, "build")
          rbs_dir = File.join(tmpdir, "sig")

          allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(out_dir)
          allow_any_instance_of(TRuby::Config).to receive(:rbs_dir).and_return(rbs_dir)
          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(out_dir)
          allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([src_dir])
          allow_any_instance_of(TRuby::Config).to receive(:compiler).and_return({ "generate_rbs" => true })
          allow_any_instance_of(TRuby::Config).to receive(:type_check?).and_return(false)

          compiler = TRuby::Compiler.new(config)
          compiler.compile(input_file)

          # Check RBS file is in the right place
          expected_rbs_path = File.join(rbs_dir, "services", "auth.rbs")
          expect(File.exist?(expected_rbs_path)).to be true
        end
      end

      it "includes source dir name with multiple source_include directories" do
        Dir.mktmpdir do |tmpdir|
          # Create two source directories
          src1 = File.join(tmpdir, "app")
          src2 = File.join(tmpdir, "lib")
          FileUtils.mkdir_p(File.join(src1, "models"))
          FileUtils.mkdir_p(File.join(src2, "utils"))

          input_file1 = File.join(src1, "models", "user.trb")
          input_file2 = File.join(src2, "utils", "helper.trb")
          File.write(input_file1, "puts 'user'")
          File.write(input_file2, "puts 'helper'")

          out_dir = File.join(tmpdir, "build")

          allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(out_dir)
          allow_any_instance_of(TRuby::Config).to receive(:rbs_dir).and_return(out_dir)
          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(out_dir)
          allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([src1, src2])
          allow_any_instance_of(TRuby::Config).to receive(:compiler).and_return({ "generate_rbs" => false })

          compiler = TRuby::Compiler.new(config)

          output1 = compiler.compile(input_file1)
          output2 = compiler.compile(input_file2)

          # Multiple source_include: include source dir name
          # app/models/user.trb → build/app/models/user.rb
          # lib/utils/helper.trb → build/lib/utils/helper.rb
          expect(output1).to eq(File.join(out_dir, "app", "models", "user.rb"))
          expect(output2).to eq(File.join(out_dir, "lib", "utils", "helper.rb"))
        end
      end

      it "handles file in current directory" do
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            input_file = File.join(tmpdir, "hello.trb")
            File.write(input_file, "puts 'hello'")

            out_dir = File.join(tmpdir, "build")
            src_dir = File.join(tmpdir, "src")

            allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(out_dir)
            allow_any_instance_of(TRuby::Config).to receive(:rbs_dir).and_return(out_dir)
            allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(out_dir)
            allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([src_dir])
            allow_any_instance_of(TRuby::Config).to receive(:compiler).and_return({ "generate_rbs" => false })

            compiler = TRuby::Compiler.new(config)
            output_path = compiler.compile(input_file)

            # File in cwd: hello.trb → build/hello.rb
            expected_path = File.join(out_dir, "hello.rb")
            expect(output_path).to eq(expected_path)
            expect(File.exist?(output_path)).to be true
          end
        end
      end
    end
  end

  describe "#compile_with_diagnostics" do
    it "returns success result for valid code" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "valid.trb")
        File.write(input_file, <<~TRB)
          def greet(name: String): String
            "Hello, \#{name}!"
          end
        TRB

        allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:rbs_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])

        compiler = TRuby::Compiler.new(config)
        result = compiler.compile_with_diagnostics(input_file)

        expect(result[:success]).to be true
        expect(result[:diagnostics]).to be_empty
      end
    end

    it "returns diagnostics for colon spacing errors" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "invalid.trb")
        # Space before colon is invalid
        File.write(input_file, <<~TRB)
          def broken() : String
            "test"
          end
        TRB

        allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:rbs_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])

        compiler = TRuby::Compiler.new(config)
        result = compiler.compile_with_diagnostics(input_file)

        expect(result[:success]).to be false
        expect(result[:diagnostics]).not_to be_empty
        expect(result[:diagnostics].first).to be_a(TRuby::Diagnostic)
        expect(result[:diagnostics].first.code).to eq("TR1003")
      end
    end

    it "returns diagnostics for file not found" do
      Dir.mktmpdir do |tmpdir|
        nonexistent_file = File.join(tmpdir, "does_not_exist.trb")

        allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])

        compiler = TRuby::Compiler.new(config)
        result = compiler.compile_with_diagnostics(nonexistent_file)

        expect(result[:success]).to be false
        expect(result[:diagnostics]).not_to be_empty
        expect(result[:diagnostics].first.message).to include("not found")
      end
    end

    it "returns diagnostics for invalid extension" do
      Dir.mktmpdir do |tmpdir|
        invalid_file = File.join(tmpdir, "test.txt")
        File.write(invalid_file, "puts 'hello'")

        allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])

        compiler = TRuby::Compiler.new(config)
        result = compiler.compile_with_diagnostics(invalid_file)

        expect(result[:success]).to be false
        expect(result[:diagnostics]).not_to be_empty
        expect(result[:diagnostics].first.message).to include("Expected .trb or .rb")
      end
    end

    it "returns diagnostics for type check errors" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "type_error.trb")
        File.write(input_file, <<~TRB)
          def get_number(): Integer
            "not a number"
          end
        TRB

        allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:rbs_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])
        allow_any_instance_of(TRuby::Config).to receive(:type_check?).and_return(true)

        compiler = TRuby::Compiler.new(config)
        result = compiler.compile_with_diagnostics(input_file)

        expect(result[:success]).to be false
        expect(result[:diagnostics]).not_to be_empty
      end
    end

    it "returns multiple diagnostics when there are multiple errors" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "multi_error.trb")
        File.write(input_file, <<~TRB)
          def error1() : String
            "test"
          end

          def error2():String
            "test"
          end
        TRB

        allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:rbs_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])

        compiler = TRuby::Compiler.new(config)
        result = compiler.compile_with_diagnostics(input_file)

        expect(result[:success]).to be false
        expect(result[:diagnostics].length).to be >= 2
      end
    end
  end

  describe "yield compilation" do
    it "compiles method with yield without arguments to Ruby" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        File.write(input_file, <<~TRB)
          def each_twice
            yield
            yield
          end
        TRB

        allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])

        compiler = TRuby::Compiler.new(config)
        output_path = compiler.compile(input_file)

        output_content = File.read(output_path)
        expect(output_content).to include("def each_twice")
        expect(output_content).to include("yield")
        expect(output_content.scan("yield").length).to eq(2)
      end
    end

    it "compiles yield with single argument" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        File.write(input_file, <<~TRB)
          def map_values
            yield(1)
            yield(2)
          end
        TRB

        allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])

        compiler = TRuby::Compiler.new(config)
        output_path = compiler.compile(input_file)

        output_content = File.read(output_path)
        expect(output_content).to include("yield(1)")
        expect(output_content).to include("yield(2)")
      end
    end

    it "compiles yield with multiple arguments" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        File.write(input_file, <<~TRB)
          def each_with_index
            yield(item, 0)
          end
        TRB

        allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:ruby_dir).and_return(tmpdir)
        allow_any_instance_of(TRuby::Config).to receive(:source_include).and_return([tmpdir])

        compiler = TRuby::Compiler.new(config)
        output_path = compiler.compile(input_file)

        output_content = File.read(output_path)
        expect(output_content).to include("yield(item, 0)")
      end
    end
  end
end
