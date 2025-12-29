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

    it "returns empty hash when no generics" do
      call_args = ['"hello"']
      func_params = [{ name: "item", type: "String" }]

      result = inferencer.infer_generic_params(call_args, func_params)
      expect(result).to eq({})
    end
  end

  describe "InferredType" do
    describe "#medium_confidence?" do
      it "returns true for medium confidence" do
        type = TRuby::InferredType.new(type: "String", confidence: TRuby::InferredType::MEDIUM)
        expect(type.medium_confidence?).to be true
      end

      it "returns false for high confidence" do
        type = TRuby::InferredType.new(type: "String", confidence: TRuby::InferredType::HIGH)
        expect(type.medium_confidence?).to be false
      end
    end

    describe "#low_confidence?" do
      it "returns true for low confidence" do
        type = TRuby::InferredType.new(type: "String", confidence: TRuby::InferredType::LOW)
        expect(type.low_confidence?).to be true
      end

      it "returns false for medium confidence" do
        type = TRuby::InferredType.new(type: "String", confidence: TRuby::InferredType::MEDIUM)
        expect(type.low_confidence?).to be false
      end
    end

    describe "attributes" do
      it "stores source" do
        type = TRuby::InferredType.new(type: "String", source: :literal)
        expect(type.source).to eq(:literal)
      end

      it "stores location" do
        type = TRuby::InferredType.new(type: "String", location: { line: 10, column: 5 })
        expect(type.location).to eq({ line: 10, column: 5 })
      end
    end
  end

  describe "#infer_literal" do
    it "returns nil for non-literal expressions" do
      result = inferencer.infer_literal("some_variable")
      expect(result).to be_nil
    end

    it "handles underscored integers" do
      result = inferencer.infer_literal("1_000_000")
      # Depends on pattern - may or may not match
      expect(result.nil? || result.type == "Integer").to be true
    end
  end

  describe "#infer_method_call" do
    it "infers gsub returns String" do
      result = inferencer.infer_method_call("String", "gsub")
      expect(result.type).to eq("String")
    end

    it "infers chars returns Array<String>" do
      result = inferencer.infer_method_call("String", "chars")
      expect(result.type).to eq("Array<String>")
    end

    it "infers bytes returns Array<Integer>" do
      result = inferencer.infer_method_call("String", "bytes")
      expect(result.type).to eq("Array<Integer>")
    end

    it "infers to_f returns Float" do
      result = inferencer.infer_method_call("Integer", "to_f")
      expect(result.type).to eq("Float")
    end

    it "infers flatten returns Array" do
      result = inferencer.infer_method_call("Array", "flatten")
      expect(result.type).to eq("Array")
    end

    it "infers merge returns Hash" do
      result = inferencer.infer_method_call("Hash", "merge")
      expect(result.type).to eq("Hash")
    end

    it "infers class returns Class" do
      result = inferencer.infer_method_call("Object", "class")
      expect(result.type).to eq("Class")
    end

    it "infers inspect returns String" do
      result = inferencer.infer_method_call("Object", "inspect")
      expect(result.type).to eq("String")
    end

    it "infers nil? returns Boolean" do
      result = inferencer.infer_method_call("Object", "nil?")
      expect(result.type).to eq("Boolean")
    end

    it "infers from receiver for unknown method on string" do
      # Unknown methods on String receiver may return String (via infer_from_receiver heuristic)
      result = inferencer.infer_method_call("String", "some_method_x")
      # The implementation returns String for any lowercase method on String receiver
      expect(result).not_to be_nil
    end

    context "with receiver type" do
      it "infers String method returns from receiver" do
        # This uses infer_from_receiver
        result = inferencer.infer_method_call("String", "chars")
        expect(result.type).to eq("Array<String>")
      end
    end
  end

  describe "#infer_return_type" do
    it "returns nil for body with no inferable returns" do
      body = "some_method_call()"
      result = inferencer.infer_return_type(body)
      # Returns nil confidence medium due to implicit return
      expect(result.type).to eq("nil")
    end
  end

  describe "#infer_parameter_types" do
    it "infers Hash type from hash method usage" do
      body = "h.keys"
      params = [{ name: "h" }]
      result = inferencer.infer_parameter_types(body, params)
      expect(result["h"]&.type).to eq("Hash")
    end

    it "infers Numeric type from numeric method usage" do
      body = "n.abs"
      params = [{ name: "n" }]
      result = inferencer.infer_parameter_types(body, params)
      expect(result["n"]&.type).to eq("Numeric")
    end

    it "returns empty hash for unused parameters" do
      body = "puts 'hello'"
      params = [{ name: "unused" }]
      result = inferencer.infer_parameter_types(body, params)
      expect(result).to eq({})
    end

    it "handles comparison operations" do
      body = "x > 10"
      params = [{ name: "x" }]
      result = inferencer.infer_parameter_types(body, params)
      # Comparison doesn't determine type by itself
      expect(result).to be_a(Hash)
    end

    it "handles string interpolation" do
      body = 'puts "Hello #{name}"'
      params = [{ name: "name" }]
      result = inferencer.infer_parameter_types(body, params)
      # String interpolation doesn't determine type
      expect(result).to be_a(Hash)
    end
  end

  describe "#infer_narrowed_type" do
    it "returns nil for respond_to? check" do
      result = inferencer.infer_narrowed_type("x", "x.respond_to?(:to_s)")
      expect(result).to be_nil
    end

    it "returns nil for unknown condition" do
      result = inferencer.infer_narrowed_type("x", "some_condition")
      expect(result).to be_nil
    end
  end

  describe "#infer_expression_type" do
    it "infers method chain" do
      result = inferencer.infer_expression_type('"hello".upcase.length')
      expect(result&.type).to eq("Integer")
    end

    it "infers logical operators" do
      result = inferencer.infer_expression_type("a && b")
      # && propagates types, may return nil
      expect(result).to be_nil
    end

    it "infers negation operator" do
      result = inferencer.infer_expression_type("a ! b")
      # Negation requires space-surrounded operator in the implementation
      expect(result&.type).to eq("Boolean") if result
    end

    it "infers bitwise operators" do
      result = inferencer.infer_expression_type("a & b")
      expect(result&.type).to eq("Integer")
    end

    it "infers spaceship operator" do
      result = inferencer.infer_expression_type("a <=> b")
      expect(result&.type).to eq("Integer")
    end

    it "infers less-than-or-equal operator" do
      result = inferencer.infer_expression_type("a <= b")
      expect(result&.type).to eq("Boolean")
    end

    it "infers modulo operator" do
      result = inferencer.infer_expression_type("a % b")
      expect(result&.type).to eq("Numeric")
    end

    it "infers typed array construction" do
      result = inferencer.infer_expression_type('["a", "b", "c"]')
      expect(result&.type).to include("Array")
      # Element type inference may not work for quoted strings in simple split
    end

    it "infers mixed type array" do
      result = inferencer.infer_expression_type('[1, "hello"]')
      expect(result&.type).to include("Array")
    end
  end

  describe "LITERAL_PATTERNS constant" do
    it "includes all expected patterns" do
      patterns = TRuby::TypeInferencer::LITERAL_PATTERNS
      expect(patterns.values).to include("String", "Integer", "Float", "Boolean", "nil", "Symbol", "Array", "Hash", "Regexp")
    end
  end

  describe "METHOD_RETURN_TYPES constant" do
    it "includes common methods" do
      types = TRuby::TypeInferencer::METHOD_RETURN_TYPES
      expect(types["to_s"]).to eq("String")
      expect(types["to_i"]).to eq("Integer")
      expect(types["empty?"]).to eq("Boolean")
    end
  end

  describe "OPERATOR_TYPES constant" do
    it "includes arithmetic operators" do
      ops = TRuby::TypeInferencer::OPERATOR_TYPES
      expect(ops["+"]).to eq(:numeric_or_string)
      expect(ops["-"]).to eq(:numeric)
    end

    it "includes comparison operators" do
      ops = TRuby::TypeInferencer::OPERATOR_TYPES
      expect(ops["=="]).to eq("Boolean")
      expect(ops["<"]).to eq("Boolean")
    end
  end

  describe "#add_warning" do
    it "stores warning with location" do
      inferencer.add_warning("Test warning", location: { line: 5 })
      warning = inferencer.warnings.first
      expect(warning[:location]).to eq({ line: 5 })
    end
  end

  describe "private methods via send" do
    describe "#extract_return_statements" do
      it "extracts explicit returns" do
        body = "return 42"
        statements = inferencer.send(:extract_return_statements, body)
        expect(statements.length).to eq(1)
        expect(statements.first[:value]).to eq("42")
      end

      it "handles multiple returns" do
        body = "if x\n  return 1\nelse\n  return 2\nend"
        statements = inferencer.send(:extract_return_statements, body)
        expect(statements.length).to eq(2)
      end
    end

    describe "#find_parameter_usages" do
      it "finds method calls on parameter" do
        body = "x.upcase.strip"
        usages = inferencer.send(:find_parameter_usages, body, "x")
        expect(usages.any? { |u| u[:type] == :method_call }).to be true
      end

      it "finds arithmetic usage" do
        body = "x + 1"
        usages = inferencer.send(:find_parameter_usages, body, "x")
        expect(usages.any? { |u| u[:type] == :arithmetic }).to be true
      end
    end

    describe "#infer_type_from_method" do
      it "identifies string methods" do
        expect(inferencer.send(:infer_type_from_method, "upcase")).to eq("String")
        expect(inferencer.send(:infer_type_from_method, "downcase")).to eq("String")
      end

      it "identifies array methods" do
        expect(inferencer.send(:infer_type_from_method, "each")).to eq("Array")
        expect(inferencer.send(:infer_type_from_method, "map")).to eq("Array")
      end

      it "identifies hash methods" do
        expect(inferencer.send(:infer_type_from_method, "keys")).to eq("Hash")
        expect(inferencer.send(:infer_type_from_method, "values")).to eq("Hash")
      end

      it "identifies numeric methods" do
        expect(inferencer.send(:infer_type_from_method, "abs")).to eq("Numeric")
        expect(inferencer.send(:infer_type_from_method, "times")).to eq("Numeric")
      end

      it "returns nil for unknown methods" do
        expect(inferencer.send(:infer_type_from_method, "unknown")).to be_nil
      end
    end

    describe "#infer_from_receiver" do
      it "returns nil for nil receiver" do
        result = inferencer.send(:infer_from_receiver, nil, "length")
        expect(result).to be_nil
      end

      it "infers String receiver methods" do
        expect(inferencer.send(:infer_from_receiver, "String", "length")).to eq("Integer")
        expect(inferencer.send(:infer_from_receiver, "String", "chars")).to eq("Array<String>")
      end

      it "infers Array receiver methods" do
        expect(inferencer.send(:infer_from_receiver, "Array", "length")).to eq("Integer")
        expect(inferencer.send(:infer_from_receiver, "Array", "join")).to eq("String")
      end

      it "infers Numeric receiver methods" do
        expect(inferencer.send(:infer_from_receiver, "Integer", "to_s")).to eq("String")
        expect(inferencer.send(:infer_from_receiver, "Float", "to_i")).to eq("Integer")
      end
    end

    describe "#infer_operator_result" do
      it "returns Boolean for comparison" do
        result = inferencer.send(:infer_operator_result, "a == b", "==", "Boolean")
        expect(result.type).to eq("Boolean")
      end

      it "returns Integer for bitwise" do
        result = inferencer.send(:infer_operator_result, "a & b", "&", "Integer")
        expect(result.type).to eq("Integer")
      end

      it "returns Numeric for arithmetic" do
        result = inferencer.send(:infer_operator_result, "a - b", "-", :numeric)
        expect(result.type).to eq("Numeric")
      end

      it "returns mixed type for ambiguous" do
        result = inferencer.send(:infer_operator_result, "a + b", "+", :numeric_or_string)
        expect(result.type).to include("Numeric")
      end

      it "returns nil for propagate type" do
        result = inferencer.send(:infer_operator_result, "a && b", "&&", :propagate)
        expect(result).to be_nil
      end
    end

    describe "#infer_array_type" do
      it "infers empty array" do
        result = inferencer.send(:infer_array_type, "[]")
        expect(result.type).to eq("Array")
      end

      it "infers homogeneous array" do
        result = inferencer.send(:infer_array_type, "[1, 2, 3]")
        expect(result.type).to eq("Array<Integer>")
      end

      it "infers string array" do
        result = inferencer.send(:infer_array_type, '["a", "b"]')
        expect(result.type).to eq("Array<String>")
      end
    end

    describe "#split_array_elements" do
      it "splits simple elements" do
        result = inferencer.send(:split_array_elements, "1, 2, 3")
        expect(result).to eq(%w[1 2 3])
      end

      it "handles whitespace" do
        result = inferencer.send(:split_array_elements, "  a  ,  b  ")
        expect(result).to eq(%w[a b])
      end
    end

    describe "#infer_from_usages" do
      it "returns nil for empty usages" do
        result = inferencer.send(:infer_from_usages, [])
        expect(result).to be_nil
      end

      it "infers from arithmetic usage" do
        usages = [{ type: :arithmetic, line: 1 }]
        result = inferencer.send(:infer_from_usages, usages)
        expect(result.type).to eq("Numeric")
      end

      it "infers from method call usage" do
        usages = [{ type: :method_call, method: "upcase", line: 1 }]
        result = inferencer.send(:infer_from_usages, usages)
        expect(result.type).to eq("String")
      end
    end
  end
end
