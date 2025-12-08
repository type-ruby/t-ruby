# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe TRuby::DeclarationGenerator do
  let(:generator) { described_class.new }

  describe "#generate" do
    it "generates declaration for type aliases" do
      source = "type UserId = String"
      result = generator.generate(source)

      expect(result).to include("type UserId = String")
    end

    it "generates declaration for multiple type aliases" do
      source = <<~TRB
        type UserId = String
        type Age = Integer
      TRB

      result = generator.generate(source)

      expect(result).to include("type UserId = String")
      expect(result).to include("type Age = Integer")
    end

    it "generates declaration for interfaces" do
      source = <<~TRB
        interface Printable
          to_string: String
          print: void
        end
      TRB

      result = generator.generate(source)

      expect(result).to include("interface Printable")
      expect(result).to include("to_string: String")
      expect(result).to include("print: void")
      expect(result).to include("end")
    end

    it "generates declaration for functions with typed parameters" do
      source = "def greet(name: String, age: Integer): String\nend"
      result = generator.generate(source)

      expect(result).to include("def greet(name: String, age: Integer): String")
    end

    it "generates declaration for functions without return type" do
      source = "def process(data: String)\nend"
      result = generator.generate(source)

      expect(result).to include("def process(data: String)")
    end

    it "generates declaration for functions with untyped parameters" do
      source = "def simple(a, b)\nend"
      result = generator.generate(source)

      expect(result).to include("def simple(a, b)")
    end

    it "includes header comments" do
      source = "type Test = String"
      result = generator.generate(source)

      expect(result).to include("# Auto-generated type declaration file")
      expect(result).to include("# Do not edit manually")
    end

    it "handles complex source with all elements" do
      source = <<~TRB
        type UserId = String

        interface User
          id: UserId
          name: String
        end

        def get_user(id: UserId): User
        end

        def save_user(user: User): Boolean
        end
      TRB

      result = generator.generate(source)

      expect(result).to include("type UserId = String")
      expect(result).to include("interface User")
      expect(result).to include("def get_user(id: UserId): User")
      expect(result).to include("def save_user(user: User): Boolean")
    end
  end

  describe "#generate_file" do
    it "generates a .d.trb file from source file" do
      Dir.mktmpdir do |dir|
        source_path = File.join(dir, "test.trb")
        File.write(source_path, "type UserId = String")

        output_path = generator.generate_file(source_path, dir)

        expect(output_path).to eq(File.join(dir, "test.d.trb"))
        expect(File.exist?(output_path)).to be true
        expect(File.read(output_path)).to include("type UserId = String")
      end
    end

    it "raises error for non-existent file" do
      expect {
        generator.generate_file("/nonexistent.trb")
      }.to raise_error(ArgumentError, /File not found/)
    end

    it "raises error for non-.trb file" do
      Dir.mktmpdir do |dir|
        file_path = File.join(dir, "test.rb")
        File.write(file_path, "puts 'hello'")

        expect {
          generator.generate_file(file_path)
        }.to raise_error(ArgumentError, /Expected .trb file/)
      end
    end

    it "creates output directory if needed" do
      Dir.mktmpdir do |dir|
        source_path = File.join(dir, "test.trb")
        output_dir = File.join(dir, "types", "generated")
        File.write(source_path, "type Test = String")

        output_path = generator.generate_file(source_path, output_dir)

        expect(Dir.exist?(output_dir)).to be true
        expect(File.exist?(output_path)).to be true
      end
    end
  end
end

