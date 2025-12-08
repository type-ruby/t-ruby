# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::InferredType do
  describe "#high_confidence?" do
    it "returns true for high confidence" do
      type = TRuby::InferredType.new(type: "String", confidence: TRuby::InferredType::HIGH)
      expect(type.high_confidence?).to be true
    end

    it "returns false for medium confidence" do
      type = TRuby::InferredType.new(type: "String", confidence: TRuby::InferredType::MEDIUM)
      expect(type.high_confidence?).to be false
    end
  end

  describe "#to_s" do
    it "returns the type string" do
      type = TRuby::InferredType.new(type: "Integer")
      expect(type.to_s).to eq("Integer")
    end
  end
end

RSpec.describe TRuby::TypeInferencer do
  let(:inferencer) { TRuby::TypeInferencer.new }

  describe "#infer_literal" do
    context "with string literals" do
      it "infers double-quoted strings" do
        result = inferencer.infer_literal('"hello"')
        expect(result.type).to eq("String")
        expect(result.confidence).to eq(TRuby::InferredType::HIGH)
      end

      it "infers single-quoted strings" do
        result = inferencer.infer_literal("'hello'")
        expect(result.type).to eq("String")
      end
    end

    context "with integer literals" do
      it "infers decimal integers" do
        result = inferencer.infer_literal("42")
        expect(result.type).to eq("Integer")
      end

      it "infers negative integers" do
        result = inferencer.infer_literal("-42")
        expect(result.type).to eq("Integer")
      end

      it "infers hexadecimal integers" do
        result = inferencer.infer_literal("0xFF")
        expect(result.type).to eq("Integer")
      end

      it "infers binary integers" do
        result = inferencer.infer_literal("0b1010")
        expect(result.type).to eq("Integer")
      end

      it "infers octal integers" do
        result = inferencer.infer_literal("0o755")
        expect(result.type).to eq("Integer")
      end
    end

    context "with float literals" do
      it "infers decimal floats" do
        result = inferencer.infer_literal("3.14")
        expect(result.type).to eq("Float")
      end

      it "infers scientific notation" do
        result = inferencer.infer_literal("1e10")
        expect(result.type).to eq("Float")
      end
    end

    context "with boolean literals" do
      it "infers true" do
        result = inferencer.infer_literal("true")
        expect(result.type).to eq("Boolean")
      end

      it "infers false" do
        result = inferencer.infer_literal("false")
        expect(result.type).to eq("Boolean")
      end
    end

    context "with nil literal" do
      it "infers nil" do
        result = inferencer.infer_literal("nil")
        expect(result.type).to eq("nil")
      end
    end

    context "with symbol literals" do
      it "infers symbols" do
        result = inferencer.infer_literal(":symbol")
        expect(result.type).to eq("Symbol")
      end
    end

    context "with array literals" do
      it "infers arrays" do
        result = inferencer.infer_literal("[1, 2, 3]")
        expect(result.type).to eq("Array")
      end
    end

    context "with hash literals" do
      it "infers hashes" do
        result = inferencer.infer_literal("{a: 1}")
        expect(result.type).to eq("Hash")
      end
    end

    context "with regex literals" do
      it "infers regexes" do
        result = inferencer.infer_literal("/pattern/")
        expect(result.type).to eq("Regexp")
      end
    end
  end

  describe "#infer_method_call" do
    it "infers to_s returns String" do
      result = inferencer.infer_method_call("Integer", "to_s")
      expect(result.type).to eq("String")
    end

    it "infers to_i returns Integer" do
      result = inferencer.infer_method_call("String", "to_i")
      expect(result.type).to eq("Integer")
    end

    it "infers length returns Integer" do
      result = inferencer.infer_method_call("String", "length")
      expect(result.type).to eq("Integer")
    end

    it "infers upcase returns String" do
      result = inferencer.infer_method_call("String", "upcase")
      expect(result.type).to eq("String")
    end

    it "infers split returns Array<String>" do
      result = inferencer.infer_method_call("String", "split")
      expect(result.type).to eq("Array<String>")
    end

    it "infers empty? returns Boolean" do
      result = inferencer.infer_method_call("Array", "empty?")
      expect(result.type).to eq("Boolean")
    end

    it "infers keys returns Array" do
      result = inferencer.infer_method_call("Hash", "keys")
      expect(result.type).to eq("Array")
    end
  end

  describe "#infer_return_type" do
    it "infers from explicit return with literal" do
      body = <<~RUBY
        return "hello"
      RUBY
      result = inferencer.infer_return_type(body)
      expect(result.type).to eq("String")
    end

    it "infers from explicit return with integer" do
      body = <<~RUBY
        return 42
      RUBY
      result = inferencer.infer_return_type(body)
      expect(result.type).to eq("Integer")
    end

    it "infers nil for empty body" do
      result = inferencer.infer_return_type("")
      expect(result.type).to eq("nil")
    end

    it "infers union type for multiple return types" do
      body = <<~RUBY
        if condition
          return "string"
        else
          return 42
        end
      RUBY
      result = inferencer.infer_return_type(body)
      expect(result.type).to include("String")
      expect(result.type).to include("Integer")
    end
  end

  describe "#infer_parameter_types" do
    it "infers numeric type from arithmetic usage" do
      body = "x + 1"
      params = [{ name: "x" }]
      result = inferencer.infer_parameter_types(body, params)
      expect(result["x"]&.type).to eq("Numeric")
    end

    it "infers String type from string method usage" do
      body = "s.upcase"
      params = [{ name: "s" }]
      result = inferencer.infer_parameter_types(body, params)
      expect(result["s"]&.type).to eq("String")
    end

    it "infers Array type from array method usage" do
      body = "arr.map { |x| x }"
      params = [{ name: "arr" }]
      result = inferencer.infer_parameter_types(body, params)
      expect(result["arr"]&.type).to eq("Array")
    end
  end

  describe "#infer_narrowed_type" do
    it "narrows type from is_a? guard" do
      result = inferencer.infer_narrowed_type("x", "x.is_a?(String)")
      expect(result.type).to eq("String")
    end

    it "narrows type from nil? check" do
      result = inferencer.infer_narrowed_type("x", "x.nil?")
      expect(result.type).to eq("nil")
    end
  end

  describe "#infer_expression_type" do
    it "infers literal types" do
      expect(inferencer.infer_expression_type("42").type).to eq("Integer")
      expect(inferencer.infer_expression_type('"hello"').type).to eq("String")
    end

    it "infers comparison operator returns Boolean" do
      result = inferencer.infer_expression_type("a == b")
      expect(result.type).to eq("Boolean")
    end

    it "infers array construction" do
      result = inferencer.infer_expression_type("[1, 2, 3]")
      expect(result.type).to include("Array")
    end

    it "infers empty array" do
      result = inferencer.infer_expression_type("[]")
      expect(result.type).to eq("Array")
    end

    it "infers hash construction" do
      result = inferencer.infer_expression_type("{a: 1}")
      expect(result.type).to eq("Hash")
    end
  end

  describe "#record_variable_type and #get_variable_type" do
    it "records and retrieves variable types" do
      type = TRuby::InferredType.new(type: "String")
      inferencer.record_variable_type("name", type)
      expect(inferencer.get_variable_type("name")).to eq(type)
    end
  end

  describe "#add_warning" do
    it "adds warnings to the list" do
      inferencer.add_warning("Ambiguous type inference")
      expect(inferencer.warnings.length).to eq(1)
      expect(inferencer.warnings.first[:message]).to eq("Ambiguous type inference")
    end
  end

  describe "#reset" do
    it "clears all state" do
      inferencer.record_variable_type("x", TRuby::InferredType.new(type: "String"))
      inferencer.add_warning("test")
      inferencer.reset
      expect(inferencer.get_variable_type("x")).to be_nil
      expect(inferencer.warnings).to be_empty
    end
  end

  describe "#infer_generic_params" do
    it "infers generic parameters from arguments" do
      call_args = ['"hello"']
      func_params = [{ name: "item", type: "Array<T>" }]

      # This is a simplified test - real implementation would be more complex
      result = inferencer.infer_generic_params(call_args, func_params)
      expect(result).to be_a(Hash)
    end
  end
end
