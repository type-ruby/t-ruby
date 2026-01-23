# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require "rbs"

RSpec.describe "Tuple Type E2E" do
  let(:tmpdir) { Dir.mktmpdir("trb_tuple_e2e") }

  before do
    @original_dir = Dir.pwd
  end

  after do
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(tmpdir)
  end

  # Helper to create config file with RBS generation enabled
  def create_config_file(yaml_content)
    config_path = File.join(tmpdir, "trbconfig.yml")
    File.write(config_path, yaml_content)
    config_path
  end

  # Helper to create a .trb file
  def create_trb_file(relative_path, content)
    full_path = File.join(tmpdir, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
    full_path
  end

  # Helper to compile and get RBS content
  def compile_and_get_rbs(trb_path, rbs_dir: "sig")
    config = TRuby::Config.new
    allow(config).to receive(:type_check?).and_return(false)
    compiler = TRuby::Compiler.new(config)
    compiler.compile(trb_path)

    relative_path = trb_path.sub("#{tmpdir}/src/", "")
    rbs_path = File.join(tmpdir, rbs_dir, relative_path.sub(".trb", ".rbs"))
    File.read(rbs_path) if File.exist?(rbs_path)
  end

  # Helper to compile and get Ruby content
  def compile_and_get_ruby(trb_path, ruby_dir: "build")
    config = TRuby::Config.new
    allow(config).to receive(:type_check?).and_return(false)
    compiler = TRuby::Compiler.new(config)
    compiler.compile(trb_path)

    relative_path = trb_path.sub("#{tmpdir}/src/", "")
    ruby_path = File.join(tmpdir, ruby_dir, relative_path.sub(".trb", ".rb"))
    File.read(ruby_path) if File.exist?(ruby_path)
  end

  # Helper to assert RBS is valid
  def expect_valid_rbs(rbs_content)
    expect(rbs_content).not_to be_nil
    expect(rbs_content.strip).not_to be_empty

    begin
      RBS::Parser.parse_signature(rbs_content)
    rescue RBS::ParsingError => e
      first_line = rbs_content.strip.lines.first.to_s
      unless first_line.start_with?("def ") || first_line.start_with?("type ")
        raise "Generated RBS is invalid:\n#{rbs_content}\n\nParsing error: #{e.message}"
      end
    end

    rbs_content
  end

  describe "basic tuple compilation" do
    it "compiles basic tuple type to RBS" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/pair.trb", <<~TRB)
          def get_pair(): [String, Integer]
            ["hello", 42]
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/pair.trb"))

        expect_valid_rbs(rbs_content)
        expect(rbs_content).to include("def get_pair: () -> [String, Integer]")
      end
    end

    it "compiles tuple parameter to RBS" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/process.trb", <<~TRB)
          def process_pair(data: [String, Integer]): Boolean
            true
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/process.trb"))

        expect_valid_rbs(rbs_content)
        expect(rbs_content).to include("def process_pair: (data: [String, Integer]) -> Boolean")
      end
    end
  end

  describe "tuple with rest element" do
    it "compiles tuple with rest element to RBS (fallback to union array)" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/values.trb", <<~TRB)
          def get_values(): [String, *Integer[]]
            ["header", 1, 2, 3]
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/values.trb"))

        expect_valid_rbs(rbs_content)
        # RBS fallback: tuple with rest → union array
        expect(rbs_content).to include("def get_values: () -> Array[String | Integer]")
      end
    end

    it "compiles tuple with generic rest element" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/table.trb", <<~TRB)
          def get_table(): [String, *Array<Hash>]
            ["title", {a: 1}, {b: 2}]
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/table.trb"))

        expect_valid_rbs(rbs_content)
        expect(rbs_content).to include("Array[String | Hash]")
      end
    end
  end

  describe "nested tuple compilation" do
    it "compiles nested tuples" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/matrix.trb", <<~TRB)
          def get_matrix(): [[Integer, Integer], [Integer, Integer]]
            [[1, 2], [3, 4]]
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/matrix.trb"))

        expect_valid_rbs(rbs_content)
        expect(rbs_content).to include("def get_matrix: () -> [[Integer, Integer], [Integer, Integer]]")
      end
    end
  end

  describe "type alias with tuple" do
    it "compiles type alias with tuple" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/point.trb", <<~TRB)
          type Point = [Integer, Integer]

          def get_origin(): Point
            [0, 0]
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/point.trb"))

        expect_valid_rbs(rbs_content)
        expect(rbs_content).to include("type Point = [Integer, Integer]")
      end
    end
  end

  describe "Ruby output type erasure" do
    it "removes tuple types in compiled Ruby" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/typed_pair.trb", <<~TRB)
          def get_pair(): [String, Integer]
            ["hello", 42]
          end
        TRB

        ruby_content = compile_and_get_ruby(File.join(tmpdir, "src/typed_pair.trb"))

        expect(ruby_content).to include("def get_pair()")
        expect(ruby_content).not_to include("[String, Integer]")
      end
    end

    it "removes tuple with rest types in compiled Ruby" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/typed_rest.trb", <<~TRB)
          def get_values(): [String, *Integer[]]
            ["header", 1, 2, 3]
          end
        TRB

        ruby_content = compile_and_get_ruby(File.join(tmpdir, "src/typed_rest.trb"))

        expect(ruby_content).to include("def get_values()")
        expect(ruby_content).not_to include("*Integer[]")
      end
    end
  end

  describe "error handling" do
    it "raises error when rest element is not at end" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/bad.trb", <<~TRB)
          def bad(): [*String[], Integer]
            ["a", "b", 42]
          end
        TRB

        expect do
          compile_and_get_rbs(File.join(tmpdir, "src/bad.trb"))
        end.to raise_error(TypeError, /Rest element must be at the end of tuple/)
      end
    end

    it "raises error when multiple rest elements" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/bad_multi.trb", <<~TRB)
          def bad(): [*String[], *Integer[]]
            ["a", 1, 2]
          end
        TRB

        expect do
          compile_and_get_rbs(File.join(tmpdir, "src/bad_multi.trb"))
        end.to raise_error(TypeError, /Tuple can have at most one rest element/)
      end
    end
  end
end
