# frozen_string_literal: true

require "spec_helper"

describe TRuby::RBSGenerator do
  let(:generator) { TRuby::RBSGenerator.new }

  describe "basic function signature generation" do
    it "generates RBS for simple function" do
      func = {
        name: "greet",
        params: [{ name: "name", type: "String" }],
        return_type: "String",
      }

      rbs = generator.generate_function_signature(func)
      expect(rbs).to include("def greet")
      expect(rbs).to include("String")
    end

    it "generates RBS for function with no parameters" do
      func = {
        name: "hello",
        params: [],
        return_type: "String",
      }

      rbs = generator.generate_function_signature(func)
      expect(rbs).to include("def hello")
    end

    it "generates RBS for function with multiple parameters" do
      func = {
        name: "add",
        params: [
          { name: "a", type: "Integer" },
          { name: "b", type: "Integer" },
        ],
        return_type: "Integer",
      }

      rbs = generator.generate_function_signature(func)
      expect(rbs).to include("add")
      expect(rbs).to include("Integer")
    end

    it "handles void return type" do
      func = {
        name: "log",
        params: [{ name: "msg", type: "String" }],
        return_type: "void",
      }

      rbs = generator.generate_function_signature(func)
      expect(rbs).to include("void")
    end

    it "handles parameters without types" do
      func = {
        name: "process",
        params: [{ name: "value", type: nil }],
        return_type: nil,
      }

      rbs = generator.generate_function_signature(func)
      expect(rbs).to include("process")
    end
  end

  describe "type alias generation" do
    it "generates RBS for simple type alias" do
      type_alias = { name: "UserId", definition: "String" }

      rbs = generator.generate_type_alias(type_alias)
      expect(rbs).to include("type UserId")
      expect(rbs).to include("String")
    end

    it "generates multiple type aliases" do
      aliases = [
        { name: "UserId", definition: "String" },
        { name: "Count", definition: "Integer" },
      ]

      rbs = generator.generate_type_aliases(aliases)
      expect(rbs).to include("UserId")
      expect(rbs).to include("Count")
    end
  end

  describe "complete RBS file generation" do
    it "generates RBS content from parsed data" do
      functions = [
        {
          name: "greet",
          params: [{ name: "name", type: "String" }],
          return_type: "String",
        },
      ]
      type_aliases = [{ name: "UserId", definition: "String" }]

      rbs = generator.generate(functions, type_aliases)
      expect(rbs).to include("type UserId")
      expect(rbs).to include("def greet")
    end

    it "returns empty string when no functions or aliases" do
      rbs = generator.generate([], [])
      expect(rbs).to be_a(String)
    end

    it "generates valid RBS format" do
      functions = [
        {
          name: "create",
          params: [{ name: "name", type: "String" }],
          return_type: "Boolean",
        },
      ]

      rbs = generator.generate(functions, [])
      # Basic validation: RBS should be readable
      expect(rbs).not_to include("nil:")
    end
  end

  describe "visibility modifier generation" do
    it "generates RBS with private visibility" do
      func = {
        name: "secret",
        params: [{ name: "x", type: "String" }],
        return_type: "Integer",
        visibility: :private,
      }

      rbs = generator.generate_function_signature(func)
      expect(rbs).to eq("private def secret: (x: String) -> Integer")
    end

    it "generates RBS with protected visibility" do
      func = {
        name: "internal",
        params: [{ name: "n", type: "Integer" }],
        return_type: "Boolean",
        visibility: :protected,
      }

      rbs = generator.generate_function_signature(func)
      expect(rbs).to eq("protected def internal: (n: Integer) -> Boolean")
    end

    it "generates RBS without modifier for public visibility" do
      func = {
        name: "hello",
        params: [],
        return_type: "String",
        visibility: :public,
      }

      rbs = generator.generate_function_signature(func)
      expect(rbs).to eq("def hello: () -> String")
    end

    it "generates RBS without modifier when visibility is nil" do
      func = {
        name: "hello",
        params: [],
        return_type: "String",
      }

      rbs = generator.generate_function_signature(func)
      expect(rbs).to eq("def hello: () -> String")
    end
  end

  describe "RBS format validation" do
    it "maintains proper RBS syntax" do
      func = {
        name: "test_method",
        params: [{ name: "x", type: "Integer" }],
        return_type: "String",
      }

      rbs = generator.generate_function_signature(func)
      # Should have basic RBS format
      expect(rbs).to match(/def\s+\w+/)
    end

    it "handles array types in RBS" do
      func = {
        name: "process_items",
        params: [{ name: "items", type: "Array" }],
        return_type: "Array",
      }

      rbs = generator.generate_function_signature(func)
      expect(rbs).to include("Array")
    end

    it "handles hash types in RBS" do
      func = {
        name: "get_data",
        params: [{ name: "key", type: "String" }],
        return_type: "Hash",
      }

      rbs = generator.generate_function_signature(func)
      expect(rbs).to include("Hash")
    end
  end
end