RSpec.describe TRuby::DeclarationParser do
  let(:parser) { described_class.new }

  describe "#parse" do
    it "parses type aliases" do
      content = "type UserId = String"
      parser.parse(content)

      expect(parser.type_aliases).to eq({ "UserId" => "String" })
    end

    it "parses multiple type aliases" do
      content = <<~TRB
        type UserId = String
        type Age = Integer
        type Name = String
      TRB

      parser.parse(content)

      expect(parser.type_aliases.keys).to contain_exactly("UserId", "Age", "Name")
    end

    it "parses interfaces" do
      content = <<~TRB
        interface Printable
          to_string: String
        end
      TRB

      parser.parse(content)

      expect(parser.interfaces).to have_key("Printable")
      expect(parser.interfaces["Printable"][:members].first[:name]).to eq("to_string")
    end

    it "parses functions" do
      content = "def greet(name: String): String"
      parser.parse(content)

      expect(parser.functions).to have_key("greet")
      expect(parser.functions["greet"][:return_type]).to eq("String")
    end
  end

  describe "#parse_file" do
    it "parses a .d.trb file" do
      Dir.mktmpdir do |dir|
        decl_path = File.join(dir, "types.d.trb")
        File.write(decl_path, "type UserId = String")

        parser.parse_file(decl_path)

        expect(parser.type_aliases).to eq({ "UserId" => "String" })
      end
    end

    it "raises error for non-existent file" do
      expect {
        parser.parse_file("/nonexistent.d.trb")
      }.to raise_error(ArgumentError, /Declaration file not found/)
    end

    it "raises error for wrong extension" do
      Dir.mktmpdir do |dir|
        file_path = File.join(dir, "types.trb")
        File.write(file_path, "type Test = String")

        expect {
          parser.parse_file(file_path)
        }.to raise_error(ArgumentError, /Expected .d.trb file/)
      end
    end
  end

  describe "#load_directory" do
    it "loads all declaration files from directory" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "types.d.trb"), "type UserId = String")
        File.write(File.join(dir, "models.d.trb"), "type Age = Integer")

        parser.load_directory(dir)

        expect(parser.type_aliases.keys).to contain_exactly("UserId", "Age")
      end
    end

    it "loads recursively when specified" do
      Dir.mktmpdir do |dir|
        sub_dir = File.join(dir, "sub")
        FileUtils.mkdir_p(sub_dir)

        File.write(File.join(dir, "types.d.trb"), "type UserId = String")
        File.write(File.join(sub_dir, "models.d.trb"), "type Age = Integer")

        parser.load_directory(dir, recursive: true)

        expect(parser.type_aliases.keys).to contain_exactly("UserId", "Age")
      end
    end

    it "raises error for non-existent directory" do
      expect {
        parser.load_directory("/nonexistent")
      }.to raise_error(ArgumentError, /Directory not found/)
    end
  end

  describe "#type_defined?" do
    it "returns true for defined type alias" do
      parser.parse("type UserId = String")
      expect(parser.type_defined?("UserId")).to be true
    end

    it "returns true for defined interface" do
      parser.parse("interface Printable\nend")
      expect(parser.type_defined?("Printable")).to be true
    end

    it "returns false for undefined type" do
      expect(parser.type_defined?("Unknown")).to be false
    end
  end

  describe "#merge" do
    it "merges declarations from another parser" do
      parser1 = described_class.new
      parser2 = described_class.new

      parser1.parse("type UserId = String")
      parser2.parse("type Age = Integer")

      parser1.merge(parser2)

      expect(parser1.type_aliases.keys).to contain_exactly("UserId", "Age")
    end
  end

  describe "#to_h" do
    it "returns all declarations as a hash" do
      content = <<~TRB
        type UserId = String
        interface User
          id: UserId
        end
        def get_user(id: UserId): User
      TRB

      parser.parse(content)
      result = parser.to_h

      expect(result).to have_key(:type_aliases)
      expect(result).to have_key(:interfaces)
      expect(result).to have_key(:functions)
    end
  end
end

RSpec.describe TRuby::DeclarationLoader do
  let(:loader) { described_class.new }

  describe "#add_search_path" do
    it "adds a search path" do
      loader.add_search_path("/path/to/types")
      expect(loader.search_paths).to include("/path/to/types")
    end

    it "does not add duplicate paths" do
      loader.add_search_path("/path/to/types")
      loader.add_search_path("/path/to/types")

      expect(loader.search_paths.count("/path/to/types")).to eq(1)
    end
  end

  describe "#load" do
    it "loads declaration by name" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "user.d.trb"), "type UserId = String")
        loader.add_search_path(dir)

        result = loader.load("user")

        expect(result).to be true
        expect(loader.type_aliases).to eq({ "UserId" => "String" })
      end
    end

    it "returns false when file not found" do
      loader.add_search_path("/nonexistent")
      result = loader.load("unknown")

      expect(result).to be false
    end

    it "does not load same file twice" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "user.d.trb"), "type UserId = String")
        loader.add_search_path(dir)

        loader.load("user")
        loader.load("user")

        expect(loader.loaded_files.length).to eq(1)
      end
    end
  end

  describe "#load_all" do
    it "loads all declaration files from search paths" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "types.d.trb"), "type UserId = String")
        File.write(File.join(dir, "models.d.trb"), "type Age = Integer")
        loader.add_search_path(dir)

        loader.load_all

        expect(loader.type_aliases.keys).to contain_exactly("UserId", "Age")
      end
    end
  end

  describe "#type_defined?" do
    it "checks if type is defined in loaded declarations" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "types.d.trb"), "type UserId = String")
        loader.add_search_path(dir)
        loader.load_all

        expect(loader.type_defined?("UserId")).to be true
        expect(loader.type_defined?("Unknown")).to be false
      end
    end
  end
end
