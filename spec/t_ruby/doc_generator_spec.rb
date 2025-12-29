# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tempfile"

describe TRuby::DocGenerator do
  let(:config) { instance_double(TRuby::Config) }
  let(:generator) { described_class.new(config) }

  describe "#initialize" do
    it "initializes with default config when none provided" do
      allow(TRuby::Config).to receive(:new).and_return(config)
      gen = described_class.new
      expect(gen.config).to eq(config)
    end

    it "initializes with provided config" do
      expect(generator.config).to eq(config)
    end

    it "initializes docs with empty structures" do
      expect(generator.docs).to eq(
        { types: {}, interfaces: {}, functions: {}, modules: {} }
      )
    end
  end

  describe "#generate" do
    let(:trb_content) do
      <<~TRB
        type UserId = Integer

        interface User
          id: Integer
          name: String
        end

        def greet(name: String): String
          "Hello, \#{name}"
        end
      TRB
    end

    it "generates documentation files" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        output_dir = File.join(tmpdir, "docs")
        File.write(input_file, trb_content)

        allow(generator).to receive(:puts)
        generator.generate([input_file], output_dir: output_dir)

        expect(File.exist?(File.join(output_dir, "index.html"))).to be true
        expect(Dir.exist?(File.join(output_dir, "types"))).to be true
        expect(Dir.exist?(File.join(output_dir, "interfaces"))).to be true
        expect(Dir.exist?(File.join(output_dir, "functions"))).to be true
      end
    end

    it "parses type aliases" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        output_dir = File.join(tmpdir, "docs")
        File.write(input_file, "type MyType = String | Integer")

        allow(generator).to receive(:puts)
        generator.generate([input_file], output_dir: output_dir)

        expect(generator.docs[:types]).to have_key("MyType")
        expect(generator.docs[:types]["MyType"][:definition]).to eq("String | Integer")
      end
    end

    it "parses generic types" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        output_dir = File.join(tmpdir, "docs")
        File.write(input_file, "type Container<T> = Array<T> | nil")

        allow(generator).to receive(:puts)
        generator.generate([input_file], output_dir: output_dir)

        expect(generator.docs[:types]["Container"][:type_params]).to eq(["T"])
      end
    end

    it "generates search index" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        output_dir = File.join(tmpdir, "docs")
        File.write(input_file, trb_content)

        allow(generator).to receive(:puts)
        generator.generate([input_file], output_dir: output_dir)

        search_index_path = File.join(output_dir, "search-index.json")
        expect(File.exist?(search_index_path)).to be true

        search_data = JSON.parse(File.read(search_index_path))
        expect(search_data).to be_an(Array)
      end
    end
  end

  describe "#generate_markdown" do
    let(:trb_content) do
      <<~TRB
        type Status = "active" | "inactive"

        interface Product
          id: Integer
          name: String
        end

        def calculate(a: Integer, b: Integer): Integer
          a + b
        end
      TRB
    end

    it "generates markdown file" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        output_path = File.join(tmpdir, "API.md")
        File.write(input_file, trb_content)

        allow(generator).to receive(:puts)
        generator.generate_markdown([input_file], output_path: output_path)

        expect(File.exist?(output_path)).to be true
        content = File.read(output_path)
        expect(content).to include("# T-Ruby API Documentation")
      end
    end

    it "includes types section" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        output_path = File.join(tmpdir, "API.md")
        File.write(input_file, trb_content)

        allow(generator).to receive(:puts)
        generator.generate_markdown([input_file], output_path: output_path)

        content = File.read(output_path)
        expect(content).to include("## Types")
        expect(content).to include("Status")
      end
    end

    it "includes interfaces section" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        output_path = File.join(tmpdir, "API.md")
        File.write(input_file, trb_content)

        allow(generator).to receive(:puts)
        generator.generate_markdown([input_file], output_path: output_path)

        content = File.read(output_path)
        expect(content).to include("## Interfaces")
        expect(content).to include("Product")
      end
    end

    it "includes functions section" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        output_path = File.join(tmpdir, "API.md")
        File.write(input_file, trb_content)

        allow(generator).to receive(:puts)
        generator.generate_markdown([input_file], output_path: output_path)

        content = File.read(output_path)
        expect(content).to include("## Functions")
        expect(content).to include("calculate")
      end
    end

    it "includes table of contents" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        output_path = File.join(tmpdir, "API.md")
        File.write(input_file, trb_content)

        allow(generator).to receive(:puts)
        generator.generate_markdown([input_file], output_path: output_path)

        content = File.read(output_path)
        expect(content).to include("## Table of Contents")
        expect(content).to include("[Types](#types)")
        expect(content).to include("[Interfaces](#interfaces)")
        expect(content).to include("[Functions](#functions)")
      end
    end
  end

  describe "#generate_json" do
    let(:trb_content) do
      <<~TRB
        type Id = Integer
        interface Entity
          id: Id
        end
      TRB
    end

    it "generates JSON file" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        output_path = File.join(tmpdir, "api.json")
        File.write(input_file, trb_content)

        allow(generator).to receive(:puts)
        generator.generate_json([input_file], output_path: output_path)

        expect(File.exist?(output_path)).to be true
        json = JSON.parse(File.read(output_path))
        expect(json).to have_key("generated_at")
        expect(json).to have_key("version")
        expect(json).to have_key("types")
        expect(json).to have_key("interfaces")
      end
    end

    it "includes type information" do
      Dir.mktmpdir do |tmpdir|
        input_file = File.join(tmpdir, "test.trb")
        output_path = File.join(tmpdir, "api.json")
        File.write(input_file, trb_content)

        allow(generator).to receive(:puts)
        generator.generate_json([input_file], output_path: output_path)

        json = JSON.parse(File.read(output_path))
        expect(json["types"]).to have_key("Id")
      end
    end
  end

  describe "private methods" do
    describe "#collect_files" do
      it "collects .trb files from directory" do
        Dir.mktmpdir do |tmpdir|
          FileUtils.touch(File.join(tmpdir, "test.trb"))
          FileUtils.touch(File.join(tmpdir, "other.rb"))

          files = generator.send(:collect_files, [tmpdir])

          expect(files.length).to eq(1)
          expect(files.first).to end_with("test.trb")
        end
      end

      it "collects .d.trb files from directory" do
        Dir.mktmpdir do |tmpdir|
          FileUtils.touch(File.join(tmpdir, "types.d.trb"))

          files = generator.send(:collect_files, [tmpdir])

          expect(files.length).to eq(1)
          expect(files.first).to end_with("types.d.trb")
        end
      end

      it "collects single file" do
        Dir.mktmpdir do |tmpdir|
          file_path = File.join(tmpdir, "test.trb")
          FileUtils.touch(file_path)

          files = generator.send(:collect_files, [file_path])

          expect(files).to eq([file_path])
        end
      end

      it "returns unique files" do
        Dir.mktmpdir do |tmpdir|
          file_path = File.join(tmpdir, "test.trb")
          FileUtils.touch(file_path)

          files = generator.send(:collect_files, [tmpdir, file_path])

          expect(files.uniq).to eq(files)
        end
      end
    end

    describe "#extract_doc_comments" do
      it "extracts @doc comments" do
        content = <<~TRB
          # @doc type:MyType
          # This is a description
          type MyType = String
        TRB

        comments = generator.send(:extract_doc_comments, content)
        expect(comments).to have_key("type:MyType")
      end

      it "extracts inline comments before definitions" do
        content = <<~TRB
          # This is a type alias
          type MyType = String
        TRB

        comments = generator.send(:extract_doc_comments, content)
        expect(comments).to have_key("type:MyType")
        expect(comments["type:MyType"]).to include("type alias")
      end
    end

    describe "#parse_interfaces" do
      it "parses interface with members" do
        content = <<~TRB
          interface User
            id: Integer
            name: String
          end
        TRB

        generator.send(:parse_interfaces, content, "test.trb", {})

        expect(generator.docs[:interfaces]).to have_key("User")
        expect(generator.docs[:interfaces]["User"][:members].length).to eq(2)
      end

      it "parses generic interface" do
        content = <<~TRB
          interface Container<T>
            value: T
          end
        TRB

        generator.send(:parse_interfaces, content, "test.trb", {})

        expect(generator.docs[:interfaces]["Container"][:type_params]).to eq(["T"])
      end
    end

    describe "#parse_functions" do
      it "parses function with parameters" do
        content = "def add(a: Integer, b: Integer): Integer\n  a + b\nend"

        generator.send(:parse_functions, content, "test.trb", {})

        expect(generator.docs[:functions]).to have_key("add")
        expect(generator.docs[:functions]["add"][:params].length).to eq(2)
        expect(generator.docs[:functions]["add"][:return_type]).to eq("Integer")
      end

      it "parses generic function" do
        content = "def first<T>(items: Array<T>): T\n  items.first\nend"

        generator.send(:parse_functions, content, "test.trb", {})

        expect(generator.docs[:functions]["first"][:type_params]).to eq(["T"])
      end

      it "parses function with special characters in name" do
        content = "def valid?(value: Boolean): Boolean\n  value\nend"

        generator.send(:parse_functions, content, "test.trb", {})

        expect(generator.docs[:functions]).to have_key("valid?")
      end
    end

    describe "#generate_type_html" do
      it "generates HTML for type" do
        info = {
          definition: "String | Integer",
          description: "A test type",
          source: "test.trb",
          type_params: nil,
        }

        html = generator.send(:generate_type_html, "MyType", info)

        expect(html).to include("<title>MyType - T-Ruby API</title>")
        expect(html).to include("type MyType")
        expect(html).to include("String | Integer")
      end

      it "includes type parameters" do
        info = {
          definition: "Array<T>",
          type_params: ["T"],
          source: "test.trb",
        }

        html = generator.send(:generate_type_html, "Container", info)

        expect(html).to include("<T>")
      end
    end

    describe "#generate_interface_html" do
      it "generates HTML for interface" do
        info = {
          members: [
            { name: "id", type: "Integer", description: "The ID" },
          ],
          source: "test.trb",
          type_params: nil,
        }

        html = generator.send(:generate_interface_html, "User", info)

        expect(html).to include("<title>User - T-Ruby API</title>")
        expect(html).to include("interface User")
        expect(html).to include("id")
        expect(html).to include("Integer")
      end
    end

    describe "#generate_function_html" do
      it "generates HTML for function" do
        info = {
          params: [
            { name: "a", type: "Integer" },
            { name: "b", type: "Integer" },
          ],
          return_type: "Integer",
          source: "test.trb",
          type_params: nil,
        }

        html = generator.send(:generate_function_html, "add", info)

        expect(html).to include("<title>add - T-Ruby API</title>")
        expect(html).to include("def add")
        expect(html).to include("a: Integer")
        expect(html).to include("Returns")
      end
    end

    describe "#generate_search_index" do
      it "generates search index with all items" do
        generator.docs[:types]["MyType"] = { name: "MyType" }
        generator.docs[:interfaces]["MyInterface"] = { name: "MyInterface" }
        generator.docs[:functions]["myFunc"] = { name: "myFunc" }

        Dir.mktmpdir do |tmpdir|
          generator.send(:generate_search_index, tmpdir)

          index_path = File.join(tmpdir, "search-index.json")
          expect(File.exist?(index_path)).to be true

          data = JSON.parse(File.read(index_path))
          types = data.select { |d| d["type"] == "type" }
          interfaces = data.select { |d| d["type"] == "interface" }
          functions = data.select { |d| d["type"] == "function" }

          expect(types.length).to eq(1)
          expect(interfaces.length).to eq(1)
          expect(functions.length).to eq(1)
        end
      end
    end
  end
end
