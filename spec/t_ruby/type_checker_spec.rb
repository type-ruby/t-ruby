# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::TypeHierarchy do
  let(:hierarchy) { TRuby::TypeHierarchy.new }

  describe "#subtype_of?" do
    it "recognizes same type" do
      expect(hierarchy.subtype_of?("String", "String")).to be true
    end

    it "recognizes Integer as subtype of Numeric" do
      expect(hierarchy.subtype_of?("Integer", "Numeric")).to be true
    end

    it "recognizes Float as subtype of Numeric" do
      expect(hierarchy.subtype_of?("Float", "Numeric")).to be true
    end

    it "recognizes all types as subtype of Object" do
      expect(hierarchy.subtype_of?("String", "Object")).to be true
      expect(hierarchy.subtype_of?("Integer", "Object")).to be true
    end

    it "does not recognize Numeric as subtype of Integer" do
      expect(hierarchy.subtype_of?("Numeric", "Integer")).to be false
    end
  end

  describe "#compatible?" do
    it "recognizes compatible types" do
      expect(hierarchy.compatible?("Integer", "Numeric")).to be true
      expect(hierarchy.compatible?("Numeric", "Integer")).to be true
    end
  end

  describe "#common_supertype" do
    it "finds common supertype" do
      expect(hierarchy.common_supertype("Integer", "Float")).to eq("Numeric")
    end

    it "returns same type for identical types" do
      expect(hierarchy.common_supertype("String", "String")).to eq("String")
    end
  end
end

RSpec.describe TRuby::TypeScope do
  describe "#define and #lookup" do
    it "stores and retrieves types" do
      scope = TRuby::TypeScope.new
      scope.define("x", "Integer")
      expect(scope.lookup("x")).to eq("Integer")
    end

    it "looks up in parent scope" do
      parent = TRuby::TypeScope.new
      parent.define("x", "Integer")

      child = parent.child_scope
      expect(child.lookup("x")).to eq("Integer")
    end

    it "shadows parent scope" do
      parent = TRuby::TypeScope.new
      parent.define("x", "Integer")

      child = parent.child_scope
      child.define("x", "String")
      expect(child.lookup("x")).to eq("String")
      expect(parent.lookup("x")).to eq("Integer")
    end
  end
end

RSpec.describe TRuby::FlowContext do
  describe "#narrow" do
    it "narrows variable type" do
      context = TRuby::FlowContext.new
      context.narrow("x", "String")
      expect(context.get_narrowed_type("x")).to eq("String")
    end
  end

  describe "#branch" do
    it "creates independent copy" do
      context = TRuby::FlowContext.new
      context.narrow("x", "String")

      branch = context.branch
      branch.narrow("x", "Integer")

      expect(context.get_narrowed_type("x")).to eq("String")
      expect(branch.get_narrowed_type("x")).to eq("Integer")
    end
  end

  describe "#merge" do
    it "creates union for different types" do
      context1 = TRuby::FlowContext.new
      context1.narrow("x", "String")

      context2 = TRuby::FlowContext.new
      context2.narrow("x", "Integer")

      merged = context1.merge(context2)
      expect(merged.get_narrowed_type("x")).to include("String")
      expect(merged.get_narrowed_type("x")).to include("Integer")
    end

    it "keeps same type when both branches agree" do
      context1 = TRuby::FlowContext.new
      context1.narrow("x", "String")

      context2 = TRuby::FlowContext.new
      context2.narrow("x", "String")

      merged = context1.merge(context2)
      expect(merged.get_narrowed_type("x")).to eq("String")
    end
  end
end

