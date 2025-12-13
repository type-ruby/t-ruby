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
          config_data = {
            "emit" => {"rb" => true, "rbs" => false, "dtrb" => false},
            "paths" => {"src" => "./src", "out" => tmpdir},
            "strict" => {"rbs_compat" => true, "null_safety" => false, "inference" => "basic"}
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

          compiler = TRuby::Compiler.new(config)
          compiler.compile(input_file)

          expect(File.directory?(output_dir)).to be true
        end
      end

      it "preserves file content during compilation (Milestone 0)" do
        Dir.mktmpdir do |tmpdir|
          input_file = File.join(tmpdir, "script.trb")
          # Write content with string interpolation
          File.write(input_file, 'def greet(person)' + "\n" +
                                 '  puts "Hello, #{person}!"' + "\n" +
                                 'end' + "\n" +
                                 "\n" +
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

        expect {
          compiler.compile("/nonexistent/path/file.trb")
        }.to raise_error(ArgumentError, /File not found/)
      end

      it "raises ArgumentError with descriptive message for missing file" do
        missing_file = "/path/to/missing.trb"
        compiler = TRuby::Compiler.new(config)

        expect {
          compiler.compile(missing_file)
        }.to raise_error(ArgumentError, /#{Regexp.escape(missing_file)}/)
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

          expect {
            compiler.compile(txt_file)
          }.to raise_error(ArgumentError, /Expected .trb or .rb file/)
        end
      end

      it "raises ArgumentError for .rbs extension" do
        Dir.mktmpdir do |tmpdir|
          rbs_file = File.join(tmpdir, "test.rbs")
          File.write(rbs_file, "def foo: () -> void")

          compiler = TRuby::Compiler.new(config)

          expect {
            compiler.compile(rbs_file)
          }.to raise_error(ArgumentError, /Expected .trb or .rb file/)
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
          large_content = "puts 'line'\n" * 10000
          input_file = File.join(tmpdir, "large.trb")
          File.write(input_file, large_content)

          allow_any_instance_of(TRuby::Config).to receive(:out_dir).and_return(tmpdir)

          compiler = TRuby::Compiler.new(config)
          output_path = compiler.compile(input_file)

          expect(File.read(output_path)).to eq(large_content)
        end
      end
    end
  end
end
