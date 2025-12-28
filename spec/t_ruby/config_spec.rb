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

  describe "compiler.strictness" do
    it "returns 'standard' by default" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.strictness).to eq("standard")
        end
      end
    end

    it "returns 'strict' when set" do
      yaml = <<~YAML
        compiler:
          strictness: strict
      YAML

      create_config(yaml) do |config|
        expect(config.strictness).to eq("strict")
      end
    end

    it "returns 'permissive' when set" do
      yaml = <<~YAML
        compiler:
          strictness: permissive
      YAML

      create_config(yaml) do |config|
        expect(config.strictness).to eq("permissive")
      end
    end

    it "validates strictness value" do
      yaml = <<~YAML
        compiler:
          strictness: invalid
      YAML

      expect do
        create_config(yaml, &:validate!)
      end.to raise_error(TRuby::ConfigError)
    end
  end

  describe "compiler.generate_rbs" do
    it "returns true by default" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.generate_rbs?).to be true
        end
      end
    end

    it "returns false when set to false" do
      yaml = <<~YAML
        compiler:
          generate_rbs: false
      YAML

      create_config(yaml) do |config|
        expect(config.generate_rbs?).to be false
      end
    end

    it "returns true when set to true" do
      yaml = <<~YAML
        compiler:
          generate_rbs: true
      YAML

      create_config(yaml) do |config|
        expect(config.generate_rbs?).to be true
      end
    end
  end

  describe "compiler.target_ruby" do
    it "auto-detects current Ruby version by default" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expected = "#{RUBY_VERSION.split(".")[0]}.#{RUBY_VERSION.split(".")[1]}"
          expect(config.target_ruby).to eq(expected)
        end
      end
    end

    it "returns custom version when set" do
      yaml = <<~YAML
        compiler:
          target_ruby: "3.2"
      YAML

      create_config(yaml) do |config|
        expect(config.target_ruby).to eq("3.2")
      end
    end

    it "supports version without quotes" do
      yaml = <<~YAML
        compiler:
          target_ruby: 3.3
      YAML

      create_config(yaml) do |config|
        expect(config.target_ruby).to eq("3.3")
      end
    end

    it "raises UnsupportedRubyVersionError for unsupported version" do
      yaml = <<~YAML
        compiler:
          target_ruby: "2.7"
      YAML

      create_config(yaml) do |config|
        expect { config.target_ruby }.to raise_error(TRuby::UnsupportedRubyVersionError)
      end
    end

    it "provides target_ruby_version as RubyVersion object" do
      yaml = <<~YAML
        compiler:
          target_ruby: "3.4"
      YAML

      create_config(yaml) do |config|
        version = config.target_ruby_version
        expect(version).to be_a(TRuby::RubyVersion)
        expect(version.major).to eq(3)
        expect(version.minor).to eq(4)
      end
    end
  end

  describe "compiler.experimental" do
    it "returns empty array by default" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.experimental_features).to eq([])
        end
      end
    end

    it "returns configured experimental features" do
      yaml = <<~YAML
        compiler:
          experimental:
            - decorators
            - pattern_matching
      YAML

      create_config(yaml) do |config|
        expect(config.experimental_features).to eq(%w[decorators pattern_matching])
      end
    end

    it "checks if a specific feature is enabled" do
      yaml = <<~YAML
        compiler:
          experimental:
            - decorators
      YAML

      create_config(yaml) do |config|
        expect(config.experimental_enabled?("decorators")).to be true
        expect(config.experimental_enabled?("pattern_matching")).to be false
      end
    end
  end

  describe "compiler.checks.no_implicit_any" do
    it "returns false by default" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.check_no_implicit_any?).to be false
        end
      end
    end

    it "returns true when enabled" do
      yaml = <<~YAML
        compiler:
          checks:
            no_implicit_any: true
      YAML

      create_config(yaml) do |config|
        expect(config.check_no_implicit_any?).to be true
      end
    end

    it "returns false when disabled" do
      yaml = <<~YAML
        compiler:
          checks:
            no_implicit_any: false
      YAML

      create_config(yaml) do |config|
        expect(config.check_no_implicit_any?).to be false
      end
    end
  end

  describe "compiler.checks.no_unused_vars" do
    it "returns false by default" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.check_no_unused_vars?).to be false
        end
      end
    end

    it "returns true when enabled" do
      yaml = <<~YAML
        compiler:
          checks:
            no_unused_vars: true
      YAML

      create_config(yaml) do |config|
        expect(config.check_no_unused_vars?).to be true
      end
    end

    it "returns false when disabled" do
      yaml = <<~YAML
        compiler:
          checks:
            no_unused_vars: false
      YAML

      create_config(yaml) do |config|
        expect(config.check_no_unused_vars?).to be false
      end
    end
  end

  describe "compiler.checks.strict_nil" do
    it "returns false by default" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.check_strict_nil?).to be false
        end
      end
    end

    it "returns true when enabled" do
      yaml = <<~YAML
        compiler:
          checks:
            strict_nil: true
      YAML

      create_config(yaml) do |config|
        expect(config.check_strict_nil?).to be true
      end
    end

    it "returns false when disabled" do
      yaml = <<~YAML
        compiler:
          checks:
            strict_nil: false
      YAML

      create_config(yaml) do |config|
        expect(config.check_strict_nil?).to be false
      end
    end
  end

  describe "watch.paths" do
    it "returns empty array by default" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.watch_paths).to eq([])
        end
      end
    end

    it "returns configured paths" do
      yaml = <<~YAML
        watch:
          paths:
            - config
            - types
      YAML

      create_config(yaml) do |config|
        expect(config.watch_paths).to eq(%w[config types])
      end
    end
  end

  describe "watch.debounce" do
    it "returns 100 by default" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.watch_debounce).to eq(100)
        end
      end
    end

    it "returns configured debounce value" do
      yaml = <<~YAML
        watch:
          debounce: 200
      YAML

      create_config(yaml) do |config|
        expect(config.watch_debounce).to eq(200)
      end
    end
  end

  describe "watch.clear_screen" do
    it "returns false by default" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.watch_clear_screen?).to be false
        end
      end
    end

    it "returns true when enabled" do
      yaml = <<~YAML
        watch:
          clear_screen: true
      YAML

      create_config(yaml) do |config|
        expect(config.watch_clear_screen?).to be true
      end
    end

    it "returns false when disabled" do
      yaml = <<~YAML
        watch:
          clear_screen: false
      YAML

      create_config(yaml) do |config|
        expect(config.watch_clear_screen?).to be false
      end
    end
  end

  describe "watch.on_success" do
    it "returns nil by default" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.watch_on_success).to be_nil
        end
      end
    end

    it "returns configured command" do
      yaml = <<~YAML
        watch:
          on_success: "bundle exec rspec"
      YAML

      create_config(yaml) do |config|
        expect(config.watch_on_success).to eq("bundle exec rspec")
      end
    end
  end

  describe "version requirement" do
    it "returns nil by default" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.version_requirement).to be_nil
        end
      end
    end

    it "returns configured version requirement" do
      yaml = <<~YAML
        version: ">=1.0.0"
      YAML

      create_config(yaml) do |config|
        expect(config.version_requirement).to eq(">=1.0.0")
      end
    end

    it "checks if current version satisfies requirement" do
      yaml = <<~YAML
        version: ">=0.0.1"
      YAML

      create_config(yaml) do |config|
        expect(config.version_satisfied?).to be true
      end
    end

    it "returns false when version requirement is not met" do
      yaml = <<~YAML
        version: ">=99.0.0"
      YAML

      create_config(yaml) do |config|
        expect(config.version_satisfied?).to be false
      end
    end

    it "returns true when no version requirement is specified" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.version_satisfied?).to be true
        end
      end
    end
  end

  describe "output.clean_before_build" do
    it "returns false by default" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.clean_before_build?).to be false
        end
      end
    end

    it "returns true when set to true" do
      yaml = <<~YAML
        output:
          clean_before_build: true
      YAML

      create_config(yaml) do |config|
        expect(config.clean_before_build?).to be true
      end
    end

    it "returns false when set to false" do
      yaml = <<~YAML
        output:
          clean_before_build: false
      YAML

      create_config(yaml) do |config|
        expect(config.clean_before_build?).to be false
      end
    end
  end

  # NOTE: preserve_structure option has been removed
  # Directory structure is now always preserved based on source_include configuration:
  # - Single source_include: excludes source dir name (src/models/user.trb → build/models/user.rb)
  # - Multiple source_include: includes source dir name (src/models/user.trb → build/src/models/user.rb)

  describe "output.rbs_dir" do
    it "returns nil by default (uses ruby_dir)" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.output["rbs_dir"]).to be_nil
          expect(config.rbs_dir).to eq("build") # Falls back to ruby_dir
        end
      end
    end

    it "returns custom rbs_dir from config" do
      yaml = <<~YAML
        output:
          ruby_dir: build
          rbs_dir: sig
      YAML

      create_config(yaml) do |config|
        expect(config.rbs_dir).to eq("sig")
      end
    end

    it "uses ruby_dir when rbs_dir is not specified" do
      yaml = <<~YAML
        output:
          ruby_dir: dist
      YAML

      create_config(yaml) do |config|
        expect(config.rbs_dir).to eq("dist")
      end
    end
  end

  describe "output.ruby_dir" do
    it "returns default ruby_dir 'build'" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.ruby_dir).to eq("build")
        end
      end
    end

    it "returns custom ruby_dir from config" do
      yaml = <<~YAML
        output:
          ruby_dir: dist
      YAML

      create_config(yaml) do |config|
        expect(config.ruby_dir).to eq("dist")
      end
    end

    it "ruby_dir is aliased to out_dir for backwards compatibility" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.out_dir).to eq(config.ruby_dir)
        end
      end
    end
  end

  describe "source.extensions" do
    it "returns default extension .trb" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.source_extensions).to eq([".trb"])
        end
      end
    end

    it "returns custom extensions from config" do
      yaml = <<~YAML
        source:
          extensions:
            - .trb
            - .truby
            - .rb
      YAML

      create_config(yaml) do |config|
        expect(config.source_extensions).to eq([".trb", ".truby", ".rb"])
      end
    end

    it "finds files with custom extensions" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          FileUtils.mkdir_p("src")
          File.write("src/main.trb", "# main")
          File.write("src/utils.truby", "# utils")
          File.write("src/helper.rb", "# helper")
          File.write("src/readme.md", "# readme")

          File.write("trbconfig.yml", <<~YAML)
            source:
              extensions:
                - .trb
                - .truby
          YAML

          config = TRuby::Config.new
          files = config.find_source_files

          expect(files.size).to eq(2)
          expect(files.map { |f| File.basename(f) }).to contain_exactly("main.trb", "utils.truby")
        end
      end
    end
  end

  describe "source.exclude" do
    it "returns empty array by default" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.source_exclude).to eq([])
        end
      end
    end

    it "returns custom exclude patterns from config" do
      yaml = <<~YAML
        source:
          exclude:
            - "**/*_test.trb"
            - "**/fixtures/**"
            - vendor
      YAML

      create_config(yaml) do |config|
        expect(config.source_exclude).to eq(["**/*_test.trb", "**/fixtures/**", "vendor"])
      end
    end

    it "excludes files matching patterns" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          FileUtils.mkdir_p("src/tests")
          FileUtils.mkdir_p("src/vendor")
          File.write("src/main.trb", "# main")
          File.write("src/tests/main_test.trb", "# test")
          File.write("src/vendor/lib.trb", "# vendor lib")

          File.write("trbconfig.yml", <<~YAML)
            source:
              exclude:
                - tests
                - vendor
          YAML

          config = TRuby::Config.new
          files = config.find_source_files

          expect(files.size).to eq(1)
          expect(files.first).to end_with("main.trb")
        end
      end
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
          expect(config.source["include"]).to eq(%w[src lib])
          expect(config.source["exclude"]).to eq(["**/*_test.trb"])
          expect(config.source["extensions"]).to eq([".trb", ".truby"])
        end
      end

      it "parses output section" do
        yaml = <<~YAML
          output:
            ruby_dir: dist
            rbs_dir: sig
            clean_before_build: true
        YAML

        create_config(yaml) do |config|
          expect(config.output["ruby_dir"]).to eq("dist")
          expect(config.output["rbs_dir"]).to eq("sig")
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
            # target_ruby defaults to nil (auto-detect), but target_ruby method returns current version
            expect(config.compiler["target_ruby"]).to be_nil
            expected_ruby = "#{RUBY_VERSION.split(".")[0]}.#{RUBY_VERSION.split(".")[1]}"
            expect(config.target_ruby).to eq(expected_ruby)
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

      expect do
        create_config(yaml) { |_| }
      end.to output(/DEPRECATED|deprecated|legacy/i).to_stderr
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

  describe "environment variable expansion" do
    it "expands ${VAR} syntax in string values" do
      yaml = <<~YAML
        output:
          ruby_dir: ${TRC_OUTPUT_DIR}
      YAML

      ENV["TRC_OUTPUT_DIR"] = "custom_build"
      begin
        create_config(yaml) do |config|
          expect(config.ruby_dir).to eq("custom_build")
        end
      ensure
        ENV.delete("TRC_OUTPUT_DIR")
      end
    end

    it "expands ${VAR:-default} syntax with default value" do
      yaml = <<~YAML
        output:
          ruby_dir: ${TRC_OUTPUT_DIR:-fallback}
      YAML

      ENV.delete("TRC_OUTPUT_DIR")
      create_config(yaml) do |config|
        expect(config.ruby_dir).to eq("fallback")
      end
    end

    it "uses env value when both env and default are available" do
      yaml = <<~YAML
        output:
          ruby_dir: ${TRC_OUTPUT_DIR:-fallback}
      YAML

      ENV["TRC_OUTPUT_DIR"] = "from_env"
      begin
        create_config(yaml) do |config|
          expect(config.ruby_dir).to eq("from_env")
        end
      ensure
        ENV.delete("TRC_OUTPUT_DIR")
      end
    end

    it "expands env vars in compiler.strictness" do
      yaml = <<~YAML
        compiler:
          strictness: ${TRC_STRICTNESS:-standard}
      YAML

      ENV["TRC_STRICTNESS"] = "strict"
      begin
        create_config(yaml) do |config|
          expect(config.strictness).to eq("strict")
        end
      ensure
        ENV.delete("TRC_STRICTNESS")
      end
    end

    it "expands env vars in nested values" do
      yaml = <<~YAML
        source:
          include:
            - ${TRC_SRC_DIR:-src}
      YAML

      ENV["TRC_SRC_DIR"] = "lib"
      begin
        create_config(yaml) do |config|
          expect(config.source_include).to eq(["lib"])
        end
      ensure
        ENV.delete("TRC_SRC_DIR")
      end
    end

    it "leaves value unchanged when env var is not set and no default" do
      yaml = <<~YAML
        output:
          ruby_dir: ${TRC_NONEXISTENT_VAR}
      YAML

      ENV.delete("TRC_NONEXISTENT_VAR")
      create_config(yaml) do |config|
        # Returns empty string when env var not set
        expect(config.ruby_dir).to eq("")
      end
    end
  end
end
