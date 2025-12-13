# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tempfile"

describe TRuby::Config do
  # Helper method to create a config with custom YAML
  def create_config(yaml_content)
    Dir.mktmpdir do |tmpdir|
      config_path = File.join(tmpdir, "trbconfig.yml")
      File.write(config_path, yaml_content)
      yield TRuby::Config.new(config_path)
    end
  end

  describe "source.include" do
    it "returns source include directories" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.source_include).to eq(["src"])
        end
      end
    end

    it "returns custom include directories from config" do
      yaml = <<~YAML
        source:
          include:
            - src
            - lib
            - app/models
      YAML

      create_config(yaml) do |config|
        expect(config.source_include).to eq(["src", "lib", "app/models"])
      end
    end

    it "uses source_include in find_source_files" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          FileUtils.mkdir_p("src")
          FileUtils.mkdir_p("lib")
          File.write("src/main.trb", "# main")
          File.write("lib/utils.trb", "# utils")

          File.write("trbconfig.yml", <<~YAML)
            source:
              include:
                - src
                - lib
          YAML

          config = TRuby::Config.new
          files = config.find_source_files

          expect(files.size).to eq(2)
          expect(files.map { |f| File.basename(f) }).to contain_exactly("main.trb", "utils.trb")
        end
      end
    end
  end

  describe "new schema structure" do
    describe "DEFAULT_CONFIG" do
      it "has source section" do
        expect(TRuby::Config::DEFAULT_CONFIG).to have_key("source")
        expect(TRuby::Config::DEFAULT_CONFIG["source"]).to have_key("include")
        expect(TRuby::Config::DEFAULT_CONFIG["source"]).to have_key("exclude")
        expect(TRuby::Config::DEFAULT_CONFIG["source"]).to have_key("extensions")
      end

      it "has output section" do
        expect(TRuby::Config::DEFAULT_CONFIG).to have_key("output")
        expect(TRuby::Config::DEFAULT_CONFIG["output"]).to have_key("ruby_dir")
        expect(TRuby::Config::DEFAULT_CONFIG["output"]).to have_key("rbs_dir")
        expect(TRuby::Config::DEFAULT_CONFIG["output"]).to have_key("preserve_structure")
        expect(TRuby::Config::DEFAULT_CONFIG["output"]).to have_key("clean_before_build")
      end

      it "has compiler section" do
        expect(TRuby::Config::DEFAULT_CONFIG).to have_key("compiler")
        expect(TRuby::Config::DEFAULT_CONFIG["compiler"]).to have_key("strictness")
        expect(TRuby::Config::DEFAULT_CONFIG["compiler"]).to have_key("generate_rbs")
        expect(TRuby::Config::DEFAULT_CONFIG["compiler"]).to have_key("target_ruby")
        expect(TRuby::Config::DEFAULT_CONFIG["compiler"]).to have_key("experimental")
        expect(TRuby::Config::DEFAULT_CONFIG["compiler"]).to have_key("checks")
      end

      it "has watch section" do
        expect(TRuby::Config::DEFAULT_CONFIG).to have_key("watch")
        expect(TRuby::Config::DEFAULT_CONFIG["watch"]).to have_key("paths")
        expect(TRuby::Config::DEFAULT_CONFIG["watch"]).to have_key("debounce")
        expect(TRuby::Config::DEFAULT_CONFIG["watch"]).to have_key("clear_screen")
        expect(TRuby::Config::DEFAULT_CONFIG["watch"]).to have_key("on_success")
      end

      it "is frozen" do
        expect(TRuby::Config::DEFAULT_CONFIG).to be_frozen
      end
    end

    describe "initialization with new schema" do
      it "parses source section" do
        yaml = <<~YAML
          source:
            include:
              - src
              - lib
            exclude:
              - "**/*_test.trb"
            extensions:
              - .trb
              - .truby
        YAML

        create_config(yaml) do |config|
          expect(config.source["include"]).to eq(["src", "lib"])
          expect(config.source["exclude"]).to eq(["**/*_test.trb"])
          expect(config.source["extensions"]).to eq([".trb", ".truby"])
        end
      end

      it "parses output section" do
        yaml = <<~YAML
          output:
            ruby_dir: dist
            rbs_dir: sig
            preserve_structure: false
            clean_before_build: true
        YAML

        create_config(yaml) do |config|
          expect(config.output["ruby_dir"]).to eq("dist")
          expect(config.output["rbs_dir"]).to eq("sig")
          expect(config.output["preserve_structure"]).to eq(false)
          expect(config.output["clean_before_build"]).to eq(true)
        end
      end

      it "parses compiler section" do
        yaml = <<~YAML
          compiler:
            strictness: strict
            generate_rbs: false
            target_ruby: "3.2"
            experimental:
              - pattern_matching_types
            checks:
              no_implicit_any: true
              no_unused_vars: true
              strict_nil: true
        YAML

        create_config(yaml) do |config|
          expect(config.compiler["strictness"]).to eq("strict")
          expect(config.compiler["generate_rbs"]).to eq(false)
          expect(config.compiler["target_ruby"]).to eq("3.2")
          expect(config.compiler["experimental"]).to eq(["pattern_matching_types"])
          expect(config.compiler["checks"]["no_implicit_any"]).to eq(true)
          expect(config.compiler["checks"]["no_unused_vars"]).to eq(true)
          expect(config.compiler["checks"]["strict_nil"]).to eq(true)
        end
      end

      it "parses watch section" do
        yaml = <<~YAML
          watch:
            paths:
              - config
            debounce: 200
            clear_screen: true
            on_success: "bundle exec rspec"
        YAML

        create_config(yaml) do |config|
          expect(config.watch["paths"]).to eq(["config"])
          expect(config.watch["debounce"]).to eq(200)
          expect(config.watch["clear_screen"]).to eq(true)
          expect(config.watch["on_success"]).to eq("bundle exec rspec")
        end
      end
    end

    describe "default values" do
      it "uses default source values when not specified" do
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            config = TRuby::Config.new
            expect(config.source["include"]).to eq(["src"])
            expect(config.source["exclude"]).to eq([])
            expect(config.source["extensions"]).to eq([".trb"])
          end
        end
      end

      it "uses default output values when not specified" do
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            config = TRuby::Config.new
            expect(config.output["ruby_dir"]).to eq("build")
            expect(config.output["rbs_dir"]).to be_nil
            expect(config.output["preserve_structure"]).to eq(true)
            expect(config.output["clean_before_build"]).to eq(false)
          end
        end
      end

      it "uses default compiler values when not specified" do
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            config = TRuby::Config.new
            expect(config.compiler["strictness"]).to eq("standard")
            expect(config.compiler["generate_rbs"]).to eq(true)
            expect(config.compiler["target_ruby"]).to eq("3.0")
            expect(config.compiler["experimental"]).to eq([])
            expect(config.compiler["checks"]["no_implicit_any"]).to eq(false)
            expect(config.compiler["checks"]["no_unused_vars"]).to eq(false)
            expect(config.compiler["checks"]["strict_nil"]).to eq(false)
          end
        end
      end

      it "uses default watch values when not specified" do
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            config = TRuby::Config.new
            expect(config.watch["paths"]).to eq([])
            expect(config.watch["debounce"]).to eq(100)
            expect(config.watch["clear_screen"]).to eq(false)
            expect(config.watch["on_success"]).to be_nil
          end
        end
      end
    end
  end

  describe "legacy schema migration" do
    it "detects legacy emit key and migrates to compiler.generate_rbs" do
      yaml = <<~YAML
        emit:
          rb: true
          rbs: true
          dtrb: false
      YAML

      create_config(yaml) do |config|
        expect(config.compiler["generate_rbs"]).to eq(true)
      end
    end

    it "detects legacy paths key and migrates to output/source" do
      yaml = <<~YAML
        paths:
          src: ./source
          out: ./output
      YAML

      create_config(yaml) do |config|
        expect(config.source["include"]).to include("source")
        expect(config.output["ruby_dir"]).to eq("output")
      end
    end

    it "outputs deprecation warning for legacy config" do
      yaml = <<~YAML
        emit:
          rbs: true
      YAML

      expect {
        create_config(yaml) { |_| }
      }.to output(/DEPRECATED|deprecated|legacy/i).to_stderr
    end
  end

  # Keep backwards compatibility tests for now
  describe "initialization with default config" do
    it "initializes with default configuration when no config file exists" do
      # Use a temporary directory that doesn't have a trbconfig.yml
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new

          expect(config).to be_a(TRuby::Config)
          # New schema accessors
          expect(config.source).to be_a(Hash)
          expect(config.output).to be_a(Hash)
          expect(config.compiler).to be_a(Hash)
        end
      end
    end

    it "has correct default out_dir (backwards compatible)" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.out_dir).to eq("build")
        end
      end
    end

    it "has correct default src_dir (backwards compatible)" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.src_dir).to eq("src")
        end
      end
    end
  end

  describe "initialization with custom config file" do
    it "loads configuration from specified config path (new schema)" do
      Dir.mktmpdir do |tmpdir|
        config_file = File.join(tmpdir, "custom.yml")
        File.write(config_file, <<~YAML)
          source:
            include:
              - source
          output:
            ruby_dir: output
          compiler:
            strictness: strict
            generate_rbs: false
        YAML

        config = TRuby::Config.new(config_file)

        expect(config.source["include"]).to eq(["source"])
        expect(config.output["ruby_dir"]).to eq("output")
        expect(config.compiler["strictness"]).to eq("strict")
        expect(config.compiler["generate_rbs"]).to eq(false)
      end
    end

    it "falls back to default config if specified file doesn't exist" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new("/nonexistent/path/config.yml")

          expect(config.compiler["generate_rbs"]).to eq(true)
          expect(config.out_dir).to eq("build")
        end
      end
    end

    it "loads trbconfig.yml from current directory if it exists" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          File.write("trbconfig.yml", <<~YAML)
            source:
              include:
                - lib
            output:
              ruby_dir: dist
            compiler:
              strictness: strict
          YAML

          config = TRuby::Config.new

          expect(config.source["include"]).to eq(["lib"])
          expect(config.out_dir).to eq("dist")
          expect(config.src_dir).to eq("lib")
          expect(config.compiler["strictness"]).to eq("strict")
        end
      end
    end

    it "prefers explicitly passed config path over trbconfig.yml" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          # Create trbconfig.yml with one config
          File.write("trbconfig.yml", <<~YAML)
            output:
              ruby_dir: default_build
          YAML

          # Create explicit config with different path
          explicit_config = File.join(tmpdir, "explicit.yml")
          File.write(explicit_config, <<~YAML)
            output:
              ruby_dir: explicit_build
          YAML

          config = TRuby::Config.new(explicit_config)

          expect(config.out_dir).to eq("explicit_build")
        end
      end
    end
  end

  describe "attr_reader accessors" do
    it "provides read-only access to source" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect { config.source = {} }.to raise_error(NoMethodError)
        end
      end
    end

    it "provides read-only access to output" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect { config.output = {} }.to raise_error(NoMethodError)
        end
      end
    end

    it "provides read-only access to compiler" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect { config.compiler = {} }.to raise_error(NoMethodError)
        end
      end
    end

    it "provides read-only access to watch" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect { config.watch = {} }.to raise_error(NoMethodError)
        end
      end
    end
  end

  describe "#excluded?" do
    it "excludes .git directory (auto-exclude)" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.excluded?(".git/config")).to be true
          expect(config.excluded?(".git/objects/foo")).to be true
        end
      end
    end

    it "excludes output directory (auto-exclude)" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          File.write("trbconfig.yml", <<~YAML)
            output:
              ruby_dir: dist
          YAML

          config = TRuby::Config.new
          expect(config.excluded?("dist/compiled.rb")).to be true
        end
      end
    end

    it "does not exclude regular source files" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.excluded?("app/models/user.trb")).to be false
          expect(config.excluded?("lib/utils.rb")).to be false
        end
      end
    end
  end

  describe "#find_source_files" do
    it "finds .trb files in src directory" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          FileUtils.mkdir_p("src/models")
          FileUtils.mkdir_p("src/lib")
          File.write("src/main.trb", "# main")
          File.write("src/models/user.trb", "# user")
          File.write("src/lib/utils.trb", "# utils")

          config = TRuby::Config.new
          files = config.find_source_files

          expect(files.size).to eq(3)
          expect(files).to include(File.expand_path("src/main.trb"))
          expect(files).to include(File.expand_path("src/models/user.trb"))
          expect(files).to include(File.expand_path("src/lib/utils.trb"))
        end
      end
    end

    it "excludes files matching exclude patterns" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          FileUtils.mkdir_p("src/node_modules/pkg")
          FileUtils.mkdir_p("src/vendor")
          File.write("src/main.trb", "# main")
          File.write("src/node_modules/pkg/index.trb", "# pkg")
          File.write("src/vendor/lib.trb", "# lib")

          File.write("trbconfig.yml", <<~YAML)
            source:
              exclude:
                - node_modules
                - vendor
          YAML

          config = TRuby::Config.new
          files = config.find_source_files

          expect(files.size).to eq(1)
          expect(files).to include(File.expand_path("src/main.trb"))
        end
      end
    end

    it "returns empty array if src directory does not exist" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          files = config.find_source_files

          expect(files).to eq([])
        end
      end
    end
  end

  describe "AUTO_EXCLUDE constant" do
    it "contains .git" do
      expect(TRuby::Config::AUTO_EXCLUDE).to include(".git")
    end

    it "is frozen to prevent modifications" do
      expect(TRuby::Config::AUTO_EXCLUDE).to be_frozen
    end
  end
end
