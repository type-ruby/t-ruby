# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tempfile"

describe TRuby::Config do
  describe "initialization with default config" do
    it "initializes with default configuration when no config file exists" do
      # Use a temporary directory that doesn't have a trbconfig.yml
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new

          expect(config).to be_a(TRuby::Config)
          expect(config.emit).to eq({"rb" => true, "rbs" => false, "dtrb" => false})
          expect(config.paths).to eq({"src" => "./src", "out" => "./build"})
          expect(config.strict).to eq({"rbs_compat" => true, "null_safety" => false, "inference" => "basic"})
        end
      end
    end

    it "has correct default out_dir" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.out_dir).to eq("./build")
        end
      end
    end

    it "has correct default src_dir" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          config = TRuby::Config.new
          expect(config.src_dir).to eq("./src")
        end
      end
    end
  end

  describe "initialization with custom config file" do
    it "loads configuration from specified config path" do
      Dir.mktmpdir do |tmpdir|
        config_file = File.join(tmpdir, "custom.yml")
        File.write(config_file, <<~YAML)
          emit:
            rb: true
            rbs: true
            dtrb: false
          paths:
            src: ./source
            out: ./output
          strict:
            rbs_compat: false
            null_safety: true
            inference: advanced
        YAML

        config = TRuby::Config.new(config_file)

        expect(config.emit["rbs"]).to eq(true)
        expect(config.paths["src"]).to eq("./source")
        expect(config.paths["out"]).to eq("./output")
        expect(config.strict["rbs_compat"]).to eq(false)
        expect(config.strict["null_safety"]).to eq(true)
        expect(config.strict["inference"]).to eq("advanced")
      end
    end

    it "falls back to default config if specified file doesn't exist" do
      config = TRuby::Config.new("/nonexistent/path/config.yml")

      expect(config.emit).to eq({"rb" => true, "rbs" => false, "dtrb" => false})
      expect(config.out_dir).to eq("./build")
    end

    it "loads trbconfig.yml from current directory if it exists" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          File.write("trbconfig.yml", <<~YAML)
            emit:
              rb: false
              rbs: true
              dtrb: true
            paths:
              src: ./lib
              out: ./dist
            strict:
              rbs_compat: true
              null_safety: true
              inference: strict
          YAML

          config = TRuby::Config.new

          expect(config.emit["rb"]).to eq(false)
          expect(config.emit["rbs"]).to eq(true)
          expect(config.emit["dtrb"]).to eq(true)
          expect(config.out_dir).to eq("./dist")
          expect(config.src_dir).to eq("./lib")
          expect(config.strict["inference"]).to eq("strict")
        end
      end
    end

    it "prefers explicitly passed config path over trbconfig.yml" do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          # Create trbconfig.yml with one config
          File.write("trbconfig.yml", <<~YAML)
            paths:
              out: ./default_build
          YAML

          # Create explicit config with different path
          explicit_config = File.join(tmpdir, "explicit.yml")
          File.write(explicit_config, <<~YAML)
            paths:
              out: ./explicit_build
          YAML

          config = TRuby::Config.new(explicit_config)

          expect(config.out_dir).to eq("./explicit_build")
        end
      end
    end
  end

  describe "attr_reader accessors" do
    it "provides read-only access to emit" do
      config = TRuby::Config.new
      expect { config.emit = {} }.to raise_error(NoMethodError)
    end

    it "provides read-only access to paths" do
      config = TRuby::Config.new
      expect { config.paths = {} }.to raise_error(NoMethodError)
    end

    it "provides read-only access to strict" do
      config = TRuby::Config.new
      expect { config.strict = {} }.to raise_error(NoMethodError)
    end
  end

  describe "DEFAULT_CONFIG constant" do
    it "is frozen to prevent modifications" do
      expect(TRuby::Config::DEFAULT_CONFIG).to be_frozen
    end

    it "contains expected keys" do
      expect(TRuby::Config::DEFAULT_CONFIG).to have_key("emit")
      expect(TRuby::Config::DEFAULT_CONFIG).to have_key("paths")
      expect(TRuby::Config::DEFAULT_CONFIG).to have_key("strict")
    end
  end
end
