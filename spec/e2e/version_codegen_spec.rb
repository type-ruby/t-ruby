# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "Version-specific code generation" do
  let(:tmpdir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  def create_project(config_yaml, source_content)
    # Create config file
    File.write(File.join(tmpdir, "trbconfig.yml"), config_yaml)

    # Create source directory and file
    src_dir = File.join(tmpdir, "src")
    FileUtils.mkdir_p(src_dir)
    File.write(File.join(src_dir, "test.trb"), source_content)

    # Create build directory
    build_dir = File.join(tmpdir, "build")
    FileUtils.mkdir_p(build_dir)

    tmpdir
  end

  def compile_and_read_output(project_dir)
    Dir.chdir(project_dir) do
      config = TRuby::Config.new
      compiler = TRuby::Compiler.new(config)
      output_path = compiler.compile("src/test.trb")
      File.read(output_path)
    end
  end

  describe "Ruby 3.0 target" do
    it "preserves _1 numbered parameters" do
      config = <<~YAML
        compiler:
          target_ruby: "3.0"
        source:
          include:
            - src
      YAML

      source = <<~TRB
        def double_all(items: Array<Integer>): Array<Integer>
          items.map { _1 * 2 }
        end
      TRB

      create_project(config, source)
      output = compile_and_read_output(tmpdir)

      expect(output).to include("{ _1 * 2 }")
      expect(output).not_to include("{ it * 2 }")
    end

    it "preserves named block forwarding" do
      config = <<~YAML
        compiler:
          target_ruby: "3.0"
        source:
          include:
            - src
      YAML

      source = <<~TRB
        def wrapper(&block: Block): void
          inner(&block)
        end
      TRB

      create_project(config, source)
      output = compile_and_read_output(tmpdir)

      expect(output).to include("def wrapper(&block)")
      expect(output).to include("inner(&block)")
    end
  end

  describe "Ruby 3.1+ target" do
    it "converts block forwarding to anonymous syntax" do
      config = <<~YAML
        compiler:
          target_ruby: "3.1"
        source:
          include:
            - src
      YAML

      source = <<~TRB
        def wrapper(&block: Block): void
          inner(&block)
        end
      TRB

      create_project(config, source)
      output = compile_and_read_output(tmpdir)

      expect(output).to include("def wrapper(&)")
      expect(output).to include("inner(&)")
    end

    it "preserves _1 numbered parameters (still valid)" do
      config = <<~YAML
        compiler:
          target_ruby: "3.2"
        source:
          include:
            - src
      YAML

      source = <<~TRB
        def process(items: Array<Integer>): Array<Integer>
          items.map { _1 * 2 }
        end
      TRB

      create_project(config, source)
      output = compile_and_read_output(tmpdir)

      expect(output).to include("{ _1 * 2 }")
    end
  end

  describe "Ruby 3.4+ target" do
    it "preserves _1 syntax (still valid, it is optional)" do
      config = <<~YAML
        compiler:
          target_ruby: "3.4"
        source:
          include:
            - src
      YAML

      source = <<~TRB
        def process(items: Array<Integer>): Array<Integer>
          items.map { _1 * 2 }
        end
      TRB

      create_project(config, source)
      output = compile_and_read_output(tmpdir)

      # Ruby 3.4 supports both _1 and it, so _1 is preserved
      expect(output).to include("{ _1 * 2 }")
    end

    it "uses anonymous block forwarding" do
      config = <<~YAML
        compiler:
          target_ruby: "3.4"
        source:
          include:
            - src
      YAML

      source = <<~TRB
        def wrapper(&block: Block): void
          forward(&block)
        end
      TRB

      create_project(config, source)
      output = compile_and_read_output(tmpdir)

      expect(output).to include("def wrapper(&)")
      expect(output).to include("forward(&)")
    end
  end

  describe "Ruby 4.0 target" do
    it "converts _1 to it (numbered params raise NameError)" do
      config = <<~YAML
        compiler:
          target_ruby: "4.0"
        source:
          include:
            - src
      YAML

      source = <<~TRB
        def double_all(items: Array<Integer>): Array<Integer>
          items.map { _1 * 2 }
        end
      TRB

      create_project(config, source)
      output = compile_and_read_output(tmpdir)

      expect(output).to include("{ it * 2 }")
      expect(output).not_to include("_1")
    end

    it "converts multiple numbered params to explicit params" do
      config = <<~YAML
        compiler:
          target_ruby: "4.0"
        source:
          include:
            - src
      YAML

      source = <<~TRB
        def swap_pairs(hash: Hash<String, Integer>): Array<Array>
          hash.map { [_2, _1] }
        end
      TRB

      create_project(config, source)
      output = compile_and_read_output(tmpdir)

      # Should convert to explicit params like |k, v|
      expect(output).to include("|k, v|")
      expect(output).not_to include("_1")
      expect(output).not_to include("_2")
    end

    it "handles nested blocks with _1" do
      config = <<~YAML
        compiler:
          target_ruby: "4.0"
        source:
          include:
            - src
      YAML

      source = <<~TRB
        def nested(items: Array<Array<Integer>>): Array<Array<Integer>>
          items.map { _1.map { _1 * 2 } }
        end
      TRB

      create_project(config, source)
      output = compile_and_read_output(tmpdir)

      # Both _1 should be converted to it
      expect(output).to include("{ it.map { it * 2 } }")
      expect(output).not_to include("_1")
    end

    it "uses anonymous block forwarding" do
      config = <<~YAML
        compiler:
          target_ruby: "4.0"
        source:
          include:
            - src
      YAML

      source = <<~TRB
        def wrapper(&block: Block): void
          forward(&block)
        end
      TRB

      create_project(config, source)
      output = compile_and_read_output(tmpdir)

      expect(output).to include("def wrapper(&)")
      expect(output).to include("forward(&)")
    end
  end

  describe "auto-detection (no target_ruby specified)" do
    it "uses current Ruby version" do
      config = <<~YAML
        source:
          include:
            - src
      YAML

      source = <<~TRB
        def greet(name: String): String
          "Hello, \#{name}!"
        end
      TRB

      create_project(config, source)

      Dir.chdir(tmpdir) do
        config = TRuby::Config.new
        expected_version = "#{RUBY_VERSION.split(".")[0]}.#{RUBY_VERSION.split(".")[1]}"
        expect(config.target_ruby).to eq(expected_version)
      end
    end
  end

  describe "compile_string with version option" do
    it "respects target_ruby for string compilation" do
      config = <<~YAML
        compiler:
          target_ruby: "4.0"
        source:
          include:
            - src
      YAML

      source = <<~TRB
        def double(items: Array<Integer>): Array<Integer>
          items.map { _1 * 2 }
        end
      TRB

      create_project(config, source)

      Dir.chdir(tmpdir) do
        config = TRuby::Config.new
        compiler = TRuby::Compiler.new(config)
        result = compiler.compile_string(source)

        expect(result[:ruby]).to include("{ it * 2 }")
        expect(result[:ruby]).not_to include("_1")
      end
    end
  end
end
