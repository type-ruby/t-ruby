# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require "rbs"

RSpec.describe "Class RBS Generation E2E" do
  let(:tmpdir) { Dir.mktmpdir("trb_class_rbs_e2e") }

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
    compiler = TRuby::Compiler.new(config)
    compiler.compile(trb_path)

    # Determine RBS path based on config
    relative_path = trb_path.sub("#{tmpdir}/src/", "")
    rbs_path = File.join(tmpdir, rbs_dir, relative_path.sub(".trb", ".rbs"))
    File.read(rbs_path) if File.exist?(rbs_path)
  end

  # Helper to normalize RBS content for comparison (ignore whitespace differences)
  def normalize_rbs(content)
    content.to_s.lines.map(&:rstrip).reject(&:empty?).join("\n")
  end

  # Helper to validate RBS syntax using the official rbs gem
  def valid_rbs_syntax?(rbs_content)
    return false if rbs_content.nil? || rbs_content.strip.empty?

    RBS::Parser.parse_signature(rbs_content)
    true
  rescue RBS::ParsingError
    false
  end

  # Helper to assert RBS is valid and return parsed content
  def expect_valid_rbs(rbs_content)
    expect(rbs_content).not_to be_nil
    expect(rbs_content.strip).not_to be_empty

    begin
      RBS::Parser.parse_signature(rbs_content)
    rescue RBS::ParsingError => e
      raise "Generated RBS is invalid:\n#{rbs_content}\n\nParsing error: #{e.message}"
    end

    rbs_content
  end

  describe "class wrapper generation" do
    it "wraps class methods in RBS class block" do
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

        create_trb_file("src/greeter.trb", <<~TRB)
          class Greeter
            def greet(): String
              "Hello"
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/greeter.trb"))

        # Validate RBS syntax using official rbs gem
        expect_valid_rbs(rbs_content)

        expect(rbs_content).to include("class Greeter")
        expect(rbs_content).to include("def greet: () -> String")
        expect(rbs_content).to include("end")
      end
    end
  end

  describe "instance variable declaration" do
    it "declares instance variables assigned in initialize" do
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

        create_trb_file("src/person.trb", <<~TRB)
          class Person
            def initialize(name: String, age: Integer): void
              @name = name
              @age = age
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/person.trb"))

        # Validate RBS syntax using official rbs gem
        expect_valid_rbs(rbs_content)

        expect(rbs_content).to include("class Person")
        expect(rbs_content).to include("@name: String")
        expect(rbs_content).to include("@age: Integer")
      end
    end
  end

  describe "keyword argument format" do
    it "generates RBS with keyword argument syntax (name: Type)" do
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

        create_trb_file("src/calculator.trb", <<~TRB)
          class Calculator
            def add(a: Integer, b: Integer): Integer
              a + b
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/calculator.trb"))

        # Validate RBS syntax using official rbs gem
        expect_valid_rbs(rbs_content)

        # Should be keyword argument format: (a: Integer, b: Integer)
        # NOT positional format: (Integer a, Integer b)
        expect(rbs_content).to include("def add: (a: Integer, b: Integer) -> Integer")
        expect(rbs_content).not_to include("Integer a")
        expect(rbs_content).not_to include("Integer b")
      end
    end
  end

  describe "methods without type annotations" do
    it "infers return type from method body" do
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

        create_trb_file("src/mixed.trb", <<~TRB)
          class Mixed
            def typed_method(x: Integer): String
              x.to_s
            end

            def untyped_method
              "something"
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/mixed.trb"))

        # Validate RBS syntax using official rbs gem
        expect_valid_rbs(rbs_content)

        expect(rbs_content).to include("def typed_method: (x: Integer) -> String")
        # Type inference: returns "something" (String literal) -> String
        expect(rbs_content).to include("def untyped_method: () -> String")
      end
    end
  end

  describe "visibility modifier generation" do
    it "generates RBS with private method visibility" do
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

        create_trb_file("src/secret.trb", <<~TRB)
          class Secret
            def public_method(): String
              "public"
            end

            private def hidden(x: Integer): Boolean
              x > 0
            end

            protected def internal(name: String): String
              name.upcase
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/secret.trb"))

        # Validate RBS syntax using official rbs gem
        expect_valid_rbs(rbs_content)

        expect(rbs_content).to include("class Secret")
        expect(rbs_content).to include("def public_method: () -> String")
        expect(rbs_content).to include("private def hidden: (x: Integer) -> Boolean")
        # RBS does not support protected visibility, treated as public
        # See: https://github.com/ruby/rbs/issues/579
        expect(rbs_content).to include("def internal: (name: String) -> String")
        expect(rbs_content).not_to include("protected def")
      end
    end

    it "preserves visibility in compiled Ruby code" do
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

        create_trb_file("src/visible.trb", <<~TRB)
          class Visible
            private def secret(x: String): Integer
              x.length
            end
          end
        TRB

        trb_path = File.join(tmpdir, "src/visible.trb")
        config = TRuby::Config.new
        compiler = TRuby::Compiler.new(config)
        compiler.compile(trb_path)

        # Check compiled Ruby preserves private keyword
        ruby_path = File.join(tmpdir, "build/visible.rb")
        ruby_content = File.read(ruby_path)

        expect(ruby_content).to include("private def secret")
        expect(ruby_content).not_to include(": String")
        expect(ruby_content).not_to include(": Integer")
      end
    end
  end

  describe "block type annotation" do
    it "generates RBS with block signature from Proc type annotation" do
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

        create_trb_file("src/iterator.trb", <<~TRB)
          class Iterator
            def each(&block: Proc(Integer) -> void): void
              yield 1
              yield 2
            end

            def map_values(initial: Integer, &block: Proc(Integer, Integer) -> String): Array<String>
              []
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/iterator.trb"))

        # Validate RBS syntax using official rbs gem
        expect_valid_rbs(rbs_content)

        # Block signature should use RBS block syntax: { (params) -> return }
        expect(rbs_content).to include("def each: () { (Integer) -> void } -> void")
        expect(rbs_content).to include("def map_values: (initial: Integer) { (Integer, Integer) -> String } -> Array[String]")
      end
    end

    it "generates RBS with optional block signature using ?{ } syntax" do
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

        create_trb_file("src/optional_block.trb", <<~TRB)
          class OptionalBlock
            def maybe_yield(&block?: Proc(Integer) -> void): void
              if block_given?
                yield 1
              end
            end

            def required_block(&block: Proc(String) -> String): String
              yield "hello"
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/optional_block.trb"))

        # Validate RBS syntax using official rbs gem
        expect_valid_rbs(rbs_content)

        # Optional block should use ?{ } syntax
        expect(rbs_content).to include("def maybe_yield: () ?{ (Integer) -> void } -> void")
        # Required block should use { } syntax (no ?)
        expect(rbs_content).to include("def required_block: () { (String) -> String } -> String")
      end
    end
  end

  describe "HelloWorld integration test" do
    it "generates correct RBS for HelloWorld sample structure" do
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

        # This matches the structure of samples/hello/src/world.trb
        create_trb_file("src/world.trb", <<~TRB)
          class HelloWorld
            def initialize(name: String): void
              @name = name
            end

            def greet(): String
              "Hello, \#{@name}!"
            end

            def hi
              "asdf1234!="
            end
          end

          puts HelloWorld.new("World").greet()
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/world.trb"))

        # Validate RBS syntax using official rbs gem
        expect_valid_rbs(rbs_content)

        # Should have class wrapper
        expect(rbs_content).to include("class HelloWorld")

        # Should have instance variable declaration
        expect(rbs_content).to include("@name: String")

        # Should have initialize with keyword argument format
        expect(rbs_content).to include("def initialize: (name: String) -> void")

        # Should have greet method
        expect(rbs_content).to include("def greet: () -> String")

        # Type inference: hi returns "asdf1234!=" (String literal) -> String
        expect(rbs_content).to include("def hi: () -> String")

        # Should have closing end
        expect(rbs_content).to include("end")
      end
    end
  end
end