RSpec.describe TRuby::TypeChecker do
  let(:checker) { TRuby::TypeChecker.new }

  describe "#register_function" do
    it "registers function signature" do
      checker.register_function(
        "greet",
        params: [{ name: "name", type: "String" }],
        return_type: "String"
      )

      # Verify by checking a call
      result = checker.check_call("greet", ['"hello"'])
      expect(result).to eq("String")
    end
  end

  describe "#check_call" do
    before do
      checker.register_function(
        "add",
        params: [
          { name: "a", type: "Integer" },
          { name: "b", type: "Integer" }
        ],
        return_type: "Integer"
      )
    end

    it "validates correct argument types" do
      checker.check_call("add", ["1", "2"])
      expect(checker.errors).to be_empty
    end

    it "reports wrong argument count" do
      checker.check_call("add", ["1"])
      expect(checker.errors).not_to be_empty
      expect(checker.errors.first.message).to include("Wrong number")
    end

    it "reports type mismatch" do
      checker.check_call("add", ['"hello"', "2"])
      expect(checker.errors).not_to be_empty
      expect(checker.errors.first.message).to include("Type mismatch")
    end

    it "warns about unknown functions" do
      checker.check_call("unknown_func", [])
      expect(checker.warnings).not_to be_empty
    end
  end

  describe "#check_return" do
    it "validates matching return type" do
      result = checker.check_return('"hello"', "String")
      expect(result).to be true
      expect(checker.errors).to be_empty
    end

    it "reports return type mismatch" do
      checker.check_return("42", "String")
      expect(checker.errors).not_to be_empty
    end
  end

  describe "#check_assignment" do
    it "allows compatible assignment" do
      result = checker.check_assignment("x", "42", declared_type: "Integer")
      expect(result).to be true
    end

    it "reports incompatible assignment" do
      checker.check_assignment("x", '"hello"', declared_type: "Integer")
      expect(checker.errors).not_to be_empty
    end
  end

  describe "#check_operator" do
    it "validates arithmetic operators" do
      result = checker.check_operator("Integer", "+", "Integer")
      expect(result).to eq("Integer")
    end

    it "promotes to Float when needed" do
      result = checker.check_operator("Integer", "+", "Float")
      expect(result).to eq("Float")
    end

    it "allows string concatenation" do
      result = checker.check_operator("String", "+", "String")
      expect(result).to eq("String")
    end

    it "reports error for invalid string concatenation" do
      checker.check_operator("String", "+", "Integer")
      expect(checker.errors).not_to be_empty
    end

    it "returns Boolean for comparisons" do
      result = checker.check_operator("Integer", "==", "Integer")
      expect(result).to eq("Boolean")
    end
  end

  describe "#narrow_in_conditional" do
    it "narrows type from is_a? guard" do
      then_scope = TRuby::FlowContext.new
      else_scope = TRuby::FlowContext.new

      checker.narrow_in_conditional("x.is_a?(String)", then_scope, else_scope)

      expect(then_scope.get_narrowed_type("x")).to eq("String")
    end

    it "narrows from nil? check" do
      then_scope = TRuby::FlowContext.new
      else_scope = TRuby::FlowContext.new

      checker.narrow_in_conditional("x.nil?", then_scope, else_scope)

      expect(then_scope.get_narrowed_type("x")).to eq("nil")
    end
  end

  describe "#register_alias" do
    it "registers and resolves type aliases" do
      checker.register_alias("UserId", "Integer")
      expect(checker.resolve_type("UserId")).to eq("Integer")
    end
  end

  describe "#reset" do
    it "clears all state" do
      checker.register_function("test", params: [], return_type: "String")
      checker.check_call("unknown", [])

      checker.reset

      expect(checker.errors).to be_empty
      expect(checker.warnings).to be_empty
    end
  end

  describe "#diagnostics" do
    it "returns combined errors and warnings" do
      checker.check_call("unknown", [])

      diagnostics = checker.diagnostics
      expect(diagnostics).not_to be_empty
      expect(diagnostics.first[:type]).to eq(:warning)
    end
  end
end

RSpec.describe TRuby::TypeCheckError do
  it "formats error message" do
    error = TRuby::TypeCheckError.new(
      message: "Type mismatch",
      expected: "String",
      actual: "Integer",
      suggestion: "Use .to_s"
    )

    str = error.to_s
    expect(str).to include("Type mismatch")
    expect(str).to include("Expected: String")
    expect(str).to include("Actual: Integer")
    expect(str).to include("Suggestion: Use .to_s")
  end
end
