# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::ValidationConfig do
  let(:config) { TRuby::ValidationConfig.new }

  it "has default settings" do
    expect(config.validate_all).to be true
    expect(config.validate_public_only).to be false
    expect(config.raise_on_error).to be true
  end

  it "allows modifying settings" do
    config.validate_public_only = true
    expect(config.validate_public_only).to be true
  end
end

RSpec.describe TRuby::RuntimeValidator do
  let(:validator) { TRuby::RuntimeValidator.new }

  describe "#generate_type_check" do
    context "with simple types" do
      it "generates String check" do
        check = validator.generate_type_check("x", "String")
        expect(check).to eq("x.is_a?(String)")
      end

      it "generates Integer check" do
        check = validator.generate_type_check("x", "Integer")
        expect(check).to eq("x.is_a?(Integer)")
      end

      it "generates Boolean check" do
        check = validator.generate_type_check("x", "Boolean")
        expect(check).to eq("(x == true || x == false)")
      end

      it "generates nil check" do
        check = validator.generate_type_check("x", "nil")
        expect(check).to eq("x.nil?")
      end

      it "generates Symbol check" do
        check = validator.generate_type_check("x", "Symbol")
        expect(check).to eq("x.is_a?(Symbol)")
      end
    end

    context "with union types" do
      it "generates union check" do
        check = validator.generate_type_check("x", "String | Integer")
        expect(check).to include("x.is_a?(String)")
        expect(check).to include("x.is_a?(Integer)")
        expect(check).to include("||")
      end

      it "handles nil in union" do
        check = validator.generate_type_check("x", "String | nil")
        expect(check).to include("x.is_a?(String)")
        expect(check).to include("x.nil?")
      end
    end

    context "with generic types" do
      it "generates Array<T> check" do
        check = validator.generate_type_check("arr", "Array<String>")
        expect(check).to include("arr.is_a?(Array)")
        expect(check).to include("arr.all?")
      end

      it "generates Hash<K, V> check" do
        check = validator.generate_type_check("h", "Hash<String, Integer>")
        expect(check).to include("h.is_a?(Hash)")
        expect(check).to include("h.all?")
      end
    end

    context "with optional types" do
      it "generates optional check" do
        check = validator.generate_type_check("x", "String?")
        expect(check).to include("x.nil?")
        expect(check).to include("x.is_a?(String)")
        expect(check).to include("||")
      end
    end

    context "with intersection types" do
      it "generates intersection check" do
        check = validator.generate_type_check("x", "Readable & Writable")
        expect(check).to include("x.is_a?(Readable)")
        expect(check).to include("x.is_a?(Writable)")
        expect(check).to include("&&")
      end
    end
  end

  describe "#generate_param_validation" do
    it "generates raise statement by default" do
      validation = validator.generate_param_validation("name", "String")
      expect(validation).to include("raise")
      expect(validation).to include("unless")
    end

    it "generates warn statement when configured" do
      config = TRuby::ValidationConfig.new
      config.raise_on_error = false
      warn_validator = TRuby::RuntimeValidator.new(config)

      validation = warn_validator.generate_param_validation("name", "String")
      expect(validation).to include("warn")
    end
  end

  describe "#generate_function_validation" do
    it "generates validations for all typed parameters" do
      func_info = {
        name: "greet",
        params: [
          { name: "name", type: "String" },
          { name: "age", type: "Integer" }
        ],
        return_type: "String"
      }

      validations = validator.generate_function_validation(func_info)
      expect(validations.length).to eq(3) # 2 params + 1 return
    end

    it "skips untyped parameters" do
      func_info = {
        name: "foo",
        params: [
          { name: "x", type: nil },
          { name: "y", type: "String" }
        ],
        return_type: nil
      }

      validations = validator.generate_function_validation(func_info)
      expect(validations.length).to eq(1)
    end
  end

  describe "#transform" do
    it "inserts validation code after function definition" do
      source = <<~RUBY
        def greet(name: String): String
          "Hello, \#{name}"
        end
      RUBY

      parse_result = {
        functions: [
          {
            name: "greet",
            params: [{ name: "name", type: "String" }],
            return_type: "String"
          }
        ]
      }

      transformed = validator.transform(source, parse_result)
      expect(transformed).to include("raise")
      expect(transformed).to include("name")
    end
  end

  describe "#generate_validation_module" do
    it "generates a complete validation module" do
      functions = [
        {
          name: "add",
          params: [
            { name: "a", type: "Integer" },
            { name: "b", type: "Integer" }
          ],
          return_type: "Integer"
        }
      ]

      module_code = validator.generate_validation_module(functions)
      expect(module_code).to include("module TRubyValidation")
      expect(module_code).to include("validate_add_params")
      expect(module_code).to include("validate_type")
    end
  end

  describe "#should_validate?" do
    it "returns true for all when validate_all is true" do
      expect(validator.should_validate?(:private)).to be true
      expect(validator.should_validate?(:public)).to be true
    end

    it "returns true only for public when validate_public_only is true" do
      config = TRuby::ValidationConfig.new
      config.validate_all = false
      config.validate_public_only = true
      public_validator = TRuby::RuntimeValidator.new(config)

      expect(public_validator.should_validate?(:public)).to be true
      expect(public_validator.should_validate?(:private)).to be false
    end
  end
end

RSpec.describe TRuby::RuntimeTypeError do
  it "stores type information" do
    error = TRuby::RuntimeTypeError.new(
      "Type mismatch",
      expected_type: "String",
      actual_type: "Integer",
      value: 42
    )

    expect(error.expected_type).to eq("String")
    expect(error.actual_type).to eq("Integer")
    expect(error.value).to eq(42)
  end
end

RSpec.describe TRuby::RuntimeTypeChecks do
  let(:test_class) do
    Class.new do
      include TRuby::RuntimeTypeChecks

      def greet(name)
        validate_param(name, "String", "name")
        "Hello, #{name}"
      end

      def get_number
        result = 42
        validate_return(result, "Integer")
      end
    end
  end

  describe "#validate_param" do
    it "passes for correct type" do
      obj = test_class.new
      expect { obj.greet("World") }.not_to raise_error
    end

    it "raises for incorrect type" do
      obj = test_class.new
      expect { obj.greet(123) }.to raise_error(TRuby::RuntimeTypeError)
    end
  end

  describe "#validate_return" do
    it "returns value for correct type" do
      obj = test_class.new
      expect(obj.get_number).to eq(42)
    end
  end

  describe ".validate_types! and .skip_type_validation!" do
    it "can toggle validation" do
      test_class.skip_type_validation!
      expect(test_class.type_validation_enabled?).to be false

      test_class.validate_types!
      expect(test_class.type_validation_enabled?).to be true
    end
  end
end
