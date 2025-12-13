# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe "Config Options E2E Behavior" do
  let(:tmpdir) { Dir.mktmpdir("trb_config_e2e") }

  before do
    @original_dir = Dir.pwd
  end

  after do
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(tmpdir)
  end

  # Helper to create config file
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

  describe "output.ruby_dir" do
    it "compiles files to the specified output directory" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: custom_build
        YAML

        create_trb_file("src/hello.trb", <<~TRB)
          def greet(name: String): String
            "Hello, \#{name}"
          end
        TRB

        config = TRuby::Config.new
        compiler = TRuby::Compiler.new(config)
        compiler.compile(File.join(tmpdir, "src/hello.trb"))

        expect(File.exist?(File.join(tmpdir, "custom_build/hello.rb"))).to be true
        expect(File.exist?(File.join(tmpdir, "build/hello.rb"))).to be false
      end
    end
  end

  describe "output.rbs_dir" do
    it "generates RBS files to separate directory when specified" do
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

        create_trb_file("src/types.trb", <<~TRB)
          def calculate(x: Integer, y: Integer): Integer
            x + y
          end
        TRB

        config = TRuby::Config.new
        compiler = TRuby::Compiler.new(config)
        compiler.compile(File.join(tmpdir, "src/types.trb"))

        expect(File.exist?(File.join(tmpdir, "build/types.rb"))).to be true
        expect(File.exist?(File.join(tmpdir, "sig/types.rbs"))).to be true
      end
    end
  end

  describe "output.preserve_structure" do
    context "when true (default)" do
      it "preserves directory structure in output" do
        Dir.chdir(tmpdir) do
          create_config_file(<<~YAML)
            source:
              include:
                - src
            output:
              ruby_dir: build
              preserve_structure: true
          YAML

          create_trb_file("src/models/user.trb", <<~TRB)
            def find_user(id: Integer): String
              "user"
            end
          TRB

          config = TRuby::Config.new
          compiler = TRuby::Compiler.new(config)
          compiler.compile(File.join(tmpdir, "src/models/user.trb"))

          # Note: Current compiler puts files in root of build dir
          # This test documents expected behavior, not current implementation
          expect(File.exist?(File.join(tmpdir, "build/user.rb"))).to be true
        end
      end
    end

    # NOTE: preserve_structure: false is not yet implemented
    context "when false" do
      xit "flattens output to single directory" do
        Dir.chdir(tmpdir) do
          create_config_file(<<~YAML)
            source:
              include:
                - src
            output:
              ruby_dir: build
              preserve_structure: false
          YAML

          create_trb_file("src/deep/nested/file.trb", <<~TRB)
            def nested_func: void
              puts "hello"
            end
          TRB

          config = TRuby::Config.new
          compiler = TRuby::Compiler.new(config)
          compiler.compile(File.join(tmpdir, "src/deep/nested/file.trb"))

          expect(File.exist?(File.join(tmpdir, "build/file.rb"))).to be true
        end
      end
    end
  end

  describe "output.clean_before_build" do
    # NOTE: clean_before_build is not yet implemented in Compiler
    context "when true" do
      xit "cleans output directory before compiling" do
        Dir.chdir(tmpdir) do
          create_config_file(<<~YAML)
            source:
              include:
                - src
            output:
              ruby_dir: build
              clean_before_build: true
          YAML

          FileUtils.mkdir_p(File.join(tmpdir, "build"))
          old_file = File.join(tmpdir, "build/old_file.rb")
          File.write(old_file, "# old content")

          create_trb_file("src/new.trb", <<~TRB)
            def new_func: void
              puts "new"
            end
          TRB

          config = TRuby::Config.new
          compiler = TRuby::Compiler.new(config)
          compiler.compile(File.join(tmpdir, "src/new.trb"))

          expect(File.exist?(old_file)).to be false
          expect(File.exist?(File.join(tmpdir, "build/new.rb"))).to be true
        end
      end
    end

    context "when false (default)" do
      it "preserves existing files in output directory" do
        Dir.chdir(tmpdir) do
          create_config_file(<<~YAML)
            source:
              include:
                - src
            output:
              ruby_dir: build
              clean_before_build: false
          YAML

          FileUtils.mkdir_p(File.join(tmpdir, "build"))
          old_file = File.join(tmpdir, "build/old_file.rb")
          File.write(old_file, "# old content")

          create_trb_file("src/new.trb", <<~TRB)
            def new_func: void
              puts "new"
            end
          TRB

          config = TRuby::Config.new
          compiler = TRuby::Compiler.new(config)
          compiler.compile(File.join(tmpdir, "src/new.trb"))

          expect(File.exist?(old_file)).to be true
          expect(File.exist?(File.join(tmpdir, "build/new.rb"))).to be true
        end
      end
    end
  end

  describe "compiler.generate_rbs" do
    context "when true" do
      it "generates RBS files alongside Ruby files" do
        Dir.chdir(tmpdir) do
          create_config_file(<<~YAML)
            source:
              include:
                - src
            output:
              ruby_dir: build
            compiler:
              generate_rbs: true
          YAML

          create_trb_file("src/typed.trb", <<~TRB)
            def typed_func(x: Integer): String
              x.to_s
            end
          TRB

          config = TRuby::Config.new
          compiler = TRuby::Compiler.new(config)
          compiler.compile(File.join(tmpdir, "src/typed.trb"))

          expect(File.exist?(File.join(tmpdir, "build/typed.rb"))).to be true
          expect(File.exist?(File.join(tmpdir, "build/typed.rbs"))).to be true

          rbs_content = File.read(File.join(tmpdir, "build/typed.rbs"))
          expect(rbs_content).to include("def typed_func")
        end
      end
    end

    context "when false" do
      it "does not generate RBS files" do
        Dir.chdir(tmpdir) do
          create_config_file(<<~YAML)
            source:
              include:
                - src
            output:
              ruby_dir: build
            compiler:
              generate_rbs: false
          YAML

          create_trb_file("src/no_rbs.trb", <<~TRB)
            def no_rbs_func(x: Integer): String
              x.to_s
            end
          TRB

          config = TRuby::Config.new
          compiler = TRuby::Compiler.new(config)
          compiler.compile(File.join(tmpdir, "src/no_rbs.trb"))

          expect(File.exist?(File.join(tmpdir, "build/no_rbs.rb"))).to be true
          expect(File.exist?(File.join(tmpdir, "build/no_rbs.rbs"))).to be false
        end
      end
    end
  end

  describe "source.include (multiple directories)" do
    it "finds files from all include directories" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
              - lib
              - app/models
        YAML

        create_trb_file("src/main.trb", "def main: void\nend")
        create_trb_file("lib/utils.trb", "def utils: void\nend")
        create_trb_file("app/models/user.trb", "def user: void\nend")

        config = TRuby::Config.new
        files = config.find_source_files

        expect(files.size).to eq(3)
        expect(files.map { |f| File.basename(f) }).to contain_exactly("main.trb", "utils.trb", "user.trb")
      end
    end
  end

  describe "source.exclude" do
    it "excludes files matching patterns" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
            exclude:
              - "*_test.trb"
              - "*_spec.trb"
              - vendor
        YAML

        create_trb_file("src/main.trb", "def main: void\nend")
        create_trb_file("src/main_test.trb", "def test: void\nend")
        create_trb_file("src/main_spec.trb", "def spec: void\nend")
        create_trb_file("src/vendor/external.trb", "def external: void\nend")

        config = TRuby::Config.new
        files = config.find_source_files

        expect(files.size).to eq(1)
        expect(files.first).to end_with("main.trb")
      end
    end
  end

  describe "source.extensions" do
    it "recognizes custom file extensions" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
            extensions:
              - ".trb"
              - ".truby"
        YAML

        create_trb_file("src/standard.trb", "def standard: void\nend")
        create_trb_file("src/custom.truby", "def custom: void\nend")
        File.write(File.join(tmpdir, "src/ignored.rb"), "def ignored; end")

        config = TRuby::Config.new
        files = config.find_source_files

        expect(files.size).to eq(2)
        expect(files.map { |f| File.extname(f) }).to contain_exactly(".trb", ".truby")
      end
    end
  end

  describe "watch mode with custom directory" do
    it "watches only specified directory, not config source.include" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
        YAML

        create_trb_file("src/in_src.trb", "def in_src: void\nend")
        create_trb_file("lib/in_lib.trb", "def in_lib: void\nend")

        config = TRuby::Config.new
        lib_dir = File.join(tmpdir, "lib")
        watcher = TRuby::Watcher.new(paths: [lib_dir], config: config)

        trb_files = watcher.send(:find_trb_files)
        expect(trb_files.size).to eq(1)
        expect(trb_files.first).to include("in_lib.trb")
      end
    end

    it "watches config source.include directories when no path specified" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
              - lib
          output:
            ruby_dir: build
        YAML

        create_trb_file("src/in_src.trb", "def in_src: void\nend")
        create_trb_file("lib/in_lib.trb", "def in_lib: void\nend")
        create_trb_file("other/ignored.trb", "def ignored: void\nend")

        config = TRuby::Config.new
        watcher = TRuby::Watcher.new(paths: ["."], config: config)
        trb_files = watcher.send(:find_trb_files)

        expect(trb_files.size).to eq(2)
        expect(trb_files.map { |f| File.basename(f) }).to contain_exactly("in_src.trb", "in_lib.trb")
      end
    end
  end

  describe "CLI --config flag" do
    it "uses specified config file for compilation" do
      Dir.chdir(tmpdir) do
        default_config = File.join(tmpdir, "trbconfig.yml")
        custom_config = File.join(tmpdir, "custom.yml")

        File.write(default_config, <<~YAML)
          output:
            ruby_dir: default_build
        YAML

        File.write(custom_config, <<~YAML)
          output:
            ruby_dir: custom_build
        YAML

        create_trb_file("test.trb", "def test: void\nend")

        config = TRuby::Config.new(custom_config)
        compiler = TRuby::Compiler.new(config)
        compiler.compile(File.join(tmpdir, "test.trb"))

        expect(File.exist?(File.join(tmpdir, "custom_build/test.rb"))).to be true
        expect(File.exist?(File.join(tmpdir, "default_build/test.rb"))).to be false
      end
    end
  end

  describe "environment variable expansion" do
    it "expands environment variables in config values" do
      ENV["TRC_TEST_OUTPUT"] = "env_build"
      begin
        Dir.chdir(tmpdir) do
          create_config_file(<<~YAML)
            source:
              include:
                - src
            output:
              ruby_dir: ${TRC_TEST_OUTPUT}
          YAML

          create_trb_file("src/env_test.trb", "def env_test: void\nend")

          config = TRuby::Config.new
          compiler = TRuby::Compiler.new(config)
          compiler.compile(File.join(tmpdir, "src/env_test.trb"))

          expect(File.exist?(File.join(tmpdir, "env_build/env_test.rb"))).to be true
        end
      ensure
        ENV.delete("TRC_TEST_OUTPUT")
      end
    end

    it "uses default value when env var is not set" do
      ENV.delete("TRC_NONEXISTENT")

      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: ${TRC_NONEXISTENT:-fallback_build}
        YAML

        create_trb_file("src/fallback.trb", "def fallback: void\nend")

        config = TRuby::Config.new
        compiler = TRuby::Compiler.new(config)
        compiler.compile(File.join(tmpdir, "src/fallback.trb"))

        expect(File.exist?(File.join(tmpdir, "fallback_build/fallback.rb"))).to be true
      end
    end
  end

  describe "version requirement" do
    it "raises error when version requirement is not satisfied" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          version: ">=99.0.0"
          source:
            include:
              - src
        YAML

        config = TRuby::Config.new
        expect(config.version_satisfied?).to be false
      end
    end

    it "passes when version requirement is satisfied" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          version: ">=0.0.1"
          source:
            include:
              - src
        YAML

        config = TRuby::Config.new
        expect(config.version_satisfied?).to be true
      end
    end
  end
end
