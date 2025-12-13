# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe "Watch Mode E2E Behavior" do
  let(:tmpdir) { Dir.mktmpdir("trb_watch_e2e") }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  # Helper to create config and return Config object
  def create_project_config(yaml_content)
    config_path = File.join(tmpdir, "trbconfig.yml")
    File.write(config_path, yaml_content)
    Dir.chdir(tmpdir) { TRuby::Config.new(config_path) }
  end

  # Helper to create a .trb file
  def create_trb_file(relative_path, content)
    full_path = File.join(tmpdir, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
    full_path
  end

  describe "watch.paths (additional watch paths)" do
    it "includes additional paths in watch directories" do
      config = create_project_config(<<~YAML)
        source:
          include:
            - src
        watch:
          paths:
            - config
            - types
      YAML

      # config.watch_paths should return the additional paths
      expect(config.watch_paths).to eq(["config", "types"])
    end
  end

  describe "watch.debounce" do
    it "configures debounce delay in milliseconds" do
      config = create_project_config(<<~YAML)
        watch:
          debounce: 500
      YAML

      expect(config.watch_debounce).to eq(500)

      # Watcher should use this value (internal implementation detail)
      watcher = TRuby::Watcher.new(paths: [tmpdir], config: config)
      expect(watcher.instance_variable_get(:@config).watch_debounce).to eq(500)
    end

    it "defaults to 100ms when not specified" do
      config = create_project_config(<<~YAML)
        source:
          include:
            - src
      YAML

      expect(config.watch_debounce).to eq(100)
    end
  end

  describe "watch.clear_screen" do
    it "configures screen clearing behavior" do
      config_with_clear = create_project_config(<<~YAML)
        watch:
          clear_screen: true
      YAML

      config_without_clear = create_project_config(<<~YAML)
        watch:
          clear_screen: false
      YAML

      expect(config_with_clear.watch_clear_screen?).to be true
      expect(config_without_clear.watch_clear_screen?).to be false
    end

    it "defaults to false when not specified" do
      config = create_project_config(<<~YAML)
        source:
          include:
            - src
      YAML

      expect(config.watch_clear_screen?).to be false
    end
  end

  describe "watch.on_success" do
    it "configures command to run after successful compilation" do
      config = create_project_config(<<~YAML)
        watch:
          on_success: "bundle exec rspec"
      YAML

      expect(config.watch_on_success).to eq("bundle exec rspec")
    end

    it "defaults to nil when not specified" do
      config = create_project_config(<<~YAML)
        source:
          include:
            - src
      YAML

      expect(config.watch_on_success).to be_nil
    end
  end

  describe "watcher file discovery" do
    it "finds .trb files only in specified directory" do
      config = create_project_config(<<~YAML)
        source:
          include:
            - src
        output:
          ruby_dir: build
      YAML

      create_trb_file("src/main.trb", "def main: void\nend")
      create_trb_file("lib/utils.trb", "def utils: void\nend")
      create_trb_file("other/ignore.trb", "def ignore: void\nend")

      # Watch only lib/ directory explicitly
      lib_path = File.join(tmpdir, "lib")
      watcher = TRuby::Watcher.new(paths: [lib_path], config: config)

      files = watcher.send(:find_trb_files)
      expect(files.size).to eq(1)
      expect(files.first).to end_with("utils.trb")
    end

    it "finds .rb files as well when watching" do
      config = create_project_config(<<~YAML)
        source:
          include:
            - src
          extensions:
            - ".trb"
            - ".rb"
        output:
          ruby_dir: build
      YAML

      create_trb_file("src/typed.trb", "def typed: void\nend")
      File.write(File.join(tmpdir, "src/plain.rb"), "def plain; end")

      src_path = File.join(tmpdir, "src")
      watcher = TRuby::Watcher.new(paths: [src_path], config: config)

      trb_files = watcher.send(:find_trb_files)
      rb_files = watcher.send(:find_rb_files)

      expect(trb_files.size).to eq(1)
      expect(rb_files.size).to eq(1)
    end

    it "respects exclude patterns even when watching specific directory" do
      config = create_project_config(<<~YAML)
        source:
          include:
            - src
          exclude:
            - vendor
            - "**/*_test.trb"
        output:
          ruby_dir: build
      YAML

      create_trb_file("src/main.trb", "def main: void\nend")
      create_trb_file("src/main_test.trb", "def main_test: void\nend")
      create_trb_file("src/vendor/external.trb", "def external: void\nend")

      src_path = File.join(tmpdir, "src")
      watcher = TRuby::Watcher.new(paths: [src_path], config: config)

      files = watcher.send(:find_trb_files)
      expect(files.size).to eq(1)
      expect(files.first).to end_with("main.trb")
    end
  end

  describe "watcher compilation behavior" do
    it "compiles changed files to correct output directory" do
      # Create config with absolute paths
      config_path = File.join(tmpdir, "trbconfig.yml")
      File.write(config_path, <<~YAML)
        source:
          include:
            - src
        output:
          ruby_dir: #{File.join(tmpdir, "dist")}
        compiler:
          generate_rbs: false
      YAML

      config = Dir.chdir(tmpdir) { TRuby::Config.new(config_path) }

      file_path = create_trb_file("src/watchme.trb", <<~TRB)
        def watchme(x: Integer): Integer
          x * 2
        end
      TRB

      watcher = TRuby::Watcher.new(paths: [File.join(tmpdir, "src")], config: config)

      # Trigger compile_file directly
      result = watcher.send(:compile_file, file_path)

      expect(result[:success]).to be true
      expect(File.exist?(File.join(tmpdir, "dist/watchme.rb"))).to be true
    end

    it "tracks compilation statistics" do
      # Create config with absolute paths
      config_path = File.join(tmpdir, "trbconfig.yml")
      File.write(config_path, <<~YAML)
        source:
          include:
            - src
        output:
          ruby_dir: #{File.join(tmpdir, "build")}
      YAML

      config = Dir.chdir(tmpdir) { TRuby::Config.new(config_path) }

      create_trb_file("src/stats.trb", "def stats: void\nend")

      watcher = TRuby::Watcher.new(paths: [File.join(tmpdir, "src")], config: config)

      expect(watcher.stats[:total_compilations]).to eq(0)

      watcher.send(:compile_file, File.join(tmpdir, "src/stats.trb"))

      expect(watcher.stats[:total_compilations]).to eq(1)
    end
  end

  describe "incremental compilation in watch mode" do
    it "skips unchanged files" do
      # Create config with absolute paths
      config_path = File.join(tmpdir, "trbconfig.yml")
      File.write(config_path, <<~YAML)
        source:
          include:
            - src
        output:
          ruby_dir: #{File.join(tmpdir, "build")}
      YAML

      config = Dir.chdir(tmpdir) { TRuby::Config.new(config_path) }

      file_path = create_trb_file("src/incremental.trb", "def inc: void\nend")

      watcher = TRuby::Watcher.new(
        paths: [File.join(tmpdir, "src")],
        config: config,
        incremental: true
      )

      # First compile - incremental_compiler.compile_with_ir updates stats internally
      watcher.incremental_compiler.compile_with_ir(file_path)

      # Second compile without changes - should detect no change needed
      needs_compile = watcher.incremental_compiler.needs_compile?(file_path)
      expect(needs_compile).to be false
    end

    it "detects modified files" do
      # Create config with absolute paths
      config_path = File.join(tmpdir, "trbconfig.yml")
      File.write(config_path, <<~YAML)
        source:
          include:
            - src
        output:
          ruby_dir: #{File.join(tmpdir, "build")}
      YAML

      config = Dir.chdir(tmpdir) { TRuby::Config.new(config_path) }

      file_path = create_trb_file("src/modified.trb", "def original: void\nend")

      watcher = TRuby::Watcher.new(
        paths: [File.join(tmpdir, "src")],
        config: config,
        incremental: true
      )

      # First compile
      watcher.incremental_compiler.compile_with_ir(file_path)

      # Modify the file
      sleep(0.1) # Ensure mtime changes
      File.write(file_path, "def modified: void\nend")

      # Should detect change
      needs_compile = watcher.incremental_compiler.needs_compile?(file_path)
      expect(needs_compile).to be true
    end
  end
end
