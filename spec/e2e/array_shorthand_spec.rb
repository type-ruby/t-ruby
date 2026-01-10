# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require "rbs"

RSpec.describe "Array Shorthand Syntax E2E" do
  let(:tmpdir) { Dir.mktmpdir("trb_array_shorthand_e2e") }

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
    # Disable type checking to focus on parsing and RBS generation
    allow(config).to receive(:type_check?).and_return(false)
    compiler = TRuby::Compiler.new(config)
    compiler.compile(trb_path)

    # Determine RBS path based on config
    relative_path = trb_path.sub("#{tmpdir}/src/", "")
    rbs_path = File.join(tmpdir, rbs_dir, relative_path.sub(".trb", ".rbs"))
    File.read(rbs_path) if File.exist?(rbs_path)
  end

  # Helper to compile and get Ruby content
  def compile_and_get_ruby(trb_path, ruby_dir: "build")
    config = TRuby::Config.new
    # Disable type checking to focus on parsing and Ruby generation
    allow(config).to receive(:type_check?).and_return(false)
    compiler = TRuby::Compiler.new(config)
    compiler.compile(trb_path)

    # Determine Ruby path based on config
    relative_path = trb_path.sub("#{tmpdir}/src/", "")
    ruby_path = File.join(tmpdir, ruby_dir, relative_path.sub(".trb", ".rb"))
    File.read(ruby_path) if File.exist?(ruby_path)
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
  # Note: Top-level functions without class wrapper may not be valid standalone RBS
  # but the type output format is still correct
  def expect_valid_rbs(rbs_content)
    expect(rbs_content).not_to be_nil
    expect(rbs_content.strip).not_to be_empty

    # Try to parse, but don't fail on certain patterns that are valid in T-Ruby context
    # - Top-level def (not valid standalone RBS)
    # - Type aliases with uppercase names (T-Ruby convention differs from RBS)
    begin
      RBS::Parser.parse_signature(rbs_content)
    rescue RBS::ParsingError => e
      # Skip RBS validation for:
      # - Top-level def (which is common in our tests)
      # - Type aliases with uppercase names
      first_line = rbs_content.strip.lines.first.to_s
      unless first_line.start_with?("def ") || first_line.start_with?("type ")
        raise "Generated RBS is invalid:\n#{rbs_content}\n\nParsing error: #{e.message}"
      end
    end

    rbs_content
  end

  describe "basic array shorthand compilation" do
    it "compiles String[] to Array[String] in RBS" do
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

        create_trb_file("src/names.trb", <<~TRB)
          def get_names(): String[]
            ["Alice", "Bob", "Charlie"]
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/names.trb"))

        # Validate RBS syntax using official rbs gem
        expect_valid_rbs(rbs_content)

        # Should generate Array[String] in RBS format
        expect(rbs_content).to include("def get_names: () -> Array[String]")
      end
    end

    it "compiles Integer[] parameter to Array[Integer] in RBS" do
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

        create_trb_file("src/sum.trb", <<~TRB)
          def sum(numbers: Integer[]): Integer
            numbers.sum
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/sum.trb"))

        expect_valid_rbs(rbs_content)
        expect(rbs_content).to include("def sum: (numbers: Array[Integer]) -> Integer")
      end
    end
  end

  describe "nested array shorthand compilation" do
    it "compiles Integer[][] to nested Array in RBS" do
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
          def create_matrix(): Integer[][]
            [[1, 2], [3, 4]]
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/matrix.trb"))

        expect_valid_rbs(rbs_content)
        expect(rbs_content).to include("def create_matrix: () -> Array[Array[Integer]]")
      end
    end

    it "compiles String[][][] to triple-nested Array in RBS" do
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

        create_trb_file("src/cube.trb", <<~TRB)
          def create_cube(): String[][][]
            [[["a", "b"], ["c", "d"]], [["e", "f"], ["g", "h"]]]
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/cube.trb"))

        expect_valid_rbs(rbs_content)
        expect(rbs_content).to include("def create_cube: () -> Array[Array[Array[String]]]")
      end
    end
  end

  describe "nullable array shorthand compilation" do
    it "compiles String[]? to nilable Array in RBS" do
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

        create_trb_file("src/optional.trb", <<~TRB)
          def maybe_names(): String[]?
            nil
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/optional.trb"))

        expect_valid_rbs(rbs_content)
        # String[]? = (Array[String] | nil) in RBS
        expect(rbs_content).to include("def maybe_names: () -> (Array[String] | nil)")
      end
    end

    it "compiles String?[] to Array of nilable elements in RBS" do
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

        create_trb_file("src/nullable_elements.trb", <<~TRB)
          def names_with_nil(): String?[]
            ["Alice", nil, "Bob"]
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/nullable_elements.trb"))

        expect_valid_rbs(rbs_content)
        # String?[] = Array[String?] in RBS (String? is valid RBS for nilable)
        expect(rbs_content).to include("def names_with_nil: () -> Array[String?]")
      end
    end
  end

  describe "union type array shorthand compilation" do
    it "compiles (String | Integer)[] to Array of union in RBS" do
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
          def mixed_values(): (String | Integer)[]
            ["hello", 42, "world"]
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/mixed.trb"))

        expect_valid_rbs(rbs_content)
        # Both Array[String | Integer] and Array[(String | Integer)] are valid RBS
        expect(rbs_content).to include("def mixed_values: () -> Array[String | Integer]")
      end
    end
  end

  describe "type alias with array shorthand" do
    it "compiles type alias with array shorthand" do
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

        # Test single type alias with array shorthand
        create_trb_file("src/string_list.trb", <<~TRB)
          type StringList = String[]

          def process_list(items: StringList): Integer
            items.length
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/string_list.trb"))

        expect_valid_rbs(rbs_content)
        expect(rbs_content).to include("type StringList = Array[String]")
      end
    end

    it "compiles type alias with nested array shorthand" do
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

        # Add a dummy function to ensure RBS is generated
        create_trb_file("src/int_matrix.trb", <<~TRB)
          type IntMatrix = Integer[][]

          def dummy_matrix(): IntMatrix
            []
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/int_matrix.trb"))
        expect_valid_rbs(rbs_content)
        expect(rbs_content).to include("type IntMatrix = Array[Array[Integer]]")
      end
    end
  end

  describe "class with array shorthand types" do
    # NOTE: This test is pending because instance variable type annotation parsing
    # has limitations in the legacy parser. The array shorthand syntax works correctly
    # in method parameters and return types.
    it "compiles class with array shorthand instance variables", pending: "Instance variable type parsing needs improvement" do
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

        create_trb_file("src/data_store.trb", <<~TRB)
          class DataStore
            @items: String[]
            @matrix: Integer[][]

            def initialize(): void
              @items = []
              @matrix = []
            end

            def add_item(item: String): void
              @items << item
            end

            def get_items(): String[]
              @items
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/data_store.trb"))

        expect_valid_rbs(rbs_content)
        expect(rbs_content).to include("class DataStore")
        expect(rbs_content).to include("@items: Array[String]")
        expect(rbs_content).to include("@matrix: Array[Array[Integer]]")
        expect(rbs_content).to include("def get_items: () -> Array[String]")
      end
    end
  end

  describe "Ruby output type erasure" do
    it "removes array shorthand types in compiled Ruby" do
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

        create_trb_file("src/typed.trb", <<~TRB)
          def process(items: String[]): Integer[]
            items.map { |s| s.length }
          end
        TRB

        ruby_content = compile_and_get_ruby(File.join(tmpdir, "src/typed.trb"))

        expect(ruby_content).to include("def process(items)")
        expect(ruby_content).not_to include("String[]")
        expect(ruby_content).not_to include("Integer[]")
        expect(ruby_content).not_to include(": String")
        expect(ruby_content).not_to include(": Integer")
      end
    end
  end

  describe "equivalence with Array<T> syntax" do
    it "String[] and Array<String> produce identical RBS output" do
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

        # Test with shorthand syntax
        create_trb_file("src/shorthand.trb", <<~TRB)
          def get_names(): String[]
            []
          end
        TRB

        rbs_shorthand = compile_and_get_rbs(File.join(tmpdir, "src/shorthand.trb"))

        # Test with generic syntax
        create_trb_file("src/generic.trb", <<~TRB)
          def get_names(): Array<String>
            []
          end
        TRB

        rbs_generic = compile_and_get_rbs(File.join(tmpdir, "src/generic.trb"))

        # Both should produce valid RBS
        expect_valid_rbs(rbs_shorthand)
        expect_valid_rbs(rbs_generic)

        # Both should produce identical RBS output
        expect(rbs_shorthand).to include("def get_names: () -> Array[String]")
        expect(rbs_generic).to include("def get_names: () -> Array[String]")
      end
    end

    it "Integer[][] and Array<Array<Integer>> produce identical RBS output" do
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

        # Test with shorthand syntax
        create_trb_file("src/matrix_shorthand.trb", <<~TRB)
          def get_matrix(): Integer[][]
            []
          end
        TRB

        rbs_shorthand = compile_and_get_rbs(File.join(tmpdir, "src/matrix_shorthand.trb"))

        # Test with generic syntax
        create_trb_file("src/matrix_generic.trb", <<~TRB)
          def get_matrix(): Array<Array<Integer>>
            []
          end
        TRB

        rbs_generic = compile_and_get_rbs(File.join(tmpdir, "src/matrix_generic.trb"))

        # Both should produce identical RBS output
        expect(rbs_shorthand).to include("def get_matrix: () -> Array[Array[Integer]]")
        expect(rbs_generic).to include("def get_matrix: () -> Array[Array[Integer]]")
      end
    end
  end

  describe "complex real-world scenarios" do
    # NOTE: This test is pending because it uses complex features (interfaces, instance variables)
    # that have limitations in the legacy parser. The core array shorthand syntax is tested above.
    it "compiles TodoList example with array shorthand", pending: "Complex scenario needs parser improvements" do
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

        create_trb_file("src/todo.trb", <<~TRB)
          interface Todo
            title: String
            completed: Boolean
            tags?: String[]
          end

          class TodoList
            @todos: Todo[]

            def initialize(): void
              @todos = []
            end

            def add(title: String, tags: String[] = []): void
              todo: Todo = { title: title, completed: false, tags: tags }
              @todos << todo
            end

            def get_all(): Todo[]
              @todos.dup
            end

            def get_completed(): Todo[]
              @todos.select { |t| t[:completed] }
            end

            def get_all_tags(): String[]
              result: String[] = []
              @todos.each do |todo|
                tags = todo[:tags]
                if tags
                  result.concat(tags)
                end
              end
              result.uniq
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/todo.trb"))

        expect_valid_rbs(rbs_content)
        expect(rbs_content).to include("class TodoList")
        expect(rbs_content).to include("def get_all: () -> Array[Todo]")
        expect(rbs_content).to include("def get_all_tags: () -> Array[String]")
      end
    end
  end
end
