# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe "Compiler Options E2E Behavior" do
  let(:tmpdir) { Dir.mktmpdir("trb_compiler_e2e") }

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

  describe "compiler.strictness" do
    # NOTE: strictness levels are defined but not yet enforced in the compiler.
    # These tests document the expected behavior once implemented.

    describe "strict mode" do
      it "validates strictness config value" do
        config = create_project_config(<<~YAML)
          compiler:
            strictness: strict
        YAML

        expect(config.strictness).to eq("strict")
      end

      # TODO: Implement strict mode in compiler
      # When implemented, this test should pass
      xit "rejects functions without explicit return types" do
        config = create_project_config(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
          compiler:
            strictness: strict
        YAML

        # Function without return type should error in strict mode
        create_trb_file("src/no_return.trb", <<~TRB)
          def greet(name: String)
            "Hello, \#{name}"
          end
        TRB

        compiler = TRuby::Compiler.new(config)
        expect {
          compiler.compile(File.join(tmpdir, "src/no_return.trb"))
        }.to raise_error(/return type/)
      end
    end

    describe "standard mode (default)" do
      it "allows functions without explicit return types" do
        config = create_project_config(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
          compiler:
            strictness: standard
        YAML

        create_trb_file("src/flexible.trb", <<~TRB)
          def greet(name: String)
            "Hello, \#{name}"
          end
        TRB

        compiler = TRuby::Compiler.new(config)
        expect {
          compiler.compile(File.join(tmpdir, "src/flexible.trb"))
        }.not_to raise_error
      end
    end

    describe "permissive mode" do
      it "validates permissive config value" do
        config = create_project_config(<<~YAML)
          compiler:
            strictness: permissive
        YAML

        expect(config.strictness).to eq("permissive")
      end

      it "allows any valid T-Ruby syntax" do
        config = create_project_config(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
          compiler:
            strictness: permissive
        YAML

        create_trb_file("src/loose.trb", <<~TRB)
          def process(x)
            x
          end
        TRB

        compiler = TRuby::Compiler.new(config)
        expect {
          compiler.compile(File.join(tmpdir, "src/loose.trb"))
        }.not_to raise_error
      end
    end

    it "rejects invalid strictness values" do
      expect {
        config = create_project_config(<<~YAML)
          compiler:
            strictness: invalid_value
        YAML
        config.validate!
      }.to raise_error(TRuby::ConfigError, /Invalid compiler.strictness/)
    end
  end

  describe "compiler.checks.no_implicit_any" do
    # NOTE: This check is defined but not yet enforced in the compiler.
    # These tests document the expected behavior once implemented.

    it "reads the config value correctly" do
      config_enabled = create_project_config(<<~YAML)
        compiler:
          checks:
            no_implicit_any: true
      YAML

      config_disabled = create_project_config(<<~YAML)
        compiler:
          checks:
            no_implicit_any: false
      YAML

      expect(config_enabled.check_no_implicit_any?).to be true
      expect(config_disabled.check_no_implicit_any?).to be false
    end

    # TODO: Implement no_implicit_any check in compiler
    xit "errors when parameter has no type annotation" do
      config = create_project_config(<<~YAML)
        source:
          include:
            - src
        output:
          ruby_dir: build
        compiler:
          checks:
            no_implicit_any: true
      YAML

      create_trb_file("src/implicit_any.trb", <<~TRB)
        def process(x)
          x * 2
        end
      TRB

      compiler = TRuby::Compiler.new(config)
      expect {
        compiler.compile(File.join(tmpdir, "src/implicit_any.trb"))
      }.to raise_error(/implicit any|type annotation required/i)
    end

    it "allows untyped parameters when disabled (default)" do
      config = create_project_config(<<~YAML)
        source:
          include:
            - src
        output:
          ruby_dir: build
        compiler:
          checks:
            no_implicit_any: false
      YAML

      create_trb_file("src/allow_any.trb", <<~TRB)
        def process(x)
          x * 2
        end
      TRB

      compiler = TRuby::Compiler.new(config)
      expect {
        compiler.compile(File.join(tmpdir, "src/allow_any.trb"))
      }.not_to raise_error
    end
  end

  describe "compiler.checks.no_unused_vars" do
    # NOTE: This check is defined but not yet enforced in the compiler.
    # These tests document the expected behavior once implemented.

    it "reads the config value correctly" do
      config = create_project_config(<<~YAML)
        compiler:
          checks:
            no_unused_vars: true
      YAML

      expect(config.check_no_unused_vars?).to be true
    end

    # TODO: Implement no_unused_vars check in compiler
    xit "warns about unused local variables" do
      config = create_project_config(<<~YAML)
        source:
          include:
            - src
        output:
          ruby_dir: build
        compiler:
          checks:
            no_unused_vars: true
      YAML

      create_trb_file("src/unused.trb", <<~TRB)
        def calculate(x: Integer): Integer
          unused = 42
          x * 2
        end
      TRB

      compiler = TRuby::Compiler.new(config)
      # Should warn or error about unused variable
      expect {
        compiler.compile(File.join(tmpdir, "src/unused.trb"))
      }.to raise_error(/unused.*unused/i)
    end
  end

  describe "compiler.checks.strict_nil" do
    # NOTE: This check is defined but not yet enforced in the compiler.
    # These tests document the expected behavior once implemented.

    it "reads the config value correctly" do
      config = create_project_config(<<~YAML)
        compiler:
          checks:
            strict_nil: true
      YAML

      expect(config.check_strict_nil?).to be true
    end

    # TODO: Implement strict_nil check in compiler
    xit "requires explicit nil handling" do
      config = create_project_config(<<~YAML)
        source:
          include:
            - src
        output:
          ruby_dir: build
        compiler:
          checks:
            strict_nil: true
      YAML

      # Function returns String | nil but caller doesn't handle nil
      create_trb_file("src/nil_unsafe.trb", <<~TRB)
        def find_user(id: Integer): String | nil
          nil
        end

        def greet_user(id: Integer): String
          user = find_user(id)
          "Hello, \#{user}"  # Unsafe: user could be nil
        end
      TRB

      compiler = TRuby::Compiler.new(config)
      expect {
        compiler.compile(File.join(tmpdir, "src/nil_unsafe.trb"))
      }.to raise_error(/nil|null/i)
    end
  end

  describe "compiler.target_ruby" do
    it "reads the target Ruby version" do
      config = create_project_config(<<~YAML)
        compiler:
          target_ruby: "3.2"
      YAML

      expect(config.target_ruby).to eq("3.2")
    end

    it "defaults to 3.0" do
      config = create_project_config(<<~YAML)
        source:
          include:
            - src
      YAML

      expect(config.target_ruby).to eq("3.0")
    end

    # TODO: When target_ruby affects code generation, add tests here
    # e.g., using Ruby 3.1+ pattern matching syntax only when target >= 3.1
  end

  describe "compiler.experimental" do
    it "reads experimental features list" do
      config = create_project_config(<<~YAML)
        compiler:
          experimental:
            - decorators
            - pattern_matching_types
      YAML

      expect(config.experimental_features).to eq(["decorators", "pattern_matching_types"])
      expect(config.experimental_enabled?("decorators")).to be true
      expect(config.experimental_enabled?("pattern_matching_types")).to be true
      expect(config.experimental_enabled?("nonexistent")).to be false
    end

    it "defaults to empty array" do
      config = create_project_config(<<~YAML)
        source:
          include:
            - src
      YAML

      expect(config.experimental_features).to eq([])
    end

    # TODO: When experimental features are implemented, add tests for each
  end
end
